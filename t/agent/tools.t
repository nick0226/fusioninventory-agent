#!/usr/bin/perl

use strict;
use warnings;
use lib 't/lib';

use File::Temp;
use Test::Deep qw(cmp_deeply);
use Test::More;
use Test::Exception;

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::Hardware;

my @size_tests_nok = (
    'foo', undef
);

my @size_tests_ok = (
    [ '1'     , 1       ],
    [ '1 mb'  , 1       ],
    [ '1.1 mb', 1.1     ],
    [ '1 MB'  , 1       ],
    [ '1 gb'  , 1000    ],
    [ '1 GB'  , 1000    ],
    [ '1 tb'  , 1000000 ],
    [ '1 TB'  , 1000000 ],
);

my @speed_tests_nok = (
    'foo', undef
);

my @speed_tests_ok = (
    [ '1 mhz', 1 ],
    [ '1 MHZ', 1 ],
    [ '1 ghz', 1000 ],
    [ '1 GHZ', 1000 ],
    [ '1mhz', 1 ],
    [ '1MHZ', 1 ],
    [ '1ghz', 1000 ],
    [ '1GHZ', 1000 ],
);

my @manufacturer_tests_ok = (
    [ 'maxtor'         , 'Maxtor'          ],
    [ 'sony'           , 'Sony'            ],
    [ 'compaq'         , 'Compaq'          ],
    [ 'ibm'            , 'Ibm'             ],
    [ 'toshiba'        , 'Toshiba'         ],
    [ 'fujitsu'        , 'Fujitsu'         ],
    [ 'lg'             , 'Lg'              ],
    [ 'samsung'        , 'Samsung'         ],
    [ 'nec'            , 'Nec'             ],
    [ 'transcend'      , 'Transcend'       ],
    [ 'matshita'       , 'Matshita'        ],
    [ 'pioneer'        , 'Pioneer'         ],
    [ 'hewlett packard', 'Hewlett-Packard' ],
    [ 'hp'             , 'Hewlett-Packard' ],
    [ 'WDC'            , 'Western Digital' ],
    [ 'western'        , 'Western Digital' ],
    [ 'ST'             , 'Seagate'         ],
    [ 'seagate'        , 'Seagate'         ],
    [ 'HD'             , 'Hitachi'         ],
    [ 'IC'             , 'Hitachi'         ],
    [ 'HU'             , 'Hitachi'         ],
    [ 'foo'            , 'foo'             ],
);

my @manufacturer_tests_nok = (
    undef
);

my @mac_tests_ok = (
    [ 'd2:05:a8:6c:26:d5'     ,      'd2:05:a8:6c:26:d5' ],
    [ '0xD205A86C26D5'        ,      'd2:05:a8:6c:26:d5' ],
    [ '0x6001D205A86C26D5'    ,      'd2:05:a8:6c:26:d5' ],
    [ ",k\365\233H\204" , '2c:6b:f5:9b:48:84']

);

my @version_tests_ok = (
    [ 1, 0, 1, 0 ],
    [ 1, 1, 1, 0 ],
    [ 2, 0, 1, 0 ],
);

my @version_tests_nok = (
    [ 0, 9, 1, 0 ],
);

my @sanitization_tests = (
    [ "",               ""    ],
    [ "foo",            "foo" ],
    [ "foo\x12",        "foo" ],
    [ "\x12foo",        "foo" ],
    [ "\x12foo\x12",    "foo" ],
    [ "fo\xA9",         "fo©" ],
    [ "fo\xA9\x12",     "fo©" ],
    [ "\x12fo\xA9",     "fo©" ],
    [ "\x12fo\xA9\x12", "fo©" ],
);

my @hex2char_tests = (
    [ '0x41', 'A'  ],
    [ '41',   '41' ],
);

my @hex2dec_tests = (
    [ '0x41', '65' ],
    [ '41',   '41' ],
);

my @dec2hex_tests = (
    [ '65',   '0x41' ],
    [ '0x41', '0x41' ],
);

plan tests =>
    (scalar @size_tests_ok) +
    (scalar @size_tests_nok) +
    (scalar @speed_tests_ok) +
    (scalar @speed_tests_nok) +
    (scalar @manufacturer_tests_ok) +
    (scalar @manufacturer_tests_nok) +
    (scalar @mac_tests_ok) +
    (scalar @version_tests_ok) +
    (scalar @version_tests_nok) +
    (scalar @sanitization_tests) +
    (scalar @hex2char_tests) +
    (scalar @hex2dec_tests) +
    (scalar @dec2hex_tests) +
    20;

foreach my $test (@size_tests_nok) {
    ok(
        !defined getCanonicalSize($test),
        "invalid value size normalisation"
    );
}

foreach my $test (@size_tests_ok) {
    cmp_ok(
        getCanonicalSize($test->[0]),
        '==',
        $test->[1],
        "$test->[0] normalisation"
    );
}

foreach my $test (@speed_tests_nok) {
    ok(
        !defined getCanonicalSpeed($test),
        "invalid value speed normalisation"
    );
}

foreach my $test (@speed_tests_ok) {
    cmp_ok(
        getCanonicalSpeed($test->[0]),
        '==',
        $test->[1],
        "$test->[0] normalisation"
    );
}

