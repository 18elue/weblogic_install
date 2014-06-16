#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

my $VERSION = "0.1";

# file for create domain
my ($fh_crt, $fn_crt) = create_crt_file(); #fn=> filename, fh=>filehandler
my $property_href = read_property_file();
warn Dumper $property_href;

explanation_crt($fh_crt, $fn_crt);
import_file($fh_crt);
prepare($fh_crt, $property_href);
set_admin_server($fh_crt, $property_href);
create_machines($fh_crt, $property_href);
create_managed_server($fh_crt, $property_href);
create_cluster($fh_crt, $property_href);
post_set($fh_crt, $property_href);
boot_properties($fh_crt, $property_href);
close $fh_crt;

#file for config domain
my ($fh_cfg, $fn_cfg) = create_cfg_file();
explanation_cfg($fh_cfg, $fn_cfg);
config_domain($fh_cfg, $property_href);
config_admin_server($fh_cfg, $property_href);
config_managed_server($fh_cfg, $property_href);
post_config($fh_cfg, $property_href);
close $fh_cfg;


sub read_property_file {
	my $file_name = "input.properties";
	open(my $input_file, "<", $file_name ) or die "cannot open > $file_name: $!";
	my $prop = {};
	while(<$input_file>){
		chomp $_;	
		next if $_ eq '';
		my($key, $value) = split '=', $_;
		$prop->{$key} = $value;
 
	}

	# create structured data of managed server
	my $managed_server_aref = [];
	if ($prop->{MANAGED_SERVER}) {
		my @servers = split /,/, $prop->{MANAGED_SERVER};
		for my $server ( @servers ){
			my $node = {
				num  => delete $prop->{$server."_NUM"},
				name => delete $prop->{$server."_NAME"},
				port => delete $prop->{$server."_PORT"},
				address => delete $prop->{$server."_ADDRESS"},
				machine => delete $prop->{$server."_MACHINE"},
				cluster => delete $prop->{$server."_CLUSTER"},
			};
			push @$managed_server_aref, $node;
		}
		$prop->{MANAGED_SERVER_AREF} = $managed_server_aref;
	}
	else
	{
		print "ERROR: there is not managed server!\n";
		exit;
	}

	# create index for machines
	my $machine_href = {};
	my $i=1;
	for my $server (@$managed_server_aref) {
		my $machine = $server->{machine};
		if (!$machine_href->{$machine}) {
			$machine_href->{$machine} = $i;
			$i++;
		}
	}
	$prop->{MACHINE_HREF} = $machine_href;
	
	# create structured data of cluster
	my $cluster_href = {};
	$i=1;
	for my $server (@$managed_server_aref) {
		my $cluster = $server->{cluster};
		if (!$cluster_href->{$cluster}) {
			$cluster_href->{$cluster}->{num} = $i;
			$cluster_href->{$cluster}->{node} = [];
			$cluster_href->{$cluster}->{serverlist} = $server->{name};
			$cluster_href->{$cluster}->{address} = $server->{address}.":".$server->{port};
			$i++;
		}
		else {
			$cluster_href->{$cluster}->{serverlist} .= ','.$server->{name};
			$cluster_href->{$cluster}->{address} .= ','.$server->{address}.":".$server->{port};
		
		}
		push @{$cluster_href->{$cluster}->{node}}, $server->{num};
	}

	$prop->{CLUSTER_HREF} = $cluster_href;
	close $input_file;
	return $prop;	
}

sub create_crt_file {
	my $file_name = "create_domain.py";
	open(my $file_handler, ">", $file_name) or die "cannot open > $file_name: $!";
	return ($file_handler, $file_name);
}

sub create_cfg_file {
	my $file_name = "config_domain.py";
	open(my $file_handler, ">", $file_name) or die "cannot open > $file_name: $!";
	return ($file_handler, $file_name);
}

sub explanation_crt {
	my ($fh, $fn) = @_;
	my $string = <<"EXP";
#******************************************************************************
# File: $fn 
#
# Description:
# This WLST script generates a WebLogic Server 10.3 domain, this file is 
# created by the perl script create_py.pl. If you need to change this
# file, change of file create_py.pl is recommended.
#
# Author: yelu 
# Version:$VERSION
#******************************************************************************

EXP

	print $fh $string;
}

sub import_file {
	my ($fh) = @_;
	my $string = <<"IMPORT";
import os
import shutil
import java.io.File as File
import java.io.FileInputStream as FileInputStream
import java.util.Properties as Properties

IMPORT
	
	print $fh $string;	
}

