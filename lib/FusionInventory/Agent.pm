package FusionInventory::Agent;

use strict;
use warnings;

use English qw(-no_match_vars);
use UNIVERSAL::require;
use File::Glob;
use IO::Handle;
use POSIX ":sys_wait_h"; # WNOHANG

use FusionInventory::Agent::Config;
use FusionInventory::Agent::HTTP::Client::Fusion;
use FusionInventory::Agent::Logger;
use FusionInventory::Agent::Storage;
use FusionInventory::Agent::Target::Server;
use FusionInventory::Agent::Task;
use FusionInventory::Agent::Controller;
use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::Hostname;
use FusionInventory::Agent::Message::Outbound;

our $VERSION = '2.3.14';
our $VERSION_STRING = _versionString($VERSION);
our $AGENT_STRING = "FusionInventory-Agent_v$VERSION";

sub _versionString {
    my ($VERSION) = @_;

    my $string = "FusionInventory Agent ($VERSION)";
    if ($VERSION =~ /^\d\.\d\.99(\d\d)/) {
        $string .= " **THIS IS A DEVELOPMENT RELEASE **";
    }

    return $string;
}

sub new {
    my ($class, %params) = @_;

    my $self = {
        status  => 'unknown',
        confdir => $params{confdir},
        datadir => $params{datadir},
        libdir  => $params{libdir},
        vardir  => $params{vardir},
    };
    bless $self, $class;

    return $self;
}

sub init {
    my ($self, %params) = @_;

    my $config = FusionInventory::Agent::Config->new(
        confdir => $self->{confdir},
        options => $params{options},
    );
    $self->{config} = $config;

    my $verbosity = $config->{debug} && $config->{debug} == 1 ? LOG_DEBUG  :
                    $config->{debug} && $config->{debug} == 2 ? LOG_DEBUG2 :
                                                                LOG_INFO   ;

    my $logger = FusionInventory::Agent::Logger->new(
        config    => $config,
        backends  => $config->{logger},
        verbosity => $verbosity
    );
    $self->{logger} = $logger;

    $logger->debug("Configuration directory: $self->{confdir}");
    $logger->debug("Data directory: $self->{datadir}");
    $logger->debug("Storage directory: $self->{vardir}");
    $logger->debug("Lib directory: $self->{libdir}");

    $self->{storage} = FusionInventory::Agent::Storage->new(
        logger    => $logger,
        directory => $self->{vardir}
    );

    # handle persistent state
    $self->_loadState();

    $self->{deviceid} = _computeDeviceId() if !$self->{deviceid};

    $self->_saveState();

    foreach my $server (@{$config->{server}}) {
        push @{$self->{controllers}},
            FusionInventory::Agent::Controller->new(
                logger     => $logger,
                delaytime  => $config->{delaytime},
                basevardir => $self->{vardir},
                url        => $server,
            );
    }

    if (!$self->{controllers}) {
        $logger->error("No server defined, aborting");
        exit 1;
    }

    # compute list of available modules
    my %modules = $self->getAvailableModules(disabled => $config->{'no-module'});

    if (!%modules) {
        $logger->error("No modules available, aborting");
        exit 1;
    }

    $logger->debug("Available modules");
    foreach my $module (keys %modules) {
        $logger->debug("- $module $modules{$module}");
    }

    $self->{modules} = \%modules;

    # create HTTP interface
    if (($config->{daemon} || $config->{service}) && !$config->{'no-httpd'}) {
        FusionInventory::Agent::HTTP::Server->require();
        if ($EVAL_ERROR) {
            $logger->error("Failed to load HTTP server: $EVAL_ERROR");
        } else {
            $self->{server} = FusionInventory::Agent::HTTP::Server->new(
                logger          => $logger,
                agent           => $self,
                htmldir         => $self->{datadir} . '/html',
                ip              => $config->{'httpd-ip'},
                port            => $config->{'httpd-port'},
                trust           => $config->{'httpd-trust'}
            );
            $self->{server}->init();
        }
    }

    # install signal handler to handle graceful exit
    $SIG{INT}     = sub { $self->terminate(); exit 0; };
    $SIG{TERM}    = sub { $self->terminate(); exit 0; };

    $self->{logger}->info("FusionInventory Agent starting")
        if $self->{config}->{daemon} || $self->{config}->{service};
}

