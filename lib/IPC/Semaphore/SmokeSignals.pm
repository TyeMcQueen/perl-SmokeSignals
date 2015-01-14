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
sub _smoke { 0 }
sub _stoke { 1 }
sub _bytes { 2 }
sub _puffs { 3 }


sub LightUp {   # Set up a new pipe.
    return __PACKAGE__->Ignite( @_ );
}


sub Ignite {    # Set up a new pipe.
    my( $class, @fuel ) = @_;
    $class ||= __PACKAGE__;
    @fuel = 1
        if  ! @fuel;
    my $bytes = length $fuel[0];
    my $smoke = IO::Handle->new();
    my $stoke = IO::Handle->new();
    pipe( $smoke, $stoke )
        or  _croak( "Can't ignite pipe: $!\n" );
    binmode $smoke;
    binmode $stoke;
    my $me = bless [], $class;
    $me->[_smoke] = $smoke;
    $me->[_stoke] = $stoke;
    $me->[_bytes] = $bytes;
    $me->[_puffs] = 0 + @fuel;
    for my $puff (  @fuel  ) {
        $me->_Stoke( $puff );
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
    my( $smoke ) = $me->[_smoke];
    my $puff;
    sysread( $smoke, $puff, $me->[_bytes] )
        or  die "Can't toke pipe: $!\n";
    return $puff;
}


sub _Stoke {        # Return some magic smoke (skipping proper protocol).
    my( $me, $puff ) = @_;
    my $stoke = $me->[_stoke];
    my $bytes = $me->[_bytes];
    if(  $bytes != length $puff  ) {
        _croak( "Tokin ($puff) is ", length($puff), " bytes, not $bytes!" );
    }
    syswrite( $stoke, $puff )
        or  die "Can't stoke pipe: $!\n";
}


sub Extinguish {    # Last call!
    my( $me ) = @_;
    for my $puffs (  $me->[_puffs]  ) {
        while(  $puffs  ) {
            $me->_Bogart();
            --$puffs;
        }
    }
    close $me->[_stoke];
    close $me->[_smoke];
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

    BEGIN {
        my $pipe = LightUp();

        sub threadSafe
        {
            my $puff = $pipe->Puff();
            # Only one thread will run this code at a time!
        }
    }

=head1 DESCRIPTION

A friend couldn't get APR::ThreadMutex to work so I offered to roll my own
mutual exclusion code when, *bong*, I realized this would be trivial to do
with a simple pipe.

It is easiest to use as a very simple mutex (see Synopsis above).

You can also use this as a semaphore on a relatively small number of relatively
small tokins (each tokin must be the same number of bytes and the total
number of bytes should be less than your system buffer size or else things
will hang).

It also happens to give out tokins in LRU order (least recently used).

To use it as a semaphore / LRU:

    BEGIN {
        my $bong = LightUp( 0..9 );
        my @pool;

        sub sharesResource
        {
            my $dragon = $bong->Puff();
            # Only 10 threads at once can run this code!
            my $puff = $dragon->Sniff();
            # $puff is 0..9 and is unique among the threads here now
            Do_exclusive_stuff_with( $pool[$puff] );
            if(  ...  ) {
                $dragon->Exhale();  # Return our tokin prematurely
                die ExpensivePostMortem();
            }
        }

        sub stowParaphenalia
        {
            # Calling all magic dragons; waiting for them to exhale:
            $bong->Extinguish();
            ...
        }

    }

=head1 PLANS

A future version will allow for non-blocking checking as to whether there are
any tokins currently available and for setting a maximum wait time.

A future version will allow for using a named pipe to make it easy for several
processes to share one pipe.

=head1 CONTRIBUTORS

Author: Tye McQueen, http://perlmonks.org/?node=tye

=cut