sub prepare {
	my ($fh, $prop) = @_;
	my $domain_name = $prop->{DOMAIN_NAME};
	my $domain_template = $prop->{DOMAIN_TEMPLATE};
	my $usr = $prop->{WEBLOGIC_USER};
	my $pwd = $prop->{WEBLOGIC_PWD};
	my $string = <<"PREPARE";

# Copy file from source directory to destination directory.
# Creates destination directory if it doesn't exist.
def copyfile(src, dest):
  if os.path.isfile(src):
    destpath = os.path.split(dest)[0]

    if not os.path.exists(destpath):
      os.makedirs(destpath)

    # Copy file with data and stat information.
    shutil.copy2(src, dest)
  else:
    print 'Error: source file does not exist: ' + src


# Read in the WebLogic Server 10.3 domain template. ----------------------
domaintemplate =  '$domain_template'
print 'Reading in the WebLogic Server 10.3 domain template: ' + domaintemplate
readTemplate(domaintemplate)
print ''

# Set the domain name. ------------------------------------------------------
domainname = '$domain_name' 
print 'Setting the domain name: ' + domainname
cmo.name = domainname
print 'The domain name has been set.'
print ''

# Set the default admin username and password. ------------------------------
username = '$usr' 
password = '$pwd' 
print 'Setting the default admin username and password...'
cd('/Security/%s/User/weblogic' % domainname)
cmo.name = username
cd('../' + username)
cmo.setPassword(password)

PREPARE

	print $fh $string;
}

sub set_admin_server {
	my ($fh, $prop) = @_;
	my $name = $prop->{ADMIN_SERVER_NAME};
	my $port = $prop->{ADMIN_SERVER_PORT}; 
	my $address = $prop->{ADMIN_SERVER_ADDRESS}; 
	
	my $string = <<"ADMIN_SERVER";
# Set the admin server name. ------------------------------------------------
servername = '$name' 
print 'Setting the admin server name: ' + servername
cd('/Servers/AdminServer')
cmo.name = servername
cmo.listenPort = int('$port')
cmo.listenAddress = '$address'

cd('/')
cmo.adminServerName = servername
print ''

ADMIN_SERVER

	print $fh $string;
}

sub create_machines {
    my ($fh, $prop) = @_;
	print $fh "# Create machines. ----------------------------------------------------------\n";
	for my $mach (keys %{$prop->{MACHINE_HREF}}) {
		my $num = $prop->{MACHINE_HREF}->{$mach};
		my $string =<<"MACHINE";
mach_name_$num = '$mach'
print 'Creating machine: ' + mach_name_$num 
cd('/')
machine_$num = create(mach_name_$num, 'UnixMachine')

MACHINE
		print $fh $string;	
	}
	print $fh "print ''\n\n\n";
}

sub create_managed_server {
    my ($fh, $prop) = @_;
	print $fh "# Create managed servers. ---------------------------------------------------\n";	
    for my $server (@{$prop->{MANAGED_SERVER_AREF}}) {
		my $num = $server->{num};
		my $name = $server->{name};
		my $port = $server->{port};
		my $address = $server->{address};
		my $machine = $server->{machine};
		my $machine_num = $prop->{MACHINE_HREF}->{$machine};
		my $string =<<"MANAGED_SERVER";
ms_name_$num = '$name'
print 'Creating managed server: ' + ms_name_$num
cd('/')
ms$num = create(ms_name_$num, 'Server')
ms$num.listenPort = int('$port')
ms$num.listenAddress = '$address'

# Associate managed server $num with machine $machine_num.
if ms$num != None and machine_$machine_num != None:
	ms$num.machine = machine_$machine_num


MANAGED_SERVER
		print $fh $string;
	}
	print $fh "print ''\n\n\n";
}

sub create_cluster {
	my ($fh, $prop) = @_;
	print $fh "# Create a cluster. ---------------------------------------------------------\n";
	for my $cluster (keys %{$prop->{CLUSTER_HREF}}) {
		my $num = $prop->{CLUSTER_HREF}->{$cluster}->{num};
		my $serverlist = $prop->{CLUSTER_HREF}->{$cluster}->{serverlist};
		my $address = $prop->{CLUSTER_HREF}->{$cluster}->{address};
		my $string = <<"CLUSTER";
clustername_$num = '$cluster'
print 'Creating cluster: ' + clustername_$num
cd('/')
cluster$num = create(clustername_$num, 'Cluster')
cluster$num.clusterAddress = '$address'
cluster$num.multicastPort = int('7777')
cluster$num.multicastAddress = '239.192.0.1'
cluster$num.weblogicPluginEnabled = 1
print ''

# Assign the managed servers to the cluster. --------------------------------
serverlist_$num = '$serverlist'
print 'Assigning managed servers: (%s) to cluster: %s' % (serverlist_$num, clustername_$num)
assign('Server', serverlist_$num, 'Cluster', clustername_$num)
print ''
  
 
CLUSTER
		print $fh $string;	
	}
	print $fh "print ''\n\n\n";
}

