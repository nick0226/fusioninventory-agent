package FusionInventory::Agent::Task::Inventory::Input::MacOS::Sound;

use strict;
use warnings;

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::MacOS;

sub isEnabled {
    return 
        -r '/usr/sbin/system_profiler';
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};

    my $infos = getSystemProfilerInfos();
    my $info = $infos->{'Audio (Built In)'};

    foreach my $sound (keys %$info){
        $inventory->addEntry(
            section => 'SOUNDS',
            entry   => {
                NAME         => $sound,
                MANUFACTURER => $sound,
                DESCRIPTION  => $sound,
            }
        );
    }
}

1;
