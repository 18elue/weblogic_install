#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;

#open csv file
my $csv_file_name="test.csv";
open(my $csv_file_handler, "<", $csv_file_name) or die "cannot read < $csv_file_name : $!";

#read csv file
my @all_row;
while(my $line = <$csv_file_handler>){
	$/="\r\n";
	chomp $line;
	my @one_row = split ',' , $line;
	push @all_row, \@one_row;
}
close $csv_file_handler;

#change row from array to hash by using head column as the key
my $head_row = shift @all_row;
my @all_hash_row;
for my $row (@all_row) {
	my $hash_row = {};
	my $index = 0;
	for my $column (@$row) {
		my $key = $head_row->[$index];
		$index += 1;
		$hash_row->{$key} = $column;
	}
	push @all_hash_row, $hash_row;
}

#delete columns which does not have domain name
my @temp_row = @all_hash_row;
@all_hash_row = ();
for my $row (@temp_row) {
	push @all_hash_row, $row unless ($row->{"Domain name"} eq '');
}
my $weblogic_install_dir = create_one_input_file(\@all_hash_row);
exec "./create_weblogic_install_dir.bash", $weblogic_install_dir;

sub create_one_input_file {
	my ($row_aref) = @_;
	# TO DO : validate if all rows are in the same domain 
	
	# seperate admin server and managed server
	my $admin_server_row;
	my @managed_server_row;
	for my $row (@$row_aref) {
		if ($row->{"Instance Type"} eq "Admin") {
			$admin_server_row = $row;
		}
		elsif ($row->{"Instance Type"} eq "Manage") {
			push @managed_server_row, $row;
		}
	}

	# get all machines
	my @machine;
	for my $row(@$row_aref) {
		push @machine, $row->{"Zone Name"};
	}
	@machine = do { my %seen; grep { !$seen{$_}++ } @machine };

	# create input.properties file
	my $input_file_name = "input.properties";
	open (my $input_file_handler, ">", $input_file_name) or die "cannot create > $input_file_name : $!";

	printf $input_file_handler "WEBLOGIC_USER=weblogic\n";
	printf $input_file_handler "WEBLOGIC_PWD=%s\n", $admin_server_row->{"Weblogic Password"};
	printf $input_file_handler "DOMAIN_NAME=%s\n\n", $admin_server_row->{"Domain name"};

	printf $input_file_handler "BEAHOME=%s\n", '/usr/local/oracle/wls103602';
	printf $input_file_handler "DOMAIN_DIR=%s\n", '$BEAHOME/domains/';
	printf $input_file_handler "DOMAIN_TEMPLATE=%s\n", '$BEAHOME/wlserver_10.3/common/templates/domains/wls.jar';
	printf $input_file_handler "JAVA_HOME=%s\n\n", '$BEAHOME/jdk';

	printf $input_file_handler "ADMIN_SERVER_NAME=%s\n", $admin_server_row->{"Instance Name"};
	printf $input_file_handler "ADMIN_SERVER_PORT=%s\n", $admin_server_row->{"HTTP Port"};
	printf $input_file_handler "ADMIN_SERVER_ADDRESS=%s\n\n", $admin_server_row->{"IP Address"};

	printf $input_file_handler "MACHINE=%s\n\n", join(',', @machine);

	## print managed server info
	my @managed_server_key;
	for my $num (1..@managed_server_row) {
		push @managed_server_key, "MANAGED_SERVER_$num";
	}
	printf $input_file_handler "MANAGED_SERVER=%s\n", join(',', @managed_server_key);
	my $index=1;
	for my $managed_server (@managed_server_row) {
		printf $input_file_handler "MANAGED_SERVER_%d_NUM=%s\n", $index, $index;
		printf $input_file_handler "MANAGED_SERVER_%d_NAME=%s\n", $index, $managed_server->{"Instance Name"};
		printf $input_file_handler "MANAGED_SERVER_%d_PORT=%s\n", $index, $managed_server->{"HTTP Port"};
		printf $input_file_handler "MANAGED_SERVER_%d_ADDRESS=%s\n", $index, $managed_server->{"IP Address"};
		printf $input_file_handler "MANAGED_SERVER_%d_MACHINE=%s\n", $index, $managed_server->{"Zone Name"};
		printf $input_file_handler "MANAGED_SERVER_%d_CLUSTER=%s\n\n", $index, $managed_server->{"Cluster name"};
		$index += 1;
	}

	printf $input_file_handler "ALL_NODES=(%s %s)\n", $admin_server_row->{"Instance Name"}, join(' ', map {$_->{"Instance Name"}} @managed_server_row);
	printf $input_file_handler "MANAGED_SERVER_NAMES=(%s)\n", join(' ', map {$_->{"Instance Name"}} @managed_server_row);
	printf $input_file_handler "SERVUSER=%s\n", $admin_server_row->{"App OS Username"};
	printf $input_file_handler "T3_URL=t3://%s:%s\n", $admin_server_row->{"IP Address"}, $admin_server_row->{"HTTP Port"};
	$admin_server_row->{"Component"}=~s/ /_/g;
	close $input_file_handler;
	
	my $dir = sprintf "%s_domain_create",$admin_server_row->{"Component"};
	return $dir;
}
