package Yote::Obj;

#
# A Yote object, mostly just syntactic sugar
#

use strict;

use Yote::ObjProvider;

use vars qw($VERSION);

$VERSION = '0.01';

sub new {
    my( $pkg, $id ) = @_;
    my $class = ref($pkg) || $pkg;

    my $obj = bless {
        ID       => $id,
        DATA     => {},
    }, $class;

    my $needs_init = ! $obj->{ID};

    $obj->{ID} ||= Yote::ObjProvider::get_id( $obj );
    $obj->init() if $needs_init;

    return $obj;
} #new

# returns true if the object passsed in is the same as this one.
sub is {
    my( $self, $obj ) = @_;
    return ref( $obj ) && $obj->isa( 'Yote::Obj' ) && $obj->{ID} == $self->{ID};
}

sub init {}

sub save {
    my $self = shift;
    Yote::ObjProvider::stow( $self );
} #save

sub AUTOLOAD {
    my( $s, $arg ) = @_;
    my $func = our $AUTOLOAD;

    if( $func =~/:add_to_(.*)/ ) {
        my( $fld ) = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $self, @vals ) = @_;
	    my $get = "get_$fld";
	    my $arry = $self->$get([]); # init array if need be
	    if( ref( $arry ) eq 'Yote::Array' ) {
		$arry->PUSH( @vals );
	    } else {
		push( @$arry, @vals );
	    }
        };
	use strict 'refs';
        goto &$AUTOLOAD;

    }
    elsif( $func =~ /:remove_from_(.*)/ ) {
        my $fld = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $self, $val ) = @_;
	    my $get = "get_$fld";
	    my $arry = $self->$get([]); # init array if need be
            my $count = grep { $_ eq $val } @$arry;
            while( $count ) {
                for my $i (0..$#$arry) {
                    if( $arry->[$i] eq $val ) {
                        --$count;
			if( ref( $arry ) eq 'Yote::Array' ) {
			    $arry->SPLICE( $i, 1 );
			} else {
			    splice @$arry, $i, 1;
			}
                        last;
                    }
                }
            }
        };
	use strict 'refs';
        goto &$AUTOLOAD;

    }
    elsif ( $func =~ /:set_(.*)/ ) {
        my $fld = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $self, $val ) = @_;
            my $inval = Yote::ObjProvider::xform_in( $val );
            Yote::ObjProvider::dirty( $self, $self->{ID} ) if $self->{DATA}{$fld} ne $inval;
            $self->{DATA}{$fld} = $inval
        };
        goto &$AUTOLOAD;
    }
    elsif( $func =~ /:get_(.*)/ ) {
        my $fld = $1;
        no strict 'refs';
        *$AUTOLOAD = sub {
            my( $self, $init_val ) = @_;
            if( ! defined( $self->{DATA}{$fld} ) && defined($init_val) ) {
                $self->{DATA}{$fld} = Yote::ObjProvider::xform_in( $init_val );
		if( ref( $init_val ) ) {
		    Yote::ObjProvider::dirty( $init_val, $self->{DATA}{$fld} );
		}
                Yote::ObjProvider::dirty( $self, $self->{ID} );
            }
            return Yote::ObjProvider::xform_out( $self->{DATA}{$fld} );
        };
	use strict 'refs';
        goto &$AUTOLOAD;
    }
    else {
        die "Unknown Yote::Obj function '$func'";
    }

} #AUTOLOAD

sub DESTROY {}

1;
__END__

=head1 NAME

Yote::Obj - Base class for all persistant Yote objects.

=head1 DESCRIPTION

Yote::Obj is a container class with hooks into the persistance engine. It has few methods, but dynamically autoloads and installed getters and setters as needed. This class is meant to be overridden by application objects, though it needs no modification to be a perfectly functional container class.

=head2 PUBLIC METHODS

=over 4

=item new

The new method takes no arguments. Any object created with new automatically gets assigned an ID and init is called only once before the object is saved in the data store.

=item init

This is a stub method meant to be overridden by subclasses.

=item is

Returns true if the object passed in is equivalent to this one. Note that only one instance of an individual object will be present at a time in the application server.

=item save

Takes no arguments and causes this object to be written into the datastore. This is automatically called by the application server.

=back

=head2 AUTOLOADED METHODS

=over 4

=item get_foo(initilizing_value)

Returns the value of foo where foo can be any string. This may take a single argument such that if foo is undefined in the object, it will be set to the initial argument. This may return an array reference, hash reference, Yote::Obj or scalar.

=item set_foo(item)

Sets the value of foo to the given argument, which may be an array reference, hash reference, Yote::Obj or scalar.

=item add_to_bar(item)

Ads the item to the list bar. If bar does not exist, it is created as a list. If it exists and is not a list, an error will be thrown.

=item remove_from_list(item)

Removes the item from the list bar. If bar does not exist, it is created as a list. If it exists and is not a list, an error will be thrown.

=back

=head1 AUTHOR

Eric Wolf

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 Eric Wolf

This module is free software; it can be used under the same terms as perl
itself.

=cut