sub run {
    my ($self) = @_;

    $self->{status} = 'waiting';

    while (1) {
        my $time = time();
        foreach my $controller (@{$self->{controllers}}) {
            next if $time < $controller->getNextRunDate();

            eval {
                $self->executeScheduledTasks($controller);
            };
            $self->{logger}->error($EVAL_ERROR) if $EVAL_ERROR;
            $controller->resetNextRunDate();
        }

        # check for http interface messages
        $self->{server}->handleRequests() if $self->{server};
        delay(1);
    }
}

sub terminate {
    my ($self) = @_;

    $self->{logger}->info("FusionInventory Agent exiting")
        if $self->{config}->{daemon} || $self->{config}->{service};
    $self->{current_task}->abort() if $self->{current_task};
}

sub executeScheduledTasks {
    my ($self, $controller) = @_;

    # create a single client object for this run
    my $client = FusionInventory::Agent::HTTP::Client::Fusion->new(
        logger       => $self->{logger},
        timeout      => $self->{timeout},
        user         => $self->{config}->{user},
        password     => $self->{config}->{password},
        proxy        => $self->{config}->{proxy},
        ca_cert_file => $self->{config}->{'ca-cert-file'},
        ca_cert_dir  => $self->{config}->{'ca-cert-dir'},
        no_ssl_check => $self->{config}->{'no-ssl-check'},
    );

    # get scheduled tasks, using legacy protocol
    $self->{logger}->info("sending prolog request to server $controller->{id}");

    my $answer = $client->sendXML(
        url     => $controller->getUrl(),
        message => FusionInventory::Agent::Message::Outbound->new(
            query    => 'PROLOG',
            token    => '123456678',
            deviceid => $self->{deviceid},
        )
    );
    die "No answer to prolog request from the server" unless $answer;
    my $prolog = $answer->getContent();

    # get scheduled tasks, using new protocol
    $self->{logger}->info("sending getConfig request to server $controller->{id}");

    my $config = $client->sendJSON(
        url  => $controller->getUrl(),
        args => {
            action    => "getConfig",
            machineid => $self->{deviceid},
            task      => $self->{tasks},
        }
    );
    die "No answer to getConfig request from the server" unless $config;
    my $schedule = $config->{schedule};

    # update controller
    if (defined($prolog->{PROLOG_FREQ})) {
        $controller->setMaxDelay($prolog->{PROLOG_FREQ} * 3600);
    }

    foreach my $name (keys %{$self->{modules}}) {
        eval {
            $self->_executeTask($controller, $name, $prolog, $client, $schedule);
        };
        $self->{logger}->error($EVAL_ERROR) if $EVAL_ERROR;
        $self->{status} = 'waiting';
    }
}

sub _executeTask {
    my ($self, $controller, $name, $prolog, $client, $schedule) = @_;

    $self->{status} = "running task $name";

    if ($self->{config}->{daemon} || $self->{config}->{service}) {
        # server mode: run each task in a child process
        if (my $pid = fork()) {
            # parent
            while (waitpid($pid, WNOHANG) == 0) {
                $self->{server}->handleRequests() if $self->{server};
                delay(1);
            }
        } else {
            # child
            die "fork failed: $ERRNO" unless defined $pid;

            $self->{logger}->debug("forking process $PID to handle task $name");
            $self->_executeTaskReal($controller, $name, $prolog, $client, $schedule);
            exit(0);
        }
    } else {
        # standalone mode: run each task directly
        $self->_executeTaskReal($controller, $name, $prolog, $client, $schedule);
    }
}

sub _executeTaskReal {
    my ($self, $controller, $name, $prolog, $client, $schedule) = @_;

    my $class = "FusionInventory::Agent::Task::$name";

    $class->require();

    my $task = $class->new(
        confdir      => $self->{confdir},
        datadir      => $self->{datadir},
        logger       => $self->{logger},
        deviceid     => $self->{deviceid},
    );

    my %configuration = $task->getConfiguration(
        prolog   => $prolog,
        schedule => $schedule,
        client   => $client,
        url      => $controller->getURL(),
    );
    if (!%configuration) {
        $self->{logger}->debug("no $name task execution requested");
        return;
    }

    $task->configure(
        tag                => $self->{config}->{tag},
        timeout            => $self->{config}->{'collect-timeout'},
        additional_content => $self->{config}->{'additional-content'},
        scan_homedirs      => $self->{config}->{'scan-homedirs'},
        no_category        => $self->{config}->{'no-category'},
        %configuration
    );

    $self->{logger}->info("running task $name");
    $self->{current_task} = $task;

    my $target = FusionInventory::Agent::Target::Server->new(
        url    => $controller->getURL(),
        client => $client
    );

    $task->run(
        target => $target,
        client => $client
    );
    delete $self->{current_task};
}

