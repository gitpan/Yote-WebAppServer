package Yote::ObjProvider;

use strict;

use feature ':5.10';

use Yote::Array;
use Yote::Hash;
use Yote::Obj;

use WeakRef;

use Exporter;
use base 'Exporter';

our @EXPORT_OK = qw(fetch stow a_child_of_b);

$Yote::ObjProvider::DIRTY = {};
$Yote::ObjProvider::WEAK_REFS = {};

our $DATASTORE;

use vars qw($VERSION);

$VERSION = '0.01';

# --------------------
#   PACKAGE METHODS
# --------------------

sub init {
    my $args = ref( $_[0] ) ? $_[0] : { @_ };
    my $ds = $args->{datastore};
    eval("use $ds");
    die $@ if $@;
    $DATASTORE = $ds->new( $args );
} #init

sub init_datastore {
    return $DATASTORE->init_datastore(@_);
} #init_datastore

sub connect {
    return $DATASTORE->connect();
}

sub disconnect {
    return $DATASTORE->disconnect();
}

sub xpath {
    my $path = shift;
    return xform_out( $DATASTORE->xpath( $path ) );
}

sub commit {
    $DATASTORE->commit();
}

sub xpath_count {
    my $path = shift;
    return $DATASTORE->xpath_count( $path );
}

sub fetch {
    my( $id ) = @_;

    #
    # Return the object if we have a reference to its dirty state.
    #
    my $ref = $Yote::ObjProvider::DIRTY->{$id} || $Yote::ObjProvider::WEAK_REFS->{$id};
    return $ref if $ref;

    my $obj_arry = $DATASTORE->fetch( $id );

    if( $obj_arry ) {
        my( $id, $class, $data ) = @$obj_arry;
        given( $class ) {
            when('ARRAY') {
                my( @arry );
                tie @arry, 'Yote::Array', $id, @$data;
                store_weak( $id, \@arry );
                return \@arry;
            }
            when('HASH') {
                my( %hash );
                tie %hash, 'Yote::Hash', $id, map { $_ => $data->{$_} } keys %$data;
                store_weak( $id, \%hash );
                return \%hash;
            }
            default {
                eval("require $class");
                my $obj = $class->new( $id );
                $obj->{DATA} = $data;
                $obj->{ID} = $id;
                store_weak( $id, $obj );
                return $obj;
            }
        }
    }
    return undef;
} #fetch

sub get_id {
    my $ref = shift;
    my $class = ref( $ref );
    given( $class ) {
        when('Yote::Array') {
            return $ref->[0];
        }
        when('ARRAY') {
            my $tied = tied @$ref;
            if( $tied ) {
		$tied->[0] ||= $DATASTORE->get_id( "ARRAY" );
                store_weak( $tied->[0], $ref );
		return $tied->[0];
            }
            my( @data ) = @$ref;
            my $id = $DATASTORE->get_id( $class );
            tie @$ref, 'Yote::Array', $id;
            push( @$ref, @data );
            dirty( $ref, $id );
            store_weak( $id, $ref );
            return $id;
        }
        when('Yote::Hash') {
            my $wref = $ref;
            return $ref->[0];
        }
        when('HASH') {
            my $tied = tied %$ref;

            if( $tied ) {
		$tied->[0] ||= $DATASTORE->get_id( "HASH" );
                store_weak( $tied->[0], $ref );
		return $tied->[0];
            }
            my $id = $DATASTORE->get_id( $class );
            my( %vals ) = %$ref;
            tie %$ref, 'Yote::Hash', $id;
            for my $key (keys %vals) {
                $ref->{$key} = $vals{$key};
            }
            dirty( $ref, $id );
            store_weak( $id, $ref );
            return $id;
        }
        default {
            $ref->{ID} ||= $DATASTORE->get_id( $class );
            store_weak( $ref->{ID}, $ref );
            return $ref->{ID};
        }
    }
} #get_id

sub a_child_of_b {
    my( $a, $b, $seen ) = @_;
    my $bref = ref( $b );
    return 0 unless $bref && ref($a);
    $seen ||= {};
    my $bid = get_id( $b );
    return 0 if $seen->{$bid};
    $seen->{$bid} = 1;
    return 1 if get_id($a) == get_id($b);
    given( $bref ) {
        when(/^(ARRAY|Yote::Array)$/) {
            for my $obj (@$b) {
                return 1 if( a_child_of_b( $a, $obj ) );
            }
        }
        when(/^(HASH|Yote::Hash)$/) {
            for my $obj (values %$b) {
                return 1 if( a_child_of_b( $a, $obj ) );
            }
        }
        default {
            for my $obj (values %{$b->{DATA}}) {
                return 1 if( a_child_of_b( $a, xform_out( $obj ) ) );
            }
        }
    }
    return 0;
} #a_child_of_b

sub stow_all {
    my( @objs ) = values %{$Yote::ObjProvider::DIRTY};
    for my $obj (@objs) {
        stow( $obj );
    }
} #stow_all

