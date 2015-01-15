#!/usr/bin/perl -w
use strict;

use Time::HiRes             qw< sleep >;
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

use IPC::Semaphore::SmokeSignals qw< MeetUp >;

sub async {
    return  # Parent
        if  fork();
    exec( @_ );
    die "Can't exec: $!\n";
}

if( $^O =~ /MSWin/ ) {
    print "1..0 # SKIP no mkfifo on Windows\n";
    exit 0;
}
plan( tests => 7 );

my $mod = 'IPC::Semaphore::SmokeSignals';
my $fifo = "/tmp/fifo.$$";
Note( " fifo=$fifo" );
END { unlink $fifo if $fifo; }

# Make this test die if it ever hangs:
alarm( 10 );

my $pipe;
Warns( 'Warns when creating', sub {
    $pipe = MeetUp( 2, $fifo, 0666 );
}, qr/\Q$fifo/, 'creat' );

True( $pipe, 'Can create a pipe' );

my $dragon = $pipe->Puff();
True( $dragon, 'Can toke' );
Note( $dragon->Sniff() );

async( $^X, "$0.pl", 0.5 );
sleep( 0.3 );

{
    my $fail = $pipe->Puff(1);
    False( $fail, "Not yet" )
        or  Note( $fail->Sniff() );
}
{
    my $okay = $pipe->Puff();
    True( $okay, "Patience rewarded" )
        and Note( $okay->Sniff() );
}
