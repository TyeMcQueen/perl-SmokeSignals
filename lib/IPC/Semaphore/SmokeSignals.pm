package IPC::Semaphore::SmokeSignals;
use strict;

use vars qw< $VERSION @EXPORT_OK >;
BEGIN {
    $VERSION = 0.001_002;
    @EXPORT_OK = qw< LightUp >;
    require IO::Handle;
    require Exporter;
    *import = \&Exporter::import;
    if(  eval { require bytes; 1 }  ) {
        bytes->import();
    }
}

sub _SMOKE { 0 }    # End to pull from.
sub _STOKE { 1 }    # The lit end.
sub _BYTES { 2 }    # Tokin' length.
sub _PUFFS { 3 }    # How many tokins; how many tokers at once.


sub LightUp {   # Set up a new pipe.
    return __PACKAGE__->Ignite( @_ );
}


sub _New {
    my( $class, $bytes ) = @_;

    my $smoke = IO::Handle->new();
    my $stoke = IO::Handle->new();
    pipe( $smoke, $stoke )
        or  _croak( "Can't ignite pipe: $!\n" );
    binmode $smoke;
    binmode $stoke;

    my $me = bless [], ref $class || $class;
    $me->[_SMOKE] = $smoke;
    $me->[_STOKE] = $stoke;
    $me->[_BYTES] = $bytes;

    return $me;
}


sub Ignite {    # Set up a new pipe.
    my( $class, $fuel ) = @_;
    $fuel = [ $fuel || 1 ]
        if  ! ref $fuel;

    my $bytes = length $fuel->[0];
    my $me = $class->_New( $bytes );

    if( 1 == @$fuel && $fuel->[0] =~ /^[1-9][0-9]*$/ ) {
        $me->[_PUFFS] = 0 + $fuel->[0];
        my $start = '0' x length $fuel->[0];
        $start =~ s/0$/1/;
        for my $puff (  "$start" .. "$fuel->[0]"  ) {
            $me->_Stoke( $puff );
        }
    } else {
        $me->[_PUFFS] = 0 + @$fuel;
        for my $puff (  @$fuel  ) {
            $me->_Stoke( $puff );
        }
    }

    return $me;
}


sub _MagicDragon {  # Every magic dragon needs a good name.
    return __PACKAGE__ . '::Puff';
}


sub Puff {          # Get a magic dragon so you won't forget to share.
    my( $me ) = @_;
    return $me->_MagicDragon()->Inhale( $me );
}


sub _Bogart {       # Take a drag (skipping proper protocol).
    my( $me ) = @_;
    my( $smoke ) = $me->[_SMOKE];
    my $puff;
    sysread( $smoke, $puff, $me->[_BYTES] )
        or  die "Can't toke pipe: $!\n";
    return $puff;
}


sub _Stoke {        # Return some magic smoke (skipping proper protocol).
    my( $me, $puff ) = @_;
    my $stoke = $me->[_STOKE];
    my $bytes = $me->[_BYTES];
    if(  $bytes != length $puff  ) {
        _croak( "Tokin' ($puff) is ", length($puff), " bytes, not $bytes!" );
    }
    syswrite( $stoke, $puff )
        or  die "Can't stoke pipe: $!\n";
}


sub Extinguish {    # Last call!
    my( $me ) = @_;
    for my $puffs (  $me->[_PUFFS]  ) {
        while(  $puffs  ) {
            $me->_Bogart();
            --$puffs;
        }
    }
    close $me->[_STOKE];
    close $me->[_SMOKE];
}


sub _croak {
    require Carp;
    Carp::croak( @_ );
}


package IPC::Semaphore::SmokeSignals::Puff;

sub Inhale {
    my( $class, $pipe ) = @_;
    my $puff = $pipe->_Bogart();
    return bless [ $pipe, $puff ], $class;
}

sub Sniff {
    my( $me ) = @_;
    return $me->[1];
}

sub Exhale {
    my( $me ) = @_;
    return
        if  ! @$me;
    my( $pipe, $puff ) = splice @$me;
    $pipe->_Stoke( $puff );
}

sub DESTROY {
    my( $me ) = @_;
    $me->Exhale();
}


1;
__END__

=head1 NAME

IPC::Semaphore::SmokeSignals - A mutex and an LRU from crack pipe technology

=head1 SYNOPSIS

    use IPC::Semaphore::SmokeSignals qw< LightUp >;

    my $pipe = LightUp();

    sub threadSafe
    {
        my $puff = $pipe->Puff();
        # Only one thread will run this code at a time!
        ...
    }

=head1 DESCRIPTION

A friend couldn't get APR::ThreadMutex to work so I offered to roll my own
mutual exclusion code when, *bong*, I realized this would be trivial to do
with a simple pipe.

It is easiest to use as a very simple mutex (see Synopsis above).

You can also use this as a semaphore on a relatively small number of relatively
small tokins (each tokin' must be the same number of bytes and the total
number of bytes should be less than your system buffer size or else things
will hang).

It also happens to give out tokins in LRU order (least recently used).

To use it as a semaphore / LRU:

    my $bong = LightUp( 12 );
    my @pool;

    sub sharesResource
    {
        my $dragon = $bong->Puff();
        # Only 12 threads at once can run this code!

        my $puff = $dragon->Sniff();
        # $puff is '01'..'12' and is unique among the threads here now

        Do_exclusive_stuff_with( $pool[$puff-1] );
        if(  ...  ) {
            $dragon->Exhale();  # Return our tokin' prematurely
            die ExpensivePostMortem();
        }
    }

    sub stowParaphernalia
    {
        # Calling all magic dragons; waiting for them to exhale:
        $bong->Extinguish();
        ...
    }


=head1 PLANS

A future version will allow for non-blocking checking as to whether there are
any tokins currently available and for setting a maximum wait time.

A future version will allow for using a named pipe to make it easy for several
processes to share one pipe.

=head1 CONTRIBUTORS

Author: Tye McQueen, http://perlmonks.org/?node=tye

=cut
