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

use IPC::Semaphore::SmokeSignals qw< LightUp >;

plan( tests => 1 );

my $isWin = $^O =~ /MSWin/ ? 'blocking(0) is a no-op on Windows' : '';

# Make this test die if it ever hangs:
alarm( 10 );

my $mod = 'IPC::Semaphore::SmokeSignals';

my $pipe = LightUp(['a'..'z']);

my @bet;
while( 1 ) {
    last
        if  $isWin && 25 < @bet;
    my $d = $pipe->Puff(1) or last;
    push @bet, $d;
}

for(qw< f4fa abaa aaed 6016 5512 1102 >) {
    splice @bet, hex($_), 1
        for /./g;
}
my $w = '';
my $d = $pipe->Puff();
for( 1..6 ) {
    $w .= ' ';
    my @t;
    for( 1..4 ) {
        $w .= $d->Sniff();
        push @t, $d;
        $d = $pipe->Puff();
    }
}
Okay( ' perl monq styx hack judg fibz', $w );