sub post_set {
	my ($fh, $prop) = @_;
	my $domain_name = $prop->{DOMAIN_NAME};
	my $java_home = $prop->{JAVA_HOME};
	my $domain_home = $prop->{DOMAIN_DIR}.'/'.$domain_name;
	my $string = <<"POSTSET";
# Set domain creation options. ----------------------------------------------
startmode = 'prod'
print 'Setting domain creation options...'
setOption('CreateStartMenu', 'false')
setOption('DomainName', '$domain_name')
setOption('JavaHome', '$java_home')
setOption('OverwriteDomain', 'true')
setOption('ServerStartMode', startmode)

# Write new domain and close domain template. -------------------------------
domainhome = '$domain_home'
print 'Writing new domain to disk: ' + domainhome
writeDomain(domainhome)
closeTemplate()
print ''

POSTSET
	print $fh $string;
}

sub boot_properties {
	my ($fh, $prop) = @_;
	my $domain_home = $prop->{DOMAIN_DIR}.'/'.$prop->{DOMAIN_NAME};
	my $admin_server_name = $prop->{ADMIN_SERVER_NAME};
	my $string = <<"BOOT";
# If server start mode is set to 'prod', create boot.properties file. -------
if startmode == 'prod':
  try:
    print 'Server start mode set for production: creating boot.properties file...'
    srcfile = '%s/servers/%s/security/boot.properties' % (domainhome, servername)
    srcpath = os.path.split(srcfile)[0]

    if not os.path.exists(srcpath):
      os.makedirs(srcpath)

    bootfile = open(srcfile, 'w')
    bootfile.write('username=%s\\n' % username)
    bootfile.write('password=%s\\n' % password)
    bootfile.close()

  except:
    raise 'Error creating boot.properties file.'

  print ''

  # Create 'boot.properties' files for the managed servers. -------------------
  print 'Creating boot.properties files for the managed servers...'

BOOT
	print $fh $string;
	
	for my $server (@{$prop->{MANAGED_SERVER_AREF}}) {
		my $name = $server->{name};
		my $copy_file_string = <<"COPY";
  destfile = '$domain_home/servers/$name/security/boot.properties'
  print 'Copying: boot.properties --> ' + destfile
  copyfile(srcfile, destfile)
  print ''

COPY
		print $fh $copy_file_string;	
	}
}


sub explanation_cfg {
	my ($fh, $fn) = @_;
	my $string = <<"EXP";
#******************************************************************************
# File: $fn 
#
# Description:
# This WLST script connect to the weblogic admin server and do some 
# configuration. This file is created by the perl script create_py.pl. If you
# need to change this file, change of file create_py.pl is recommended.
#
# Author: yelu 
# Version:$VERSION
#******************************************************************************

EXP
	print $fh $string;
}

sub config_domain {
	my ($fh, $prop) = @_;
	my $domain_name = $prop->{DOMAIN_NAME};
	my $admin_server_address = $prop->{ADMIN_SERVER_ADDRESS};
	my $admin_server_port = $prop->{ADMIN_SERVER_PORT};
	my $usr = $prop->{WEBLOGIC_USER};
	my $pwd = $prop->{WEBLOGIC_PWD};
	my $connect_str = <<"CONNECT";
connect('$usr','$pwd','t3://$admin_server_address:$admin_server_port')
print ''
edit()
startEdit()
CONNECT
	print $fh $connect_str;

	for my $cluster (keys %{$prop->{CLUSTER_HREF}}) {
		my $cluster_str = <<"CLUSTER";

print 'cding to /Clusters/$cluster'
cd('/Clusters/$cluster')
print ''
print 'setting Cluster communication to UNICAST'
set('ClusterMessagingMode','unicast')
print ''

CLUSTER
		print $fh $cluster_str;
}

	my $other_str = <<"OTHER";
cd('/')
print 'setting Configuration Audit Type to log'
set('ConfigurationAuditType','log')
print ''
print 'setting LockoutThreshold to 6'
cd('/SecurityConfiguration/$domain_name/Realms/myrealm/UserLockoutManager/UserLockoutManager')
set('LockoutThreshold','6')
print ''
print 'setting LockoutResetDuration to 30'
set('LockoutResetDuration','30')
print ''
cd('/Log/$domain_name')
print 'setting domain log file rotation type to none'
set('RotationType','None')
print ''
cd('/EmbeddedLDAP/$domain_name')
print 'setting EmbeddedLDAP Credential '
set('Credential','$pwd')


OTHER
	print $fh $other_str;
	
}