foreach my $test (@manufacturer_tests_ok) {
    is(
        getCanonicalManufacturer($test->[0]),
        $test->[1],
        "$test->[0] normalisation"
    );
}

foreach my $test (@manufacturer_tests_nok) {
    ok(
        !defined getCanonicalManufacturer($test),
        "invalid value manufacturer normalisation"
    );
}

foreach my $test (@mac_tests_ok) {
    is(
        getCanonicalMacAddress($test->[0]),
        $test->[1],
        "$test->[0] normalisation"
    );
}

foreach my $test (@version_tests_ok) {
    ok(
        compareVersion(@$test),
        "$test->[0].$test->[1] >= $test->[2].$test->[3]"
    );
}

foreach my $test (@version_tests_nok) {
    ok(
        !compareVersion(@$test),
        "$test->[0].$test->[1] < $test->[2].$test->[3]"
    );
}

foreach my $test (@sanitization_tests) {
    is(
        getSanitizedString($test->[0]),
        $test->[1],
        "$test->[0] sanitization"
    );
}

foreach my $test (@hex2char_tests) {
    is(
        hex2char($test->[0]),
        $test->[1],
        "conversion: $test->[0] to character"
    );
}

foreach my $test (@hex2dec_tests) {
    is(
        hex2dec($test->[0]),
        $test->[1],
        "conversion: $test->[0] to decimal"
    );
}

foreach my $test (@dec2hex_tests) {
    is(
        dec2hex($test->[0]),
        $test->[1],
        "conversion: $test->[0] to hexadecimal"
    );
}

my $tmp = File::Temp->new(UNLINK => $ENV{TEST_DEBUG} ? 0 : 1);
print $tmp "foo\n";
print $tmp "bar\n";
print $tmp "baz\n";
close $tmp;

is(
    getFirstLine(file => $tmp),
    'foo',
    "first line, file reading"
);
is(
    getFirstLine(command => 'perl -e "print qq{foo\nbar\nbaz\n}"'),
    'foo',
    "first line, command reading"
);
is(
    getLastLine(file => $tmp),
    'baz',
    "last line, file reading"
);
is(
    getLastLine(command => 'perl -e "print qq{foo\nbar\nbaz\n}"'),
    'baz',
    "last line, command reading"
);
is(
    getLinesCount(file => $tmp),
    3,
    "lines count, file reading"
);
is(
    getLinesCount(command => 'perl -e "print qq{foo\nbar\n\baz\n}"'),
    3,
    "lines count, command reading"
);
cmp_deeply(
    [ getAllLines(file => $tmp) ],
    [ qw/foo bar baz/ ],
    "all lines, file reading, list context"
);
is(
    getAllLines(file => $tmp),
    "foo\nbar\nbaz\n",
    "all lines, file reading, scalar context"
);
cmp_deeply(
    [ getAllLines(command => 'perl -e "print qq{foo\nbar\nbaz\n}"') ],
    [ qw/foo bar baz/ ],
    "all lines, command reading, list context"
);
is(
    getAllLines(command => 'perl -e "print qq{foo\nbar\nbaz\n}"'),
    "foo\nbar\nbaz\n",
    "all lines, command reading, scalar context"
);
cmp_deeply(
    [ getFirstMatch(file => $tmp, pattern => qr/^(b\w+)$/) ],
    [ qw/bar/ ],
    "first match, file reading, list context"
);
is(
    getFirstMatch(file => $tmp, pattern => qr/^(b\w+)$/),
    'bar',
    "first match, file reading, scalar context"
);
cmp_deeply(
    [ getFirstMatch(command => 'perl -e "print qq{foo\nbar\nbaz\n}"', pattern => qr/^(b\w+)$/) ],
    [ qw/bar/ ],
    "first match, command reading, list context"
);
is(
    getFirstMatch(command => 'perl -e "print qq{foo\nbar\nbaz\n}"', pattern => qr/^(b\w+)$/),
    'bar',
    "first match, command reading, scalar context"
);

my $result1 = runFunction(
    module   => 'FusionInventory::Test::Module',
    function => 'mirror',
    params   => 'foo'
);
ok(!defined $result1, 'indirect function execution, unloaded module');
my $result2 = runFunction(
    module   => 'FusionInventory::Test::Module',
    function => 'mirror',
    params   => 'foo',
    load     => 1
);
is($result2, 'foo', 'indirect function execution, automatic module loading');
runFunction(
    module   => 'FusionInventory::Test::Module',
    function => 'loop',
    params   => 'foo',
    timeout  => 1
);
ok(1, 'indirect infinite loop function execution, timeout');

throws_ok {
    my $instance = getInstance(
        class  => 'No::Such::Class',
    );
} qr/^no such class/,
'failure to load a non-existing class';

throws_ok {
    my $instance = getInstance(
        class  => 'FusionInventory::Agent::Config::Registry'
    );
} qr/^unable to load class/,
'failure to load existing class';

throws_ok {
    my $instance = getInstance(
        class  => 'FusionInventory::Agent::Config::File'
    );
} qr/^unable to instanciate class/,
'failure to instanciate existing class';
