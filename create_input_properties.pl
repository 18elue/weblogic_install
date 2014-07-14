#!/usr/bin/perl
use strict;
use warnings;
use Cwd;
use File::Path qw(make_path);
use Data::Dumper;

# variable share by all
my $beahome = '/usr/local/oracle/wls-latest';
my $domain_dir = $beahome.'/domains';
my $domain_template = $beahome.'/wlserver_10.3/common/templates/domains/wls.jar';
my $java_home = $beahome.'/jdk';

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
map { s/"//g } @$head_row; # delete colon if there is any

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
	push @all_hash_row, $row unless ($row->{"Domain name"} eq '' || $row->{"Instance Type"} eq '');
}

#set default value if no specific set, like log dir,Xms(G),Xmx(G),XX:MaxPermSize(G)
for my $row (@all_hash_row) {
	if (!$row->{"Log File"}) {
		$row->{"Log File"} = sprintf "/sites/%s/site/common/logs/103602_%s", $row->{"Domain name"}, $row->{"Instance Name"};
	}
	if (!$row->{"Xms(G)"}) {
		$row->{"Xms(G)"} = '1024';
	}
	if (!$row->{"Xmx(G)"}) {
		$row->{"Xmx(G)"} = '1024';
	}
	if (!$row->{"XX:MaxPermSize(G)"}) {
		$row->{"XX:MaxPermSize(G)"} = '512';
	}
}

#seperate all hash row into clusters,divided by component,then domain name.
my @component_aref = divide_by_key(\@all_hash_row, "Component");
my @cluster_aref;
for my $component (@component_aref) {
	push @cluster_aref, divide_by_key($component, "Domain name");
}
	

for my $cluster_aref (@cluster_aref) {
	my $weblogic_install_dir = create_one_input_file($cluster_aref);
	create_other_info_script($cluster_aref);
	create_secureCRT_config($cluster_aref);
#	create_scp_script($cluster_aref, $weblogic_install_dir);
	system "./create_weblogic_install_dir.bash", $weblogic_install_dir;
}

sub create_secureCRT_config {
	my ($row_aref) = @_;
	
	# get all rows with uniq host
	my @host_uniq_row = @$row_aref;
	
	@host_uniq_row = do { my %seen; grep { !$seen{$_->{"IP Address"}}++ } @host_uniq_row };
	
	my $config_dir = "/home/6375ly/VanDyke/Config/Sessions/WLS";
	my $template_filename = "/home/6375ly/weblogic_install_script/SecureCRT_TEMPLATE/connect.ini";
	
	# read in template file
	open (my $template_fh, "<", $template_filename) or die "cannot read file $template_filename : $!";
	my $template_file_content;
	while (<$template_fh>) {
		$template_file_content .= $_;
	}
	close $template_fh;

	# create config file for each host
	for my $row (@host_uniq_row) {
		my $file_dir = sprintf "$config_dir/%s/%s", $row->{"Application"}, $row->{"Env"};
		make_path($file_dir); # create file dir
		
		my $component = $row->{"Component"};
		$component =~ s/ /_/g;		
		my $file_name = sprintf "$file_dir/%s_%s.ini", $component, $row->{"IP Address"};
		
		open (my $config_fh, ">", $file_name) or die "cannot create file $file_name : $!";
		my $file_content = $template_file_content;
		$file_content =~ s/\${HOST_NAME}/$row->{"IP Address"}/g;
		$file_content =~ s/\${USER_NAME}/$row->{"App OS Username"}/g;		
		print $config_fh $file_content;
	}
}


# this func is used to create extra shell command like create log dir
sub create_other_info_script {
	my ($row_aref) = @_;

	# get all hosts
	my @host;
	for my $row(@$row_aref) {
		push @host, $row->{"IP Address"};
	}
	@host = do { my %seen; grep { !$seen{$_}++ } @host };
	
	my %ip_to_file_handler;
	for my $host (@host) {
		my $host_name = $host;
		$host_name =~ s/\./_/g;
		my $file_name = "other_info_".$host_name.".sh";
		open ($ip_to_file_handler{$host}, ">", $file_name) or die "cannot create > $file_name : $!";
	}
	
	# create log dir
	for my $row (@$row_aref) {
		my $host = $row->{"IP Address"};
		my $node_log_dir = sprintf "%s/%s/servers/%s/logs", $domain_dir, $row->{"Domain name"}, $row->{"Instance Name"};

		printf {$ip_to_file_handler{$host}} "#create log dir\n";
		printf {$ip_to_file_handler{$host}} "#node %s\n", $row->{"Instance Name"};
		printf {$ip_to_file_handler{$host}} "[[ -e %s ]] && rm -rf %s && echo \"%s dir deleted\"\n", $node_log_dir, $node_log_dir, $node_log_dir;
		printf {$ip_to_file_handler{$host}} "mkdir -p %s\n", $row->{"Log File"};
		printf {$ip_to_file_handler{$host}} "ln -s %s %s\n", $row->{"Log File"}, $node_log_dir;
		printf {$ip_to_file_handler{$host}} "echo soft link for %s created\n\n", $row->{"Instance Name"};
	}
	
	# copy start script
	for my $host (keys %ip_to_file_handler) {
		printf {$ip_to_file_handler{$host}} "#copy start script\n";
		printf {$ip_to_file_handler{$host}} "cp ../start_script/$host/* $domain_dir/%s/bin\n\n", $row_aref->[0]->{"Domain name"};
	}
	
	# close file handler
	map { close $_ } values %ip_to_file_handler; 
}

