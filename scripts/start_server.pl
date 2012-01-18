#!env perl

use strict;

use Yote::WebAppServer;

my $s= new Yote::WebAppServer;
$s->start_server( datastore  => 'Yote::SQLiteIO',
		  sqlitefile => "MyYote",
		  port       => 8008 );
__END__

This script will start the server running on the given port with the SQLiteIO
engine to the file 'MyYote'.

Please update these parameters as needed.
