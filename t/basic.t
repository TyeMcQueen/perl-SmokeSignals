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

plan( tests => 13 );

require IPC::Semaphore::SmokeSignals;
my $mod = 'IPC::Semaphore::SmokeSignals';

Okay( 1, 1, 'Module loads' );

# Make this test die if it ever hangs:
alarm( 10 );

Okay( undef, *LightUp{CODE}, 'LightUp not yet imported' );

$mod->import();
Okay( undef, *LightUp{CODE}, 'LightUp not imported by default' );

$mod->import('LightUp');
Okay( sub{\&IPC::Semaphore::SmokeSignals::LightUp},
    sub{*LightUp{CODE}}, 'LightUp imported explicitly' );

my $pipe = LightUp();
True( $pipe, 'Can create a pipe' );

my $dragon = $pipe->Puff();
True( $dragon, 'Can toke' );

False( $pipe->Puff(1), 'Impatience fails' );

undef $dragon;
$dragon = $pipe->Puff();
True( $dragon, 'Can re-toke' );

False( $pipe->Puff(1), 'Impatience re-fails' );

$dragon->Exhale();
my $puff = $pipe->Puff();
True( $puff, 'Can re-toke after Exhale' );
undef $puff;

True( $pipe->Extinguish(), "Can extinguish" );

Dies( "Exceeding your system buffer size fails", sub {
    LightUp(99999)
}, qr/Can't stoke/ );
my $err = $@;
if( $err =~ /Can't stoke pipe \(with '([0-9]+)'\): (.*)/ ) {
    my( $tokin, $errno ) = ( $1, $2 );
    Note( join ' ', " Pipe capacity <", $tokin*length($tokin), '?' );
    Note( " $errno" );
} else {
    Note( " Error: $@" );
}
