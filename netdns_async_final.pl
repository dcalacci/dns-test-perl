#!/usr/bin/perl
# netdns_async.pl
# Queries an arbitrary amount of DNS servers with a given hostname 
# in parallel, and returns useful information about the results.
# USAGE: netdns_asyc.pl hostname DNS1 DNS2 DNS3...
use Net::DNS::Async;
use Data::Dumper;
use Net::DNS::Packet;
$num = @ARGV;

# checks to see if the script is being called with the correct number of args
if ( $num < 2 ) {
	print "Please supply 2 or more arguments.\n";
	print "USAGE: netdns_asyc.pl hostname DNS1 DNS2 DNS3...\n";
	print "Queries an arbitrary number of DNS servers with a given hostname, resolving the queries in parallel\n";
	exit;
}
#------------------------------------------------------------------------------
my $hostname = shift(@ARGV);
my @servers = @ARGV;
my $packet = new Net::DNS::Packet($hostname);

print "Looking up $hostname at servers ", join( ', ', @servers), "\n\n";
my $c = new Net::DNS::Async(QueueSize => 20, Retries => 2, Timeout => 2);
# adds queries to $c for each element in @server
# after looking at the source for add, it seems that if you provide
# the arguments in a hash, you can specify specific nameservers
foreach (@servers) {
	$c->add(
		{
        	Nameservers => [ $_ ],
        	Callback   => \&store,
			Query      => [ $packet ],
    	}
	);
}
# Flush the queue, and perform all lookups
$c->await();


my %results;
sub store {
    my $pack = shift;
	# if the server returned no data
	# NOTE: try to specify which server returned no data
    unless ( defined $pack ) {
        #print "not defined\n";
		#------can't do this: pack is not defined------
        #warn $pack->answerfrom, " did not return any data for host $hostname!\n";
		#$answers{$pack->answerfrom} = "";
        return;
    }
	# Get the answers from the packet, store all in an @answers
	my @answers;
    foreach my $res ( $pack->answer ) {
        next unless $res->type eq "A";
		push ( @answers, $res->address);
    }
	# sort @answers for this server, separate by commas, and put in 
	# the results hash entry with the server as the key.
	$results{$pack->answerfrom} = join( ', ', sort @answers );
}
# this handles servers that return no data
foreach my $serv ( @servers ) {
	if ($results{$serv} eq "") {
		print "$serv not returning any data for $hostname.\n";
		$results{$serv} = " ";
	} else {
		next;
	}
}
# if all results are the same, %res2 should have only one key.
my %res2 = reverse %results;
if (scalar keys  %res2 > 1) {
	print "There is a discrepancy in the results:\n";
	# use Data::dumper to show contents of the results
	# use ->Dump to show the name of the has instead of just $VAR1
	print Data::Dumper->Dump( [ \%results ], ['results'] ), "\n";
} else { #if the results are different
	print "All DNS queries are returning the same result for host $hostname:\n";
    print $results{$servers[0]}, "\n"; #show the user the addresses returned
}