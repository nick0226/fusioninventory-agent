#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use FusionInventory::Agent::Task::Inventory::Input::Linux::LVM; 

my %lvs = (
    'linux-1' => [
        {
            LV_UUID   => '2ByrwP-byIK-8twm-qyHd-Bjm9-EwFd-CzPaAd',
            SIZE      => 5901,
            ATTR      => '-wi-ao',
            VG_UUID   => 'Eubwcw-UFh2-P3Kn-aI6y-qcLT-VCzU-ls49ha',
            LV_NAME   => 'home',
            SEG_COUNT => '1'
        },
        {
            LV_UUID   => 'riXTVv-5mnl-GuL8-ScBl-MZXk-iXZu-QZsAz4',
            SIZE      => 348,
            ATTR      => '-wi-ao',
            VG_UUID   => 'Eubwcw-UFh2-P3Kn-aI6y-qcLT-VCzU-ls49ha',
            LV_NAME   => 'root',
            SEG_COUNT => '1'
        },
        {
            LV_UUID   => 'OHAvld-GHNN-OXCe-RgMc-gai7-Kybd-8BKTY8',
            SIZE      => 893,
            ATTR      => '-wi-ao',
            VG_UUID   => 'Eubwcw-UFh2-P3Kn-aI6y-qcLT-VCzU-ls49ha',
            LV_NAME   => 'swap_1',
            SEG_COUNT => '1'
        },
        {
            LV_UUID   => 'KxoaKL-QUpk-y6hr-aCdX-0d2g-RlGG-jX0Nf5',
            SIZE      => 398,
            ATTR      => '-wi-ao',
            VG_UUID   => 'Eubwcw-UFh2-P3Kn-aI6y-qcLT-VCzU-ls49ha',
            LV_NAME   => 'tmp',
            SEG_COUNT => '1'
        },
        {
            LV_UUID   => 'jJBN5Y-Fi5d-ee15-zL38-OCPh-HAfn-fnjbri',
            SIZE      => 5611,
            ATTR      => '-wi-ao',
            VG_UUID   => 'Eubwcw-UFh2-P3Kn-aI6y-qcLT-VCzU-ls49ha',
            LV_NAME   => 'usr',
            SEG_COUNT => '1'
        },
        {
            LV_UUID   => 'RULgoh-9Wey-1b0F-glTA-jYTY-eJdL-ThTqNM',
            SIZE      => 2692,
            ATTR      => '-wi-ao',
            VG_UUID   => 'Eubwcw-UFh2-P3Kn-aI6y-qcLT-VCzU-ls49ha',
            LV_NAME   => 'var',
            SEG_COUNT => '1'
        },
        {
            LV_UUID   => 'd7HvFr-XI61-W7tF-zjh8-hfqj-TH3G-AOi5Ul',
            SIZE      => 104,
            ATTR      => '-wi-a-',
            VG_UUID   => 'ZHOqQg-SNQJ-a79U-Jfn1-Az84-e04w-d9zH23',
            LV_NAME   => 'lvol0',
            SEG_COUNT => '1'
        },
        {
            LV_UUID   => 'FUrHhK-H53S-AWV6-lqcK-tcTm-dHYb-xIbhQs',
            SIZE      => 104,
            ATTR      => '-wi-a-',
            VG_UUID   => 'ZHOqQg-SNQJ-a79U-Jfn1-Az84-e04w-d9zH23',
            LV_NAME   => 'lvol1',
            SEG_COUNT => '1'
        }
    ]
);

my %pvs = (
    'linux-1' => [
        {
            SIZE        => 15846,
            FORMAT      => 'lvm2',
            ATTR        => 'a-',
            FREE        => 0,
            DEVICE      => '/dev/sda5',
            PV_NAME     => 'lvm',
            PV_PE_COUNT => '3778',
            PE_SIZE     => 4,
            PV_UUID     => 'MjsnP7-GaGC-NIo7-tS3o-gf2t-di2R-eP3Au7',
            VG_UUID     => undef
        },
        {
            SIZE        => 2466,
            FORMAT      => 'lvm2',
            ATTR        => 'a-',
            FREE        => 2256,
            DEVICE      => '/dev/sdb1',
            PV_NAME     => 'lvm2',
            PV_PE_COUNT => '588',
            PE_SIZE     => 4,
            PV_UUID     => 'LNDa6y-PQGQ-gtnc-c7Wc-W2lS-Soaf-Bwu2Me',
            VG_UUID     => undef
        },
        {
            SIZE        => 2894,
            FORMAT      => 'lvm2',
            ATTR        => 'a-',
            FREE        => 2894,
            DEVICE      => '/dev/sdb2',
            PV_NAME     => 'lvm2',
            PV_PE_COUNT => '690',
            PE_SIZE     => 4,
            PV_UUID     => 'xkxfmu-fQLt-DtKZ-YnkY-vwcj-JqC2-WmQddD',
            VG_UUID     => undef
        }
    ],
    'linux-2' => [
        {
            SIZE        => 311452,
            FORMAT      => 'lvm2',
            ATTR        => 'a--',
            FREE        => 125694,
            DEVICE      => '/dev/sda2',
            PV_NAME     => 'vg00',
            PV_PE_COUNT => 9282,
            PE_SIZE     => 33,
            PV_UUID     => 'CnCKHH-tnlS-BFL5-qRMa-HaV2-10zm-kNIpEp',
            VG_UUID     => 'OFXZR2-dEjD-qVIj-VJnw-1dQY-wC57-O1TABn'
        },
        {
            SIZE        => 58921,
            FORMAT      => 'lvm2',
            ATTR        => 'a--',
            FREE        => 18119,
            DEVICE      => '/dev/sdb2',
            PV_NAME     => 'vg00',
            PV_PE_COUNT => 1756,
            PE_SIZE     => 33,
            PV_UUID     => 'XMzcNr-5qrL-pXk1-9Ycl-FyfN-nXPe-ndRvHF',
            VG_UUID     => 'OFXZR2-dEjD-qVIj-VJnw-1dQY-wC57-O1TABn'
        },
        {
            SIZE        => 500095,
            FORMAT      => 'lvm2',
            ATTR        => 'a--',
            FREE        => 241323,
            DEVICE      => '/dev/sdc1',
            PV_NAME     => 'vg00',
            PV_PE_COUNT => 14904,
            PE_SIZE     => 33,
            PV_UUID     => 'GnT78t-kb92-k8di-1uUv-28HK-H6za-SXe2EZ',
            VG_UUID     => 'OFXZR2-dEjD-qVIj-VJnw-1dQY-wC57-O1TABn'
        }
    ]
);

my %vgs = (
    'linux-1' => [
        {
            SIZE           => 15846,
            ATTR           => 'wz--n-',
            VG_NAME        => 'lvm',
            FREE           => 0,
            PV_COUNT       => '1',
            VG_UUID        => 'Eubwcw-UFh2-P3Kn-aI6y-qcLT-VCzU-ls49ha',
            LV_COUNT       => '6',
            VG_EXTENT_SIZE => '4.19'
        },
        {
            SIZE           => 5360,
            ATTR           => 'wz--n-',
            VG_NAME        => 'lvm2',
            FREE           => 5150,
            PV_COUNT       => '2',
            VG_UUID        => 'ZHOqQg-SNQJ-a79U-Jfn1-Az84-e04w-d9zH23',
            LV_COUNT       => '2',
            VG_EXTENT_SIZE => '4.19'
        }
    ],
    'linux-2' => [
        {
            'SIZE' => 870469,
            'ATTR' => 'wz--n-',
            'VG_NAME' => 'vg00',
            'FREE' => 385137,
            'PV_COUNT' => '3',
            'VG_UUID' => 'OFXZR2-dEjD-qVIj-VJnw-1dQY-wC57-O1TABn',
            'LV_COUNT' => '16',
            'VG_EXTENT_SIZE' => '33.55'
        }
    ]
);

plan tests =>
    (scalar keys %pvs) +
    (scalar keys %lvs) +
    (scalar keys %vgs);

foreach my $test (keys %pvs) {
    my @pvs = FusionInventory::Agent::Task::Inventory::Input::Linux::LVM::_getPhysicalVolumes(file => 'resources/lvm/linux/pvs/'.$test);
    is_deeply(\@pvs, $pvs{$test}, '_parsePvs()');
}

foreach my $test (keys %lvs) {
    my @lvs = FusionInventory::Agent::Task::Inventory::Input::Linux::LVM::_getLogicalVolumes(file => 'resources/lvm/linux/lvs/'.$test);
    is_deeply(\@lvs, $lvs{$test}, '_parseLvs()');
}

foreach my $test (keys %vgs) {
    my @vgs = FusionInventory::Agent::Task::Inventory::Input::Linux::LVM::_getVolumeGroups(file => 'resources/lvm/linux/vgs/'.$test);
    is_deeply(\@vgs, $vgs{$test}, '_parseVgs()');
}