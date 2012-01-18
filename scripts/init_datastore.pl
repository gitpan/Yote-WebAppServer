#!env perl

use strict;

use Yote::MysqlIO;

print "Name of mysql database to set Yote webappserver in :";
my $dbname = <STDIN>;
chomp( $dbname );

if( $dbname ) {
    my $engine = new Yote::MysqlIO;
    print "Username to use (if any) : ";
    my $uname = <STDIN>;
    chomp( $uname );
    print "Password to use (if any) : ";
    my $pword = <STDIN>;
    chomp( $pword );

    $engine->init_datastore( db    => $dbname,
			     uname => $uname,
			     pword => $pword,
	);
    print "Set up database for yote engine.\n";
}

print "Goodbye\n";

__END__

This program sets up the tables for yote's mysql io engine.
