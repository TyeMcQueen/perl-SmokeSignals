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
use Errno   qw< EAGAIN EWOULDBLOCK >;

sub _SMOKE { 0 }    # End to pull from.
sub _STOKE { 1 }    # The lit end.
sub _BYTES { 2 }    # Tokin' length.
sub _PUFFS { 3 }    # How many tokins; how many tokers at once.
sub _OWNER { 4 }    # PID of process that created this pipe.


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
    @$fuel = 1
        if  ! @$fuel;

    my $bytes = length $fuel->[0];
    my $me = $class->_New( $bytes );

    $me->_Roll( $fuel );

    return $me;
}


sub _Roll {     # Put the fuel in.
    my( $me, $fuel ) = @_;
    $me->[_OWNER] = $$;
    my $stoke = $me->[_STOKE];
    $stoke->blocking( 0 );
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
    $stoke->blocking( 1 );
}


sub _MagicDragon {  # Every magic dragon needs a good name.
    return __PACKAGE__ . '::Puff';
}


sub Puff {          # Get a magic dragon so you won't forget to share.
    my( $me, $impatient ) = @_;
    return $me->_MagicDragon()->_Inhale( $me, $impatient );
}


sub _Bogart {       # Take a drag (skipping proper protocol).
    my( $me, $impatient ) = @_;
    my( $smoke ) = $me->[_SMOKE];
    $smoke->blocking( 0 )
        if  $impatient;
    my $puff;
    my $got_none = ! sysread( $smoke, $puff, $me->[_BYTES] );
    my $excuse = $!;
    $smoke->blocking( 1 )
        if  $impatient;
    return undef
        if  $impatient
        &&  $got_none
        &&  (   EAGAIN() == $excuse
            ||  EWOULDBLOCK() == $excuse )
    ;
    _croak( "Can't toke pipe: $!\n" )
        if  $got_none;
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
        or  die "Can't stoke pipe (with '$puff'): $!\n";
}


# Returns undef if we aren't allowed to extinguish it.
# Returns 0 if pipe is now completely extinguished.
# Otherwise, returns number of outstanding tokins remaining.

sub Extinguish {    # Last call!
    my( $me, $impatient ) = @_;
    return undef                # We didn't start the fire!
        if  $$ != ( $me->[_OWNER] || 0 );
    return $me->[_PUFFS]        # We didn't or we already put it out.
        if  ! $me->[_PUFFS];
    if( 0 < $me->[_PUFFS] ) {   # Our first try at shutting down.
        $me->[_PUFFS] *= -1;    # Mark that we started shutting down.
    }
    for my $puffs (  $me->[_PUFFS]  ) {
        while(  $puffs  ) {
            my $puff = $me->_Bogart( $impatient );
            if( ! defined $puff ) {     # Pipe empty:
                return -$puffs;         # Tell caller: somebody needs time.
            }
            ++$puffs;   # Modifies $me->[_PUFFS].
        }
    }
    close $me->[_STOKE];
    close $me->[_SMOKE];
    return 0;
}


sub _croak {
    require Carp;
    Carp::croak( @_ );
}


our @CARP_NOT;

package IPC::Semaphore::SmokeSignals::Puff;
push @CARP_NOT, __PACKAGE__;

sub _Inhale {
    my( $class, $pipe, $impatient ) = @_;
    my $puff = $pipe->_Bogart($impatient)
        or  return undef;
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
number of bytes should be less than your pipe's capacity or else you're in
for a bad trip).

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

=head1 EXPORTS

There is 1 function that you can request to be exported into your package.
It serves to prevent you from having to type the rather long module name
(IPC::Semaphore::SmokeSignals) more than once.

=head2 LightUp

C<LightUp()> activates a new pipe for coordinating that only $N things can
happen at once.

    use IPC::Semaphore::SmokeSignals 'LightUp';

    $pipe = LightUp( $fuel );

There are several ways you can specify C<$fuel>:

    my $pipe = LightUp();
    # same as:
    my $pipe = LightUp(1);

    my $pipe = LightUp(50);
    # same as:
    my $pipe = LightUp(['01'..'50']);

C<LightUp(...)> is just short for:

    IPC::Semaphore::SmokeSignals->Ignite(...);

An un-named pipe is used.  This has the advantages of requiring no clean-up
and having no chance of colliding identifiers (unlike with SysV semaphores).

The only argument, C<$fuel>, if given, should be one of:

=over

=item A false value

This is the same as passing in a '1'.

=item An array reference

The array should contain 1 or more strings, all having the same length (in
bytes).

=item A positive integer

Passing in C<$N> gives you C<$N> tokins each of length C<length($N)>.  So
C<12> is the same as C<['01'..'12']>.

=back

=head1 METHODS

=head2 Ignite

    my $pipe = IPC::Semaphore::SmokeSignals->Ignite( $fuel );

See L<LightUp>.

=head2 Puff

    my $dragon = $pipe->Puff();

    my $dragon = $pipe->Puff('impatient');

C<Puff()> takes a drag on your pipe and stores the tokin' it gets in a magic
dragon that it gives to you.  Store the dragon in a lexical variable so that
when you leave the scope of that variable, the tokin' will automatically be
returned to the pipe (when the variable holding the dragon is destroyed),
making that tokin' available to some other pipe user.

The usual case is to use a semaphore to protect a block of code from being
run by too many processes (or threads) at the same time.

If you need to keep your tokin' reserved beyond any lexical scope containing
your call to C<Puff()>, then you can pass the dragon around, even making
copies of it.  When the last copy is destroyed, the tokin' will be returned.
Or you can release it early by calling C<Exhale()> on it.

If there are no available tokins, then the call to C<Puff()> will block,
waiting for a tokin' to become available.  Alternately, you can pass in a
true value as the only argument to C<Puff()> and this will cause C<Puff()>
to return immediately, either returning a magic dragon containing a tokin'
or just returning a false value.

For example:

    {
        my $dragon = $pipe->Puff('impatient');
        if( ! $dragon ) {
            warn "Can't do that right now.\n";
        } else {
            # This code must never run more than $N times at once:
            ...
        }
    }

=head2 Sniff

    my $tokin = $dragon->Sniff();

Calling C<Sniff()> on a magic dragon returned from C<Puff()> will let you see
the value of the tokin' that you have reserved.

Calling C<Sniff()> on a magic dragon that has already had C<Exhale()> called
on it will return C<undef>.

=head2 Exhale

    $dragon->Exhale();

Calling C<Exhale()> on a magic dragon returned from C<Puff()> causes the
dragon to release the reserved tokin' immediately.

This can also be done by just overwriting the dragon, for example:

    $dragon = undef;

but only if C<$dragon> is the last/only existing copy of the dragon.

=head2 Extinguish

    $pipe->Extinguish();

    my $leftovers = $pipe->Extinguish( 'impatient' );

C<Extinguish()> marks the pipe as being shut down and starts pulling out and
discarding all of the tokins in it.

=head1 PLANS

A future version may allow for setting a maximum wait time.

A future version will allow for using a named pipe to make it easy for several
processes to share one pipe.

=head1 CONTRIBUTORS

Author: Tye McQueen, http://perlmonks.org/?node=tye

=cut