=x
sub create_scp_script {
	my ($row_aref, $weblogic_install_dir) = @_;
	my $file_name = "scp.sh";
	open (my $file_handler, ">", $file_name) or die "cannot create > $file_name : $!";
	
	printf $file_handler "echo copy domain create file to all servers\n\n";
	# get all hosts
	my @host;
	for my $row(@$row_aref) {
		push @host, $row->{"IP Address"};
	}
	@host = do { my %seen; grep { !$seen{$_}++ } @host };
	
	my $run_script_dir = getcwd();
	for my $host (@host) {
		printf $file_handler "scp -r %s %s@%s:%s\n", ;
	}
	
}
=cut

sub create_one_input_file {
	my ($row_aref) = @_;
	# TO DO : validate if all rows are in the same domain 
	
	# seperate admin server and managed server
	my $admin_server_row;
	my @managed_server_row;
	for my $row (@$row_aref) {
		if ($row->{"Instance Type"} =~ /Admin/i) {
			#check if there is only one admin server
			if ($admin_server_row) {
				warn "seems like there is more than one admin server, stop running";
				exit 1;
			}
			$admin_server_row = $row;
		}
		elsif ($row->{"Instance Type"} =~ /Mana/i) {
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

	printf $input_file_handler "BEAHOME=%s\n", $beahome;
	printf $input_file_handler "DOMAIN_DIR=%s\n", $domain_dir;
	printf $input_file_handler "DOMAIN_TEMPLATE=%s\n", $domain_template;
	printf $input_file_handler "JAVA_HOME=%s\n", $java_home;
	printf $input_file_handler "Xms=%s\n", $managed_server_row[0]->{"Xms(G)"};
	printf $input_file_handler "Xmx=%s\n", $managed_server_row[0]->{"Xmx(G)"};
	printf $input_file_handler "MaxPermSize=%s\n\n", $managed_server_row[0]->{"XX:MaxPermSize(G)"};
			
	printf $input_file_handler "ADMIN_SERVER_NAME=%s\n", $admin_server_row->{"Instance Name"};
	printf $input_file_handler "ADMIN_SERVER_PORT=%s\n", $admin_server_row->{"HTTP Port"};
	printf $input_file_handler "ADMIN_SERVER_ADDRESS=%s\n\n", $admin_server_row->{"IP Address"};
	printf $input_file_handler "ADMIN_LOG_DIR=%s\n\n", $admin_server_row->{"Log File"};

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
		printf $input_file_handler "MANAGED_SERVER_%d_HTTPS_PORT=%s\n", $index, $managed_server->{"HTTPS Port"};
		printf $input_file_handler "MANAGED_SERVER_%d_ADDRESS=%s\n", $index, $managed_server->{"IP Address"};
		printf $input_file_handler "MANAGED_SERVER_%d_MACHINE=%s\n", $index, $managed_server->{"Zone Name"};
		printf $input_file_handler "MANAGED_SERVER_%d_CLUSTER=%s\n", $index, $managed_server->{"Cluster name"};
		printf $input_file_handler "MANAGED_SERVER_%d_LOG_DIR=%s\n\n", $index, $managed_server->{"Log File"};
		$index += 1;
	}

	printf $input_file_handler "ALL_NODES=(%s %s)\n", $admin_server_row->{"Instance Name"}, join(' ', map {$_->{"Instance Name"}} @managed_server_row);
	printf $input_file_handler "MANAGED_SERVER_NAMES=(%s)\n", join(' ', map {$_->{"Instance Name"}} @managed_server_row);
	printf $input_file_handler "SERVUSER=%s\n", $admin_server_row->{"App OS Username"};
	printf $input_file_handler "T3_URL=t3://%s:%s\n", $admin_server_row->{"IP Address"}, $admin_server_row->{"HTTP Port"};
	$admin_server_row->{"Component"}=~s/ /_/g;
	close $input_file_handler;
	
	my $dir = sprintf "%s_domain_%s_create", $admin_server_row->{"Component"}, $admin_server_row->{"Domain name"};
	return $dir;
}

sub divide_by_key {
	my ($all_hash_row, $key) = @_;
	my @new_hash_row;
	my @component_row;
	my $category_value = $all_hash_row->[0]->{$key};
	for my $row (@$all_hash_row) {
		if ($row->{$key} eq $category_value) {
			push @component_row, $row;
		}
		else {
			my @temp_row = @component_row;
			push @new_hash_row, \@temp_row;
			@component_row = ();
			$category_value = $row->{$key};
			push @component_row, $row;
		}
	}
	push @new_hash_row, \@component_row; # add the last component
	return @new_hash_row;
}