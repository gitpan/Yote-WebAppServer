package Yote::ClientObj;

use strict;

use Yote::Obj;

use base 'Yote::AppRoot';

use vars qw($VERSION);

$VERSION = '0.01';

sub new_obj {
    my( $self ) = @_;
    my $new = new Yote::Obj();
    
    
} #new_obj

sub set {
    
}

sub get {
    
}

1;

__END__

=NAME

    Yote::ClientObj

=SYNOPSIS

ClientObj objects provide methods for apps to be developed entirely on the client side.
