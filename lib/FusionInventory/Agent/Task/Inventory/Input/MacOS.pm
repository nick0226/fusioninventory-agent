package FusionInventory::Agent::Task::Inventory::Input::MacOS;

use strict;
use warnings;

use English qw(-no_match_vars);

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::MacOS;

sub isEnabled {
    return $OSNAME eq 'darwin';
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};

    my $infos = getSystemProfilerInfos();
    my $SystemVersion =
        $infos->{'Software'}->{'System Software Overview'}->{'System Version'};

    my ($OSName, $OSVersion);
    if ($SystemVersion =~ /^(.*?)\s+(\d+.*)/) {
        $OSName = $1;
        $OSVersion = $2;
    } else {
        # Default values
        $OSName = "Mac OS X";
    }

    # add the uname -v as the comment, not really needed, but extra info
    # never hurt
    my $OSComment = getFirstLine(command => 'uname -v');
    my $KernelVersion = getFirstLine(command => 'uname -r');

    $inventory->setHardware({
        OSNAME     => $OSName,
        OSCOMMENTS => $OSComment,
        OSVERSION  => $OSVersion,
    });

    $inventory->setOperatingSystem({
        NAME                 => "MacOSX",
        VERSION              => $OSVersion,
        KERNEL_VERSION       => $KernelVersion,
        FULL_NAME            => $OSName
    });
}

1;