sub config_admin_server {
	my($fh, $prop) = @_;
	my $server = $prop->{ADMIN_SERVER_NAME};
	my $string = <<"ADMIN";

print ''
cd('/Servers/$server/Log/$server')
set('RotationType','byTime')
set('NumberOfFilesLimited','true')
set('RotateLogOnStartup','false')
set('RotationTime','00:00')
set('FileTimeSpan','24')
set('FileCount','60')
set('FileName','logs/$server.log')
print ''
cd('../../WebServer/$server/WebServerLog/$server')
set('LoggingEnabled','true')
set('RotationType','byTime')
set('RotateLogOnStartup','false')
set('RotationTime','00:00')
set('FileTimeSpan','24')
set('FileCount','60')
set('NumberOfFilesLimited','true')
set('FileName','logs/access.log')


ADMIN
	print $fh $string;
}


sub config_managed_server {
	my ($fh, $prop) = @_;
	my $managed_server_aref = $prop->{MANAGED_SERVER_AREF};
	for my $server (@$managed_server_aref) {
		my $name = $server->{name};
		my $address = $server->{address};
		my $string = <<"MANAGED";

print 'setting $name instance parameters'
cd('/Servers/$name')
print 'setting $name InterfaceAddress'
set('InterfaceAddress','$address')
print ''
print 'setting $name MSIFileReplicationEnabled to true'
set('MSIFileReplicationEnabled','true')
print ''
print 'setting $name WeblogicPluginEnabled to true'
set('WeblogicPluginEnabled','true')
print ''
cd('/Servers/$name/Log/$name')
set('RotationType','byTime')
set('NumberOfFilesLimited','true')
set('RotateLogOnStartup','false')
set('RotationTime','00:00')
set('FileTimeSpan','24')
set('FileCount','60')
set('FileName','logs/$name.log')
print ''
print 'setting $name Web Server Log file location/name'
cd('../../WebServer/$name/WebServerLog/$name')
print ''
set('LoggingEnabled','true')
set('RotationType','byTime')
set('RotateLogOnStartup','false')
set('RotationTime','00:00')
set('FileTimeSpan','24')
set('FileCount','60')
set('NumberOfFilesLimited','true')
set('FileName','logs/access.log')

MANAGED
	print $fh $string;
	}
}

sub post_config {
	my ($fh, $prop) = @_;
	my $string = <<"POST";

print ''
cd('/')
print 'Seeing if Password Validation Provider already exists'
realm = cmo.getSecurityConfiguration().getDefaultRealm()
pwdvalidator = realm.lookupPasswordValidator('systemPasswordValidator')
if pwdvalidator:
        print 'Password Validator provider is already created'
else:
        print 'Creating SystemPasswordValidator '
        syspwdValidator = realm.createPasswordValidator('systemPasswordValidator','com.bea.security.providers.authentication.passwordvalidator.SystemPasswordValidator') 
        print "---  Creation of system Password Validator succeeded!"
print 'Configure SystemPasswordValidator'
realm = cmo.getSecurityConfiguration().getDefaultRealm()
pwdvalidator = realm.lookupPasswordValidator('systemPasswordValidator')
pwdvalidator.setMinPasswordLength(8)
pwdvalidator.setMaxConsecutiveCharacters(3)
pwdvalidator.setMaxInstancesOfAnyCharacter(4)
pwdvalidator.setMinAlphabeticCharacters(1)
pwdvalidator.setMinNumericCharacters(1)
pwdvalidator.setMinLowercaseCharacters(1)
pwdvalidator.setMinUppercaseCharacters(1)
pwdvalidator.setMinNonAlphanumericCharacters(1)
pwdvalidator.setRejectEqualOrContainUsername(true)
pwdvalidator.setRejectEqualOrContainReverseUsername(true)
print " --- Configuration of SystemPasswordValidator complete  ---"
save()
activate()
print ''
print 'Finished.'
exit()

POST
	print $fh $string;
}























