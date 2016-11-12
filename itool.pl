#!/usr/bin/perl
#
#
# itool.pl
#

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

$| = 1; # do not buffer stdout

use strict;
use oss_base;
use oss_utils;
use Data::Dumper;

use CGI;
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use subs qw(exit);
# Select the correct exit function
*exit = $ENV{MOD_PERL} ? \&Apache::exit : sub { CORE::exit };

my $cgi=new CGI;

my $user    = $cgi->param("USER");
my $pass    = $cgi->param("PASS");
my $action  = $cgi->param("ACTION");
my $connect = { aDN => 'anon' };

if( defined $user and defined $pass ){
	my $this = oss_base->new($connect);
	my $dn = $this->get_user_dn("$user");
	$this->destroy();
	$connect = { aDN => "$dn", aPW => "$pass"};
}
my $oss = oss_base->new($connect);

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?ACTION=getHW&IP=172.16.2.1" 
=cut
=item
if( $action eq 'getHW' )
{
	my $ip  = $cgi->param("IP");
	if( !defined $ip )
	{
	   $ip  = $cgi->remote_addr();
	}
	my $wsDN = $oss->get_host($ip);
	my $tmp  = get_name_of_dn($wsDN);
	if( $tmp =~ s/-wlan$// )
	{
	   $wsDN = $oss->get_host($tmp);
	}
	my $hw  = $oss->get_config_value($wsDN,'HW');

	print $cgi->header(-charset=>'utf-8');
	print $cgi->start_html(-title=>'itool');
	print "HW $hw\n";
	print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?ACTION=getPCN&IP=172.16.2.1" 
=cut
if( $action eq 'getPCN' )
{
        my $ip  = $cgi->param("IP");
	my $pc_name = "-";
        if( !defined $ip )
        {
           $ip  = $cgi->remote_addr();
        }
        my $wsDN = $oss->get_host($ip);
	my $tmp = get_name_of_dn($wsDN);
	$tmp =~ s/-wlan$//;
	if($tmp){
		$pc_name = $tmp;
	}

        print $cgi->header(-charset=>'utf-8');
        print $cgi->start_html(-title=>'itool');
        print "PCN $pc_name\n";
        print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?ACTION=getDOMAIN" 
=cut
if( $action eq 'getDOMAIN' )
{
	my $sambadomain = "-";
	my $mesg      = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
					      filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
					      scope   => 'one'
					);
	foreach my $entry ( $mesg->entries ){
		$sambadomain    = $entry->get_value('sambaDomainName');
	}

	print $cgi->header(-charset=>'utf-8');
	print $cgi->start_html(-title=>'itool');
	print "DOMAIN $sambadomain\n";
	print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?ACTION=getOSSNETBIOSNAME" 
=cut
if( $action eq 'getOSSNETBIOSNAME' )
{
	my $sambadomain = "-";
	my $ossnetbiosname = $oss->get_school_config("SCHOOL_NETBIOSNAME");

	print $cgi->header(-charset=>'utf-8');
	print $cgi->start_html(-title=>'itool');
	print "OSSNETBIOSNAME $ossnetbiosname\n";
	print $cgi->end_html();
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=edv-pc02&PASS=edv-pc02&ACTION=getPRINTER&IP=10.0.2.2" 
=cut

if( $action eq 'getPRINTER' )
{
        my $ip  = $cgi->param("IP");
        $ip  = $cgi->remote_addr() if( !defined $ip );
        notDefinedOss() if( !defined $oss );

        # get host name
        my $wsName = "-";
        my $wsDN = $oss->get_host($ip);
        my $tmp  = get_name_of_dn($wsDN);
        if( $tmp =~ s/-wlan$// )
        {
           $wsDN = $oss->get_host($tmp);
        }
        $wsName = $tmp if($tmp);

        my $room     = get_parent_dn($wsDN);
        my $dprint   = $oss->get_vendor_object($wsDN,'EXTIS','DEFAULT_PRINTER');
        $dprint      = $oss->get_vendor_object($room,'EXTIS','DEFAULT_PRINTER') if( !scalar(@$dprint) );
        my $prints   = $oss->get_vendor_object($wsDN,'EXTIS','AVAILABLE_PRINTER');
        $prints      = $oss->get_vendor_object($room,'EXTIS','AVAILABLE_PRINTER') if( !scalar(@$prints));

        print "Content-Type: text/xml\r\n";   # header tells client you send XML
        print "\r\n";                         # empty line is required between headers
        print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
        print "<printers>\n";
        if( $dprint->[0] )
        {
                print '  <defaultPrinter>'.$dprint->[0]."</defaultPrinter>\n";
        }
        print "   <printer>";
        print join(";",split(/\n/,$prints->[0] ));
        print " </printer>\n";
        print '</printers>';
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=edv-pc02&PASS=edv-pc02&ACTION=getINSTALLATIONS&IP=10.0.2.2" 
=cut

if( $action eq 'getINSTALLATIONS' )
{
	my $ip  = $cgi->param("IP");
	$ip  = $cgi->remote_addr() if( !defined $ip );
	notDefinedOss() if( !defined $oss );

	# get host name
	my $wsName = "-";
	my $wsDN = $oss->get_host($ip);
	my $tmp  = get_name_of_dn($wsDN);
	if( $tmp =~ s/-wlan$// )
	{
	   $wsDN = $oss->get_host($tmp);
	}
	$wsName = $tmp if($tmp);

	# get samba domain
	my $sambaDomain = "-";
	my $mesg = $oss->{LDAP}->search(base   => $oss->{LDAP_BASE},
					filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
					scope  => 'one'
					);
	foreach my $entry ( $mesg->entries ){
		$sambaDomain = $entry->get_value('sambaDomainName');
	}

	my $ossClientPkgDn = '';
	my $ossClientVersion = '4.7.0';
	my $mesg = $oss->{LDAP}->search(  base   => 'o=osssoftware,ou=Computers,'.$oss->{LDAP_BASE},
					  scope  => 'one',
					  filter => "configurationKey=OssClientInstallV*",
					);
	foreach my $entry ( sort $mesg->entries )
	{
		my $pkgDn = $entry->dn();
		$pkgDn =~ /^(configurationKey=OssClientInstallV)(.*),o=osssoftware(.*)/;
		if( $2 >= $ossClientVersion ){
			$ossClientVersion = $2;
			$ossClientPkgDn = $pkgDn;
		}
	}

	if( $ossClientPkgDn ){
		my $pkgName = $oss->get_attribute( $ossClientPkgDn, 'configurationKey');
		my $cmd = '/usr/sbin/oss_control_client.pl';
		$cmd .= ' --client="'.$wsName.'"';
		$cmd .= ' --cmd=ExecuteCommandCmd';
		$cmd .= ' --execfilename=cmd.exe';
		$cmd .= ' --execworkdir="C:\Windows\System32"';
		$cmd .= ' --execarg="/c';
		$cmd .= ' net use W: \\\\\install\\itool /user:'.$sambaDomain.'\\'.$wsName.' '.$wsName;
		$cmd .= ' &amp;&amp;';
		$cmd .= ' \\\\\install\\itool\\swrepository\\'.$pkgName.'\OssClientSetup.exe /VERYSILENT /LOG=C:\windows\OssClientSetup_inst.log /TASKS=allowprinterdriversinstall,enableschoolproxy';
		$cmd .= ' &amp;&amp;';
		$cmd .= ' net use W: /DELETE"';
#		create_job($cmd, "Start OssClientSetup installation on: $wsNames", 'now');
		cmd_pipe($cmd);
	}
	print "Content-Type: text/xml\r\n";   # header tells client you send XML
	print "\r\n";                         # empty line is required between headers
	print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print '<itool>'."\n";
	print ' <info ossClientPkgDn="'.$ossClientPkgDn.'" />'."\n";
	print '</itool>';
}

=item
======================================== NEW ================================================
=cut

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=info-pc00&PASS=info-pc00&ACTION=getSwRepoInfo&IP=10.0.2.0" 
=cut
if( $action eq 'getSwRepoInfo' )
{
	my $ip  = $cgi->param("IP");
	$ip  = $cgi->remote_addr() if( !defined $ip );
	notDefinedOss() if( !defined $oss );

	# get host name
	my $wsName = "-";
	my $wsDN = $oss->get_host($ip);
	my $tmp  = get_name_of_dn($wsDN);
	if( $tmp =~ s/-wlan$// )
	{
	   $wsDN = $oss->get_host($tmp);
	}
	$wsName = $tmp if($tmp);

	# get samba domain
	my $sambaDomain = "-";
	my $mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
					  filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
					  scope   => 'one'
					);
	foreach my $entry ( $mesg->entries ){
		$sambaDomain = $entry->get_value('sambaDomainName');
	}

	# get manual installed software
	my $manualinstalledsw = $oss->get_school_config('SCHOOL_CLIENTINSTALL_CHECK_MANUAL_INSTALLED_SOFTWARE', $oss->{LDAP_BASE}) || 'yes';

	# get package install status
	my %tmpHash;
	my $userDn = $oss->get_user_dn($wsName);
	my $wsUserDn = 'o=oss,'.$userDn;
	my $allPackage = $oss->search_vendor_object_for_vendor( 'osssoftware', "ou=Computers,$oss->{LDAP_BASE}");
	foreach my $pkgDn ( @$allPackage ){
		my $pkgName = $oss->get_attribute( $pkgDn, 'configurationKey');
		my $status = $oss->get_wsuser_pkg_status($userDn, $pkgName);

		if( $status =~ /^(deinstallation_scheduled|deinstallation_failed|installation_scheduled|installation_failed|deinstalled_manual|installed)$/ )
		{
			push @{$tmpHash{$status}}, $pkgDn;
		}else{
			push @{$tmpHash{other}}, $pkgDn;
                }
        }

	# sort package
        if( exists($tmpHash{deinstallation_scheduled}) or scalar($tmpHash{deinstallation_scheduled}) ){
                @{$tmpHash{deinstallation_scheduled}} = reverse(@{$oss->sortPkg($tmpHash{deinstallation_scheduled})});
        }

        if( exists($tmpHash{installation_scheduled}) or scalar($tmpHash{installation_scheduled}) ){
                $tmpHash{installation_scheduled} = $oss->sortPkg($tmpHash{installation_scheduled});
        }

	# get installed manual software
	my $obj = $oss->search_vendor_object_for_vendor( 'osssoftware', $wsUserDn );
        if( defined $obj){
                foreach my $k ( sort @$obj ){
                        if( $k =~ /^configurationKey=(.*),o=osssoftware,$wsUserDn$/ ){
                                my $tPkgN = $1;
                                my $status = $oss->get_wsuser_pkg_status($userDn,$tPkgN);
                                next if( $status ne 'installed_manual' );
				push @{$tmpHash{installed_manual}}, $tPkgN;
			}
		}
	}

	my %hash;
	my $i = 0;
	my @cmds = ( 'deinstallation_scheduled', 'deinstallation_failed', 'installation_scheduled', 'installation_failed', 'deinstalled_manual', 'installed', 'other', 'installed_manual');
	foreach my $cmd ( @cmds ){
		next if( !exists($tmpHash{$cmd}) or !scalar($tmpHash{$cmd}) );
		if( $cmd =~ /^installed_manual$/ ){
			foreach my $tPkgN ( sort @{$tmpHash{$cmd}} ){
				$i++;
				my $pkgDn = "configurationKey=$tPkgN,o=osssoftware,$wsUserDn";
				next if( ! $oss->exists_dn($pkgDn) );
				$hash{$i}->{id}     = $tPkgN;
				$hash{$i}->{status} = $oss->get_wsuser_pkg_status($userDn,$tPkgN);
				$hash{$i}->{pkgVersion} = '';
				$hash{$i}->{cmdinstall} = '';
				$hash{$i}->{cmdremove}  = '';
				$hash{$i}->{cmdreboot}  = '';
				$hash{$i}->{cmdexecute} = '';
				$hash{$i}->{swproductkey}  = $oss->get_config_value($pkgDn,'swProductKey');
				$hash{$i}->{swdisplayname} = '';
				$hash{$i}->{swfileexists}  = '';
				$hash{$i}->{swlicensetype} = '';
				$hash{$i}->{swlicensekey}  = '-';
			}
		}
		else
		{
			foreach my $pkgDn ( @{$tmpHash{$cmd}} ){ # no sort
				$i++;
				my $pkgName = $oss->get_attribute( $pkgDn, 'configurationKey');
				$hash{$i}->{id}     = $pkgName;
				$hash{$i}->{status} = $oss->get_wsuser_pkg_status($userDn, $pkgName);
				$hash{$i}->{pkgVersion} = $oss->get_config_value($pkgDn, 'pkgVersion');
				$hash{$i}->{cmdinstall} = $oss->get_config_value($pkgDn, 'cmdInstall');
				$hash{$i}->{cmdremove}  = $oss->get_config_value($pkgDn, 'cmdRemove');
				$hash{$i}->{cmdreboot}  = $oss->get_config_value($pkgDn, 'cmdReboot');
				$hash{$i}->{cmdexecute} = $oss->get_config_value($pkgDn, 'cmdExecute');
				$hash{$i}->{swproductkey}  = $oss->get_config_value($pkgDn, 'swProductKey');
				$hash{$i}->{swdisplayname} = $oss->get_config_value($pkgDn, 'swDisplayName');
				$hash{$i}->{swfileexists}  = $oss->get_config_value($pkgDn, 'swFileExists');
				$hash{$i}->{swlicensetype} = $oss->get_config_value($pkgDn, 'pkgLicenseAllocationType');
				$hash{$i}->{swlicensekey}  = '-';
				my $result = $oss->{LDAP}->search( base => 'o=productkeys,'.$pkgDn , filter => "cValue=USED=$wsName" );
				$hash{$i}->{swlicensekey} = $oss->get_config_value($result->entry(0)->dn(), 'PRODUCT_KEY') if( $result && $result->count());
			}
		}
	}

	# make xml 
	print "Content-Type: text/xml\r\n";   # header tells client you send XML
	print "\r\n";                         # empty line is required between headers
	print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print '<itool>'."\n";
	print ' <info auth="successfully" hostname="'.$wsName.'" domainname="'.$sambaDomain.'" manualinstalledsw="'.$manualinstalledsw.'" />'."\n";
	foreach my $item (sort {$a<=>$b} keys %hash){
		my $line = ' <package id="'.$hash{$item}->{id}.'">';
		$line .= '<pkgStatus>'.$hash{$item}->{status}.'</pkgStatus>';
		$line .= '<pkgVersion>'.$hash{$item}->{pkgVersion}.'</pkgVersion>';
		$line .= '<cmdInstall>'.$hash{$item}->{cmdinstall}.'</cmdInstall>';
		$line .= '<cmdRemove>'.$hash{$item}->{cmdremove}.'</cmdRemove>';
		$line .= '<cmdReboot>'.$hash{$item}->{cmdreboot}.'</cmdReboot>';
		$line .= '<cmdExecute>'.$hash{$item}->{cmdexecute}.'</cmdExecute>';
		$line .= '<swProductKey>'.$hash{$item}->{swproductkey}.'</swProductKey>';
		$line .= '<swDisplayName>'.$hash{$item}->{swdisplayname}.'</swDisplayName>';
		$line .= '<swFileExists>'.$hash{$item}->{swfileexists}.'</swFileExists>';
		$line .= '<swLicenseType>'.$hash{$item}->{swlicensetype}.'</swLicenseType>';
		$line .= '<swLicenseKey>'.$hash{$item}->{swlicensekey}.'</swLicenseKey>';
		$line .= '</package>'."\n";
		print $line;
	}
	print '</itool>';
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=info-pc00&PASS=info-pc00&ACTION=setPkgStatus&PKGNAME=XXXXV1.0&PKGSTATUS=installed&IP=10.0.2.0"
pkgStatus: installed; deinstalled; installation_failed; deinstallation_failed; installed_manual; deinstalled_manual
=cut
if( $action eq 'setPkgStatus' )
{
	my $ip = $cgi->param("IP");
        $ip    = $cgi->remote_addr() if( !defined $ip );
	notDefinedOss() if( !defined $oss );
	my $pkgName   = $cgi->param("PKGNAME");
	my $pkgStatus = $cgi->param("PKGSTATUS");

	# get host name
	my $wsName = "-";
	my $wsDN = $oss->get_host($ip);
	my $tmp  = get_name_of_dn($wsDN);
	if( $tmp =~ s/-wlan$// )
	{
	   $wsDN = $oss->get_host($tmp);
	}
	$wsName = $tmp if($tmp);
	my $userDn = $oss->get_user_dn($wsName);
	my $wsUserDn = 'o=oss,'.$userDn;

	# get samba domain
	my $sambaDomain = "-";
	my $mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
					  filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
					  scope   => 'one'
					);
	foreach my $entry ( $mesg->entries ){
		$sambaDomain = $entry->get_value('sambaDomainName');
	}

	# set status
	if( $pkgStatus =~ /^deinstalled$/ ){
		$oss->delete_vendor_object( "$wsUserDn", 'osssoftware', $pkgName );
	}elsif( $pkgStatus =~ /^installed$/ ){
		if($oss->check_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "*")){
			$oss->modify_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "pkgStatus=$pkgStatus");
		}else{
			$oss->create_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "pkgStatus=$pkgStatus");
		}
	}elsif( $pkgStatus =~ /^installed_manual|deinstalled_manual$/ ){
		if($oss->check_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "*")){
			$oss->modify_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "pkgStatus=$pkgStatus");
		}else{
			$oss->create_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "pkgStatus=$pkgStatus");
		}
	}elsif( $pkgStatus =~ /^installation_failed|deinstallation_failed$/ ){
		if($oss->check_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "*")){
			$oss->modify_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "pkgStatus=$pkgStatus");
		}else{
			$oss->create_vendor_object( "$wsUserDn", 'osssoftware', "$pkgName", "pkgStatus=$pkgStatus");
		}
	}

	# get current pkg install status
	my $currentStatus = '-';
	my $restStatus = $oss->get_wsuser_pkg_status($userDn, $pkgName);
	$currentStatus = $restStatus if( $restStatus );

	# make xml 
	print "Content-Type: text/xml\r\n";   # header tells client you send XML
	print "\r\n";                         # empty line is required between headers
	print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print '<itool>'."\n";
	print ' <info auth="successfully" hostname="'.$wsName.'" domainname="'.$sambaDomain.'" />'."\n";
	print ' <package ';
	print ' id="'.$pkgName.'"';
	print ' currentstatus="'.$currentStatus.'"';
	print ' sentstatus="'.$pkgStatus.'"';
	print ' ip="'.$ip.'"';
	print ' />'."\n";
        print '</itool>';
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=info-pc03&PASS=info-pc03&ACTION=setManualInstalledPkgStatus&NPKGNAME=XXXXV1.0&NPKGDESC=XXXXX&NPKGVER=1.0&NPKGMAN=www.ocss.ro&NPKGLIC=www.ocss.ro&NPKGPRODKEY=XXX&NPKGDISPLAY=XXXXXXtest&IP=10.0.2.0"

   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl
?USER=info-pc03
&PASS=info-pc03
&ACTION=setManualInstalledPkgStatus
&NPKGNAME=XXXXV1.0
&NPKGDESC=
&NPKGVER=
&NPKGMAN=
&NPKGLIC=
&NPKGPRODKEY=
&NPKGDISPLAY=
&IP=10.0.2.0"

pkgStatus: installed; deinstalled; installation_failed; deinstallation_failed; installed_manual; deinstalled_manual
=cut
if( $action eq 'setManualInstalledPkgStatus' )
{
	my $ip = $cgi->param("IP");
	$ip    = $cgi->remote_addr() if( !defined $ip );
	notDefinedOss() if( !defined $oss );

	my $pkgName    = $cgi->param("NPKGNAME");
	$pkgName       = string_to_ascii($pkgName);
	my $pkgDesc    = $cgi->param("NPKGDESC");
	my $pkgVersion = $cgi->param("NPKGVER");
	my $pkgManufac = $cgi->param("NPKGMAN");
	my $pkgLicense = $cgi->param("NPKGLIC");
	my $pkgProdKey = $cgi->param("NPKGPRODKEY");
	my $pkgDisplayName = $cgi->param("NPKGDISPLAY");
	my $pkgInstall     = $cgi->param("NPKGINSTALL");
	my $pkgUninstall   = $cgi->param("NPKGUNINSTALL");

#	& "&NPKGNAME=" & newPkgName _
#	& "&NPKGDESC=" & strDisplayName _
#	& "&NPKGVER="  & strDisplayVersion _
#	& "&NPKGMAN="  & strPublisher _
#	& "&NPKGLIC="  & strURLInfoAbout _
#	& "&NPKGPRODKEY="   & strProductKey _
#	& "&NPKGDISPLAY="   & strDisplayName _
#       & "&NPKGINSTALL="   & strInstallString _
#	& "&NPKGUNINSTALL=" & strUninstallString _

	# get host name
	my $wsName = "-";
	my $wsDN = $oss->get_host($ip);
	my $tmp  = get_name_of_dn($wsDN);
	if( $tmp =~ s/-wlan$// )
	{
	   $wsDN = $oss->get_host($tmp);
	}
	$wsName = $tmp if($tmp);

	# get samba domain
	my $sambaDomain = "-";
	my $mesg = $oss->{LDAP}->search( base   => $oss->{LDAP_BASE},
                                          filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
                                          scope   => 'one'
                                        );
	foreach my $entry ( $mesg->entries ){
		$sambaDomain = $entry->get_value('sambaDomainName');
	}

	# make ws uid software install status ldap base
	my $wsUidDn = $oss->get_user_dn($wsName); 
        my $vbase = 'o=oss,'.$wsUidDn;
        if( !$oss->exists_dn($vbase) )
        {
                my $result = $oss->{LDAP}->add( dn   => $vbase,
                                                 attr => [
                                                 objectclass => [ 'top', 'organization' ],
                                                 o           => 'oss'
                                                ]);
                if( $result->code )
                {
                        $oss->ldap_error($result);
                        print STDERR "Error by creating $vbase\n";
                        print STDERR $oss->{ERROR}->{code}."\n";
                        print STDERR $oss->{ERROR}->{text}."\n";
                }
        }

	my $addStatus = '';
	if( !$oss->check_vendor_object( $vbase, 'osssoftware', "$pkgName", "pkgName=$pkgName") )
	{
		my $logPath  = '\\\\install\itool\swrepository\logs\%COMPUTERNAME%';
		my $cmdInstall = 'wpkg.js /nonotify /quiet /install:'.$pkgName.' /log_file_path:'.$logPath.' /logfilePattern:'.$pkgName.'.log';
		my $cmdRemove  = 'wpkg.js /nonotify /quiet /remove:'.$pkgName.'  /log_file_path:'.$logPath.' /logfilePattern:'.$pkgName.'.log';
		my $dn = $oss->create_vendor_object( $vbase, 'osssoftware', "$pkgName", "pkgName=$pkgName");
		if( $oss->exists_dn($dn) )
		{
			$addStatus = 'successful';
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "pkgStatus=installed_manual");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "pkgDescription=$pkgDesc");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "pkgVersion=$pkgVersion");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "pkgManufacturer=$pkgManufac");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "pkgLicense=$pkgLicense");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "swProductKey=$pkgProdKey");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "swDisplayName=$pkgDisplayName");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "cmdInstall=$cmdInstall");
                        $oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "cmdRemove=$cmdRemove");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "cmdSwInstall=$pkgInstall");
			$oss->add_value_to_vendor_object( $vbase, 'osssoftware', "$pkgName", "cmdSwRemove=$pkgUninstall");
		}
		else
		{
			$addStatus = 'unsuccessful';
		}
	}
	else
	{
		$addStatus = 'exists';
	}

	# make xml 
	print "Content-Type: text/xml\r\n";   # header tells client you send XML
	print "\r\n";                         # empty line is required between headers
	print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print '<itool>'."\n";
	print ' <info auth="successfully" hostname="'.$wsName.'" domainname="'.$sambaDomain.'" />'."\n";
	print ' <package ';
	print ' id="'.$pkgName.'"';
	print ' ip="'.$ip.'"';
	print ' currentstatus="installed_manual"';
	print ' createstatus="'.$addStatus.'"';
	print ' />'."\n";
	print ' <pkgName>'.$pkgName.'</pkgName>'."\n";
	print ' <pkgDescription>'.$pkgDesc.'</pkgDescription>'."\n";
	print ' <pkgVersion>'.$pkgVersion.'</pkgVersion>'."\n";
	print ' <pkgManufacturer>'.$pkgManufac.'</pkgManufacturer>'."\n";
	print ' <pkgLicense>'.$pkgLicense.'</pkgLicense>'."\n";
	print ' <swProductKey>'.$pkgProdKey.'</swProductKey>'."\n";
	print ' <swDisplayName>'.$pkgDisplayName.'</swDisplayName>'."\n";
	print ' <swUninstallStr>'.$pkgUninstall.'</swUninstallStr>'."\n";
	print '</itool>';

}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=info-pc00&PASS=info-pc00&ACTION=setClientScriptStatus&STATUS=is_running&IP=10.0.2.0"
STATUS=is_running|is_not_running
PKGNAME=XXXV1.0
=cut
if( $action eq 'setClientScriptStatus' ){
	my $ip = $cgi->param("IP");
	$ip    = $cgi->remote_addr() if( !defined $ip );
	notDefinedOss() if( !defined $oss );
	my $status  = $cgi->param("STATUS");
	my $pkgName = $cgi->param("PKGNAME");

	# get host name
	my $wsName = "-";
	my $wsDN = $oss->get_host($ip);
	my $tmp  = get_name_of_dn($wsDN);
	if( $tmp =~ s/-wlan$// )
	{
	   $wsDN = $oss->get_host($tmp);
	}
	$wsName = $tmp if($tmp);
	my $userDn = $oss->get_user_dn($wsName);
	my $wsUserDn = 'o=oss,'.$userDn;

	# get samba domain
	my $sambaDomain = "-";
	my $mesg = $oss->{LDAP}->search(base   => $oss->{LDAP_BASE},
					filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
					scope   => 'one'
				);
	foreach my $entry ( $mesg->entries ){
		$sambaDomain = $entry->get_value('sambaDomainName');
	}

	if( $status =~ /^(is_running|is_not_running)$/){
		my $statusPkgUserDn = 'configurationKey='.$pkgName.',o=osssoftware,o=oss,'.$userDn;
		if( $status eq 'is_running'  ){
			if( !$oss->exists_dn($statusPkgUserDn) ){
				$oss->create_vendor_object( $wsUserDn, 'osssoftware', "$pkgName", "runStatus=running");
			}else{
				$oss->set_config_value( $statusPkgUserDn, 'runStatus', "running");
			}
		}elsif( $status eq 'is_not_running' ){
			if( $oss->exists_dn($statusPkgUserDn) ){
				if( $oss->check_config_value( $statusPkgUserDn, 'pkgStatus', '(.*)') ){
					$oss->delete_config_value( $statusPkgUserDn, 'runStatus', "running");
				}else{
					$oss->delete_vendor_object( $wsUserDn, 'osssoftware', $pkgName );
				}
			}
		}
	}elsif( $status =~ /^(client_running|client_not_running)$/ ){
		if( $status eq 'client_running' ){
			if( ! $oss->check_vendor_object( $wsUserDn, 'ossclientstatus', "ClientStatus", "*") ){
				$oss->create_vendor_object( $wsUserDn, 'ossclientstatus', 'ClientStatus', 'running');
			}
		}elsif( $status eq 'client_not_running' ){
			$oss->delete_vendor_object( $wsUserDn, 'ossclientstatus', 'ClientStatus' );
			my $mesg = $oss->{LDAP}->delete( 'o=ossclientstatus,'.$wsUserDn );
			
		}
	}



	# make xml 
	print "Content-Type: text/xml\r\n";   # header tells client you send XML
	print "\r\n";                         # empty line is required between headers
	print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print '<itool>'."\n";
	print ' <info auth="successfully" hostname="'.$wsName.'" domainname="'.$sambaDomain.'" />'."\n";
	print '</itool>';
}

=item
Ex: 
   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl?USER=admin&PASS=adminpass&ACTION=createPkg&NPKGNAME=XXXXV1.0&NPKGDESC=XXXXX&NPKGVER=1.0&WINTYPE=Win7-x86&IP=10.0.2.3"

   wget -O 1.txt --no-check-certificate "https://admin/cgi-bin/itool.pl
?USER=info-pc03
&PASS=info-pc03
&ACTION=setManualInstalledPkgStatus
&NPKGNAME=XXXXV1.0
&NPKGDESC=
&NPKGVER=
&WINTYPE=
&IP=10.0.2.3"
=cut

if( $action eq 'createPkg' )
{
	my $ip = $cgi->param("IP");
	$ip    = $cgi->remote_addr() if( !defined $ip );
	notDefinedOss() if( !defined $oss );
	my $pkgNameP    = $cgi->param("NPKGNAME");
	my $pkgDescP    = $cgi->param("NPKGDESC");
	my $pkgVersionP = $cgi->param("NPKGVER");
	my $winTypeP    = $cgi->param("WINTYPE");

	# get host name
	my $wsName = "-";
	my $wsDN = $oss->get_host($ip);
	my $tmp  = get_name_of_dn($wsDN);
	if( $tmp =~ s/-wlan$// )
	{
	   $wsDN = $oss->get_host($tmp);
	}
	$wsName = $tmp if($tmp);
	my $userDn = $oss->get_user_dn($wsName);
	my $wsUserDn = 'o=oss,'.$userDn;

	# get samba domain
	my $sambaDomain = "-";
	my $mesg = $oss->{LDAP}->search(base   => $oss->{LDAP_BASE},
					filter => "(&(objectClass=sambaDomain)(sambaDomainName=*))",
					scope   => 'one'
				);
	foreach my $entry ( $mesg->entries ){
		$sambaDomain = $entry->get_value('sambaDomainName');
	}

	my $logPath  = '\\\\install\itool\swrepository\logs\%COMPUTERNAME%';
	my $swBaseDn = "ou=Computers,$oss->{LDAP_BASE}";
	my $date     = `date +%Y-%m-%d`; chop $date;

	my $pkgName         = $pkgNameP;
	my $pkgDescription  = $pkgDescP;
	my $pkgVersion      = $pkgVersionP;
	my $pkgCategory     = 'WinDiffCreatorSoftware';
	my $pkgNotes        = '-';
	my $pkgPreviouspackages = '';
	my $swManufacturer  = $oss->get_school_config('SCHOOL_NAME', $oss->{LDAP_BASE});
	my $swCreatedDate   = $date;
	my $pkgCreatedDate  = $date;
	my $swLicense       = $oss->get_school_config('SCHOOL_DOMAIN', $oss->{LDAP_BASE});
	my $pkgLicenseAllocationType = 'NO_LICENSE_KEY';
	my $pkgCompatible   = $winTypeP;
	my $pkgRequirements = '';
	my $swproductkey    = '';
	my $swdisplayname   = '';
	my $swfileexists    = '';
	my $cmdInstall      = 'wpkg.js /nonotify /quiet /install:'.$pkgName.' /log_file_path:'.$logPath.' /logfilePattern:'.$pkgName.'.log';
	my $cmdRemove       = 'wpkg.js /nonotify /quiet /remove:'.$pkgName.'  /log_file_path:'.$logPath.' /logfilePattern:'.$pkgName.'.log';
	my $cmdInstallMSI   = '';
	my $cmdRemoveMSI    = '';
	my $cmdReboot       = 'false';
	my $cmdExecute      = 'once';
	my $pkgInstSrc      = '\\\\install\\itool\\swrepository\\'.$pkgName.'\\';
	my $pkgType         = 'WPKG';

	my $addStatus = 'successfully';
	my $isPkg = $oss->get_vendor_object( $swBaseDn, 'osssoftware', "$pkgName");
	if( $isPkg->[0] ){
		$addStatus = 'exist';
	}else{
		# create pkg in ldap
		my $dn = $oss->create_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgName=$pkgName");
		if( !$oss->exists_dn($dn) ){
			$addStatus = 'notexistldapentry';
		}else{
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgDescription=$pkgDescription");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgVersion=$pkgVersion");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgCategory=$pkgCategory");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgNotes=$pkgNotes");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgPreviouspackages=$pkgPreviouspackages");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "swManufacturer=$swManufacturer");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "swCreatedDate=$swCreatedDate");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgCreatedDate=$pkgCreatedDate");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "swLicense=$swLicense");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgLicenseAllocationType=$pkgLicenseAllocationType");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgCompatible=$pkgCompatible");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgRequirements=$pkgRequirements");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "swProductKey=$swproductkey");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "swDisplayName=$swdisplayname");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "swFileExists=$swfileexists");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "cmdInstall=$cmdInstall");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "cmdRemove=$cmdRemove");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "cmdSwInstall=$cmdInstallMSI");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "cmdSwRemove=$cmdRemoveMSI");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "cmdReboot=$cmdReboot");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "cmdExecute=$cmdExecute");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgInstSrc=$pkgInstSrc");
			$oss->add_value_to_vendor_object( $swBaseDn, 'osssoftware', "$pkgName", "pkgType=$pkgType");
		}
	}

	# make xml 
	print "Content-Type: text/xml\r\n";   # header tells client you send XML
	print "\r\n";                         # empty line is required between headers
	print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print '<itool>'."\n";
	print ' <info auth="successfully" hostname="'.$wsName.'" domainname="'.$sambaDomain.'" createstatus="'.$addStatus.'" />'."\n";
	print ' <pkgName>'.$pkgName.'</pkgName>'."\n";
	print ' <pkgDescription>'.$pkgDescription.'</pkgDescription>'."\n";
	print ' <pkgVersion>'.$pkgVersion.'</pkgVersion>'."\n";
	print ' <pkgCategory>'.$pkgCategory.'</pkgCategory>'."\n";
	print ' <pkgNotes>'.$pkgNotes.'</pkgNotes>'."\n";
	print ' <pkgPreviouspackages>'.$pkgPreviouspackages.'</pkgPreviouspackages>'."\n";
	print ' <swManufacturer>'.$swManufacturer.'</swManufacturer>'."\n";
	print ' <swCreatedDate>'.$swCreatedDate.'</swCreatedDate>'."\n";
	print ' <pkgCreatedDate>'.$pkgCreatedDate.'</pkgCreatedDate>'."\n";
	print ' <swLicense>'.$swLicense.'</swLicense>'."\n";
	print ' <pkgLicenseAllocationType>'.$pkgLicenseAllocationType.'</pkgLicenseAllocationType>'."\n";
	print ' <pkgCompatible>'.$pkgCompatible.'</pkgCompatible>'."\n";
	print ' <pkgRequirements>'.$pkgRequirements.'</pkgRequirements>'."\n";
	print ' <swProductKey>'.$swproductkey.'</swProductKey>'."\n";
	print ' <swDisplayName>'.$swdisplayname.'</swDisplayName>'."\n";
	print ' <swFileExists>'.$swfileexists.'</swFileExists>'."\n";
	print ' <cmdInstall>'.$cmdInstall.'</cmdInstall>'."\n";
	print ' <cmdRemove>'.$cmdRemove.'</cmdRemove>'."\n";
	print ' <cmdSwInstall>'.$cmdInstallMSI.'</cmdSwInstall>'."\n";
	print ' <cmdSwRemove>'.$cmdRemoveMSI.'</cmdSwRemove>'."\n";
	print ' <cmdReboot>'.$cmdReboot.'</cmdReboot>'."\n";
	print ' <cmdExecute>'.$cmdExecute.'</cmdExecute>'."\n";
	print ' <pkgInstSrc>'.$pkgInstSrc.'</pkgInstSrc>'."\n";
	print ' <pkgType>'.$pkgType.'</pkgType>'."\n";
	print '</itool>';
}


sub notDefinedOss
{
	# make xml 
	print "Content-Type: text/xml\r\n";   # header tells client you send XML
	print "\r\n";                         # empty line is required between headers
	print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
	print '<itool>'."\n";
	print ' <info auth="loginfailed" />'."\n";
	print '</itool>';
	exit;
}
