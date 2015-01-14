#!/usr/bin/perl -w
use strict;

use File::Basename          qw< dirname >;
use lib dirname(__FILE__) . '/../inc';

use TyeTest  qw<
    plan skip Okay True False Note Dump SkipIf Lives Dies Warns LinesLike >;

BEGIN {
    my $t = dirname( __FILE__ );
    if( -d "$t/../blib" ) {
        lib->import( "$t/../blib/arch", "$t/../blib/lib" );
    } elsif( -d "$t/../lib" ) {
        lib->import( "$t/../lib" );
    }
}

plan( tests => 5 );

require IPC::Semaphore::SmokeSignals;
my $mod = 'IPC::Semaphore::SmokeSignals';

Okay( 1, 1, 'Module loads' );

# Make this test die if it ever hangs:
alarm( 10 );

$mod->import('LightUp');

my $pipe = LightUp();
True( $pipe, 'Can create a pipe' );

my $dragon = $pipe->Puff();
True( $dragon, 'Can toke' );

undef $dragon;
$dragon = $pipe->Puff();
True( $dragon, 'Can re-toke' );

$dragon->Exhale();
my $puff = $pipe->Puff();
True( $puff, 'Can re-toke after Exhale' );
undef $puff;
