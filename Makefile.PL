#!/usr/bin/perl -w
use strict;
use ExtUtils::MakeMaker;
# Run "perldoc ExtUtils::MakeMaker" for more information.

my $mod = 'lib/IPC/Semaphore/SmokeSignals.pm';
my $v = $ExtUtils::MakeMaker::VERSION;
WriteMakefile(
    'NAME'              => 'IPC::Semaphore::SmokeSignals',
    'VERSION_FROM'      => $mod,
    'PREREQ_PM'         => {
        'strict' => 0,                  # in 'core'
    },
    $] < 5.005  ?  ()  :  (
        'AUTHOR'        => 'Tye McQueen',
        'ABSTRACT_FROM' => $mod,
    ),
    $v < 6.31  ?  ()  :  (
        LICENSE => 'unrestricted' ),
);
