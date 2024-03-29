use strict;
use Module::Build;
use File::Copy;
use File::Path;
use File::chmod qw( symchmod lschmod );

my $builder = Module::Build->current;

my $base = $builder->args( 'install_base' ) || '/usr/local/yote';

copy( "data/SQLite.yote.db", $base ) or die "Unable to copy : $!";

my $file = shift @ARGV;
open my $fh, '>', $file or die "Unable to create file : $!";

print $fh <<END;
#!/usr/bin/env perl

#
# start_server.pl - start,stop,restart
#


use strict;
use feature 'say';

use Carp;
use Config::Simple;
use FindBin qw/\$Bin/;

use Yote::WebAppServer;
use Yote::SQLiteIO;

use lib "\$Bin/../lib";


\$SIG{ __DIE__ } = sub { Carp::confess( \@_ ) };

my \$pidfile = "$base/yote.pid";

my \$s = new Yote::WebAppServer;

\$SIG{TERM} = sub { 
    \$s->shutdown();
    print STDERR "Shutting down due to term\n";
    unlink( \$pidfile );
    exit;
};



#
# The order of the config is \@ARGV, \%ENV, ~/.yoterc || ~/.yote/yote.conf || /etc/yote.conf, 
#
my \$sqlitefile = "$base/SQLite.yote.db";
unless( -e \$sqlitefile ) {
    my \$sqlite = new Yote::SQLiteIO( sqlitefile => \$sqlitefile );
    \$sqlite->init_datastore();
}
my( \%config ) = ( port       => 8008, 
		  datastore  => 'Yote::SQLiteIO', 
		  sqlitefile => \$sqlitefile );

while( \@ARGV ) {
    my \$first = shift \@ARGV;
    if(\$first eq '--shutdown') {
	`cat \$pidfile | grep yote_server | xargs kill` if -e \$pidfile;
	unlink( \$pidfile );
	exit;
    }
    elsif( \$first eq '--restart' ) {
	#
	# kill any old servers hanging around
	#
	if( -e \$pidfile ) {
	    my \$res = `cat \$pidfile | grep yote_server | xargs kill`;
	    unlink( \$pidfile );
	    sleep(2);
	}
	last;
    }
    elsif( \$first =~ /^--([^=]+)=(.*)/ ) {
	\$config{\$1} = \$2;
    }
    elsif( \$first =~ /^-([^-].*)/ ) {
	\$config{\$1} = shift \@ARGV;
    }
    else {
	say "yote_server <options>\n".join( "\n\t*", ('--shutdown : stops yote server', '--restart : restarts yote server',
						      '--port=<port> : assigns the yote server to run on specified port',
						      '--datastore=<datastore package name> : use data store other than sqlite',
						      '--sqlitefile=<filename> : specify different sqlite file' ) );
	exit 0;
    }
} #while args

#
# Check to make sure no processes are still hanging around.
#
if( -e \$pidfile ) {
    open( IN, "<\$pidfile" );
    my \$pid = <IN>; 
    chomp( \$pid );

    my( \@haspid ) = `ps -p \$pid`;
    my \$haspid = grep { \$_ =~ /\b\$pid\b/ } \@haspid;
    if( \$haspid ) {
	print STDERR "Process \$pid still alive. Unable to start yote server\n";
	exit 1;
    }
}

#
# Normal start
#
`echo \$\$ > \$pidfile`;

\$s->start_server( \%config );

END

#
# now get cgi-bin and js files.
#
my $cgi = $builder->notes( 'cgi_dir' );
mkpath( "$cgi/yote" );
copy( "cgi/yote.cgi", "$cgi/yote/" ) or die "Unable to copy file $!";
chmod( "+x", "$cgi/yote/" );


my $cgipath = $builder->notes( 'cgi_path' );

open my $fin, "<", "javascript/yote.js" or die "Unable to open javascript file $!";
my $js = $builder->notes( 'js_dir' );
mkpath( "$js/yote" );
open my $fout, '>', "$js/yote/yote.js" or die "Unable to create file : $!";

while( !eof($fin) ) {
    my $line = <$fin>;
   $line =~ s!/cgi-bin/yote.cgi!$cgipath/yote/yote.cgi!g;
   print $fout $line;
}
close( $fin );
close( $fout );


__END__