sub reset {
    stow_all();
    $Yote::ObjProvider::DIRTY = {};
    $Yote::ObjProvider::WEAK_REFS = {};
}

#
# Returns data structure representing object. References are integers. Values start with 'v'.
#
sub raw_data {
    my( $obj ) = @_;
    my $class = ref( $obj );
    return unless $class;
    my $id = get_id( $obj );
    die unless $id;
    given( $class ) {
        when('ARRAY') {
            my $tied = tied @$obj;
            if( $tied ) {
		return $tied->[1];
            } else {
                die;
            }
        }
        when('HASH') {
            my $tied = tied %$obj;
            if( $tied ) {
                return $tied->[1];
            } else {
                die;
            }
        }
        when('Yote::Array') {
	    return $obj->[1];
        }
        when('Yote::Hash') {
            return $obj->[1];
        }
        default {
            return $obj->{DATA};
        }
    }
} #raw_data

sub stow {

    my( $obj ) = @_;
    my $class = ref( $obj );
    return unless $class;
    my $id = get_id( $obj );
    die unless $id;
    my $data = raw_data( $obj );
    given( $class ) {
        when('ARRAY') {
            $DATASTORE->stow( $id,'ARRAY', $data );
            clean( $id );
        }
        when('HASH') {
            $DATASTORE->stow( $id,'HASH',$data );
            clean( $id );
        }
        when('Yote::Array') {
            if( is_dirty( $id ) ) {
                $DATASTORE->stow( $id,'ARRAY',$data );
                clean( $id );
            }
            for my $child (@$data) {
                if( $child > 0 && $Yote::ObjProvider::DIRTY->{$child} ) {
                    stow( $Yote::ObjProvider::DIRTY->{$child} );
                }
            }
        }
        when('Yote::Hash') {
            if( is_dirty( $id ) ) {
                $DATASTORE->stow( $id, 'HASH', $data );
            }
            clean( $id );
            for my $child (values %$data) {
                if( $child > 0 && $Yote::ObjProvider::DIRTY->{$child} ) {
                    stow( $Yote::ObjProvider::DIRTY->{$child} );
                }
            }
        }
        default {
            if( is_dirty( $id ) ) {
                $DATASTORE->stow( $id, $class, $data );
                clean( $id );
            }
            for my $val (values %$data) {
                if( $val > 0 && $Yote::ObjProvider::DIRTY->{$val} ) {
                    stow( $Yote::ObjProvider::DIRTY->{$val} );
                }
            }
        }
    } #given

} #stow

sub xform_out {
    my $val = shift;
    return undef unless defined( $val );
    if( index($val,'v') == 0 ) {
        return substr( $val, 1 );
    }
    return fetch( $val );
}

sub xform_in {
    my $val = shift;
    if( ref( $val ) ) {
        return get_id( $val );
    }
    return "v$val";
}

sub store_weak {
    my( $id, $ref ) = @_;
    die "SW" if ref($ref) eq 'Yote::Hash';
    my $weak = $ref;
    weaken( $weak );
    $Yote::ObjProvider::WEAK_REFS->{$id} = $weak;
}

sub dirty {
    my $obj = shift;
    my $id = shift;
    $Yote::ObjProvider::DIRTY->{$id} = $obj;
}

sub is_dirty {
    my $id = shift;
    return $Yote::ObjProvider::DIRTY->{$id};
}

sub clean {
    my $id = shift;
    delete $Yote::ObjProvider::DIRTY->{$id};
}

1;
__END__

=head1 NAME

Yote::ObjProvider - Serves Yote objects. Configured to a persistance engine.

=head1 DESCRIPTION

This module is the front end for assigning IDs to objects, fetching objects, keeping track of objects that need saving (are dirty) and saving all dirty objects.

The public methods of interest are 

=over 4

=item fetch

Returns an object given an id.

my $object = Yote::ObjProvider::fetch( $object_id );

=item xpath

Given a path designator, returns the object at the end of it, starting in the root. The notation is /foo/bar/baz where foo, bar and baz are field names. This works only for fields of Yote objects.

my $object = Yote::ObjProvider::xpath( "/foo/bar/baz" );

=item xpath_count

Given a path designator, returns the number of fields of the object at the end of it, starting in the root. The notation is /foo/bar/baz where foo, bar and baz are field names. This is useful for counting how many things are in a list.

my $count = Yote::ObjProvider::xpath_count( "/foo/bar/baz/myarray" );

=item a_child_of_b 

Takes two objects as arguments. Returns true if object a is branched off of object b.

if(  Yote::ObjProvider::xpath_count( $obj_a, $obj_b ) ) {


=item stow_all

Stows all objects that are marked as dirty. This is called automatically by the application server and need not be explicitly called.

Yote::ObjProvider::stow_all;

=back

=head1 AUTHOR

Eric Wolf

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 Eric Wolf

This module is free software; it can be used under the same terms as perl
itself.

=cut