sub getStatus {
    my ($self) = @_;
    return $self->{status};
}

sub getControllers {
    my ($self) = @_;

    return @{$self->{controllers}};
}

sub getAvailableModules {
    my ($self, %params) = @_;

    my %modules;
    my %disabled  = map { lc($_) => 1 } @{$params{disabled}};

    # tasks may be located only in agent libdir
    my $directory = $self->{libdir};
    $directory =~ s,\\,/,g;
    my $subdirectory = "FusionInventory/Agent/Task";
    # look for all perl modules here
    foreach my $file (File::Glob::glob("$directory/$subdirectory/*.pm")) {
        next unless $file =~ m{($subdirectory/(\S+)\.pm)$};
        my $module = file2module($1);
        my $name = file2module($2);

        next if $disabled{lc($name)};

        my $version;
        if ($self->{config}->{daemon} || $self->{config}->{service}) {
            # server mode: check each task version in a child process
            my ($reader, $writer);
            pipe($reader, $writer);
            $writer->autoflush(1);

            if (my $pid = fork()) {
                # parent
                close $writer;
                $version = <$reader>;
                close $reader;
                waitpid($pid, 0);
            } else {
                # child
                die "fork failed: $ERRNO" unless defined $pid;

                close $reader;
                $version = $self->_getModuleVersion($module);
                print $writer $version if $version;
                close $writer;
                exit(0);
            }
        } else {
            # standalone mode: check each task version directly
            $version = $self->_getModuleVersion($module);
        }

        # no version means non-functionning task
        next unless $version;

        $modules{$name} = $version;
    }

    return %modules;
}

sub _getModuleVersion {
    my ($self, $module) = @_;

    my $logger = $self->{logger};

    if (!$module->require()) {
        $logger->debug2("module $module does not compile: $@") if $logger;
        return;
    }

    if (!$module->isa('FusionInventory::Agent::Task')) {
        $logger->debug2("module $module is not a task") if $logger;
        return;
    }

    my $version;
    {
        no strict 'refs';  ## no critic
        $version = ${$module . '::VERSION'};
    }

    return $version;
}

sub _loadState {
    my ($self) = @_;

    my $data = $self->{storage}->restore(name => 'FusionInventory-Agent');

    $self->{deviceid} = $data->{deviceid} if $data->{deviceid};
}

sub _saveState {
    my ($self) = @_;

    $self->{storage}->save(
        name => 'FusionInventory-Agent',
        data => {
            deviceid => $self->{deviceid},
        }
    );
}

# compute an unique agent identifier, based on host name and current time
sub _computeDeviceId {
    my $hostname = getHostname();

    my ($year, $month , $day, $hour, $min, $sec) =
        (localtime (time))[5, 4, 3, 2, 1, 0];

    return sprintf "%s-%02d-%02d-%02d-%02d-%02d-%02d",
        $hostname, $year + 1900, $month + 1, $day, $hour, $min, $sec;
}

1;
__END__

=head1 NAME

FusionInventory::Agent - Fusion Inventory agent

=head1 DESCRIPTION

This is the agent object.

=head1 METHODS

=head2 new(%params)

The constructor. The following parameters are allowed, as keys of the %params
hash:

=over

=item I<confdir>

the configuration directory.

=item I<datadir>

the read-only data directory.

=item I<vardir>

the read-write data directory.

=item I<options>

the options to use.

=back

=head2 init()

Initialize the agent.

=head2 run()

Run the agent.

=head2 terminate()

Terminate the agent.

=head2 getStatus()

Get the current agent status.

=head2 getControllers()

Get all controllers.

=head2 getAvailableModules()

Get all available modules found on the system, as a list of module / version
pairs:

(
    'Foo' => x,
    'Bar' => y,
);

=head1 LICENSE

This software is licensed under the terms of GPLv2+, see LICENSE file for
details.
