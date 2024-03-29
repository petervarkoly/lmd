# OSS LMD GuestAcount module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package GuestAccount;

use strict;
use oss_base;
use oss_group;
use oss_user;
use oss_utils;
use Net::LDAP;
use oss_LDAPAttributes;
use Data::Dumper;
use Date::Parse;
use POSIX 'strftime';

use vars qw(@ISA);
@ISA = qw(oss_group);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    $connect->{withIMAP} = 1;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}

sub interface
{
        return [
                "getCapabilities",
                "default",
		"addNewGuestGroup",
		"apply",
		"delete"
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Guest Acount' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers,sysadmins' },
                { allowedRole  => 'teachers' },
                { category     => 'User' },
                { order        => 60 },
                { variable     => [ "generalpassword",     [ type => "string" ] ] },
		{ variable     => [ "accountsnumber",      [ type => "string" ] ] },
		{ variable     => [ 'roomlist',            [ type => 'list', size =>'5', multiple => 'true' ] ]},
		{ variable     => [ "expirationdategroup", [ type => "date", label => 'ExpirationDateGroup'] ] },
		{ variable     => [ "grouptype",           [ type => "hidden"] ] },
		{ variable     => [ "fquota",              [ type => "string", label => "fquota", backlabel => "MB" ] ] },
		{ variable     => [ "privategroup",        [ type => "boolean" ] ] },
		{ variable     => [ "webdav_access",       [ type => "boolean" ] ] },
		{ variable     => [ "delete",              [ type => "action" ] ] },
        ];
}

sub default
{
	my $this = shift;
	my $reply = shift;
	my @r =();
	my @lines =('guestgroups');
	my $language =  main::GetSessionValue('lang');

	if( exists($reply->{warning}) ){
		push @r, { NOTICE => $reply->{warning} };
	}

	my $mydn = main::GetSessionValue('dn');
	my $dn = $this->get_current_guestgroups($mydn);

	for(my $i = 0; $i < scalar(@$dn); $i++ ){
                my $group = $this->get_group(@$dn[$i]);
		my $accountnmb = $group->{member};
		my $accountsnumber = scalar(@$accountnmb);
		
		my $privategroup;
		if($group->{writerdn}->[0]){
			$privategroup = main::__('Yes');
		}else{
			$privategroup = main::__('No');}
		
		my $expirationdategroup = $this->get_vendor_object( @$dn[$i], 'EXTIS','ExpirationDateGroup');
		$expirationdategroup->[0] = date_format_convert("$language","$expirationdategroup->[0]");

		my $webdav_access = $this->get_vendor_object( @$dn[$i], 'EXTIS','WebDavAccess');
		if($webdav_access->[0]){
			$webdav_access = main::__("Yes");
		}else{
			$webdav_access = main::__("No");
		}
		my $roomlist = $this->get_vendor_object( @$dn[$i], 'EXTIS','RoomList');

		my $users = main::__('Users: ');
		my $u = $this->get_users_of_group( @$dn[$i], 1);
		foreach my $k ( sort keys %{$u}){
			$users .= $u->{$k}->{uid}->[0].", " if($k !~ /^cn=(.*)/);
		}

		my @line = ( @$dn[$i] );
		next if ( -e "/usr/share/oss/setup/deleting-guest-".$group->{cn}->[0] );
		push @line, { name => 'name', value => $group->{cn}->[0], "attributes" => [ type => "label" ] };
		push @line, { name => 'description', value => $group->{description}->[0], "attributes" => [ type => "label" ] };
		push @line, { name => 'privategroup', value => $privategroup, "attributes" => [ type => "label" ] };
		push @line, { name => 'webdav_access', value => $webdav_access, "attributes" => [ type => "label" ] };
		push @line, { name => 'accountsnumber', value => $accountsnumber-1, "attributes" => [ type => "label", help => $users ] };
		push @line, { name => 'ExpirationDateGroup', value => $expirationdategroup->[0], "attributes" => [ type => "label" ] };
		push @line, { name => 'RoomList', value => main::__("$roomlist->[0]"), "attributes" => [ type => "label" ] };
		push @line, { delete => main::__('delete')};
		push @lines, { line => \@line};

        }

	push @r, { table => \@lines};
	push @r, { action => 'addNewGuestGroup' } ;
	return \@r;
}

sub addNewGuestGroup
{
	my $this  = shift;
	my $reply = shift;
	my @rooms = $this->get_rooms;
	my @newgroup = ();
	if( exists($reply->{warning}) ){
		push @newgroup, { ERROR => $reply->{warning} };
	}

	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
        my $Date = sprintf('%4d-%02d-%02d',$year+1900,$mon+1,$mday);
	my @time = strptime($Date);
	$time[3] = $time[3]+6;
	my $expirationdate = POSIX::strftime("%Y-%m-%d", @time);
	push @rooms, '---DEFAULTS---';
	push @rooms, 'all';

	push @newgroup, { cn => $reply->{cn} };
	push @newgroup, { description => $reply->{description} };
        push @newgroup, { generalpassword => $reply->{generalpassword} };
        push @newgroup, { accountsnumber => $reply->{accountsnumber} } ;
	push @newgroup, { fquota => $this->get_school_config('SCHOOL_FILE_QUOTA') };
	push @newgroup, { expirationdategroup => $expirationdate};
	push @newgroup, { roomlist => [ 'all', @rooms ] } ;
	push @newgroup, { grouptype => 'guest'};
	push @newgroup, { privategroup => $reply->{privategroup} };
	push @newgroup, { webdav_access => 0 } ;
	push @newgroup, { action => 'cancel' } ;
        push @newgroup, { action => 'apply' } ;

	return \@newgroup;
}

sub apply
{
	my $this  = shift;
	my $reply = shift;
	my @roomlist = ();
	my @pcs;	
	my $pclist;

	if(!$reply->{cn}){
		$reply->{warning} .= main::__('Assign group name!')."<BR>";
	}
	if(!$reply->{description}){
		$reply->{warning} .= main::__('Assign group description!')."<BR>";
	}
	if(!$reply->{generalpassword}){
		$reply->{warning} .= main::__('Assign password!')."<BR>";
	}
	if($reply->{accountsnumber} !~ /^[0-9]{1,2}$/ ){
		$reply->{warning} .= main::__('Enter the number of users correctly!')."<BR>";
	}
	if(!$reply->{fquota}){
		$reply->{warning} .= main::__('Enter the size of storage users!')."<BR>";
	}
	if(!$reply->{roomlist}){
		$reply->{warning} .= main::__('Assign classroom(s) which can be accessed by the users!')."<BR>";
	}
	
	if( exists($reply->{warning}) ){
		return $this->addNewGuestGroup($reply);
	}

	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
        my $DateNow = sprintf('%4d-%02d-%02d',$year+1900,$mon+1,$mday);
	my $CN = uc($reply->{cn});

	if( $DateNow le $reply->{expirationdategroup} ){

		# create group
		my %GROUP = ();
		$GROUP{cn} = $CN;
	        $GROUP{description} = $reply->{description};
		$GROUP{grouptype} = 'guest';
		$GROUP{role} = lc($reply->{cn});

		my $oss_group = oss_group->new();
		my $dng = $oss_group->add(\%GROUP);
	        if( !$dng )
	        {
	           return {
	                TYPE    => 'ERROR',
	                CODE    => $oss_group->{ERROR}->{code},
	                MESSAGE_NOTRANSLATE => $oss_group->{ERROR}->{text}
	           }
	        }

		$this->create_vendor_object($dng,'EXTIS','ExpirationDateGroup', "$reply->{expirationdategroup}" );
                if($reply->{privategroup} == 1){
                        $this->{LDAP}->modify( $dng, add => { writerDN => main::GetSessionValue('dn') } );
                }

		$this->make_delete_group_webdavshare( "$dng", "$reply->{webdav_access}" );
	
		if( $reply->{roomlist} ne 'all' ){
			my @rooms=();
			foreach my $r ( split /\n/, $reply->{roomlist} ) {
				push @rooms, $this->get_attribute($r,'description');
				foreach my $dn ( @{$this->get_workstations_of_room($r)} ){
				        push @pcs, $this->get_attribute($dn,'cn');
				}      
			}      
			$this->create_vendor_object($dng,'EXTIS','RoomList', join(/,/,@rooms) );
	        }elsif( $reply->{roomlist} eq 'all' ){
	                $this->create_vendor_object($dng,'EXTIS','RoomList', 'all' );
	        }      
	
		#create users
		$reply->{warning} = main::__('Users: ');
		for( my $i = 1; $i <= $reply->{accountsnumber}; $i++ ){
			my %USER =();
			$USER{role} = lc($reply->{cn});
			$USER{uid}  = lc($reply->{cn}).''.sprintf("%02i",$i);
			$USER{sn}   = $USER{uid};
			my @workgroup = ("$GROUP{cn}");
			$USER{group} = \@workgroup;
			$USER{userpassword} = $reply->{generalpassword};
			$USER{fquota} = $reply->{fquota};
	
			my $oss_user = oss_user->new();
	                my $dnu =$oss_user->add(\%USER);
	
	        	if( !$dnu ){
	        	   return {
	                	TYPE    => 'ERROR',
	       	         	CODE    => $oss_user->{ERROR}->{code},
	                	MESSAGE_NOTRANSLATE => $oss_user->{ERROR}->{text}
		           }
		        }
			$reply->{warning} .=  $this->get_attribute($dnu, 'uid').", ";

			if( scalar @pcs ) {
			        $this->{LDAP}->modify( $dnu, add => { sambaUserWorkstations => join(",", @pcs) } );
			}
			if($reply->{privategroup} == 1){
	               		$this->{LDAP}->modify( $dnu, add => { writerDN => main::GetSessionValue('dn') } );
		       	}

		}

		#create at
		my $cmd = "at 23:59 $reply->{expirationdategroup}";
                my $arg = "/usr/share/oss/setup/delete-guest-".$CN.".pl";
                my $tmp = cmd_pipe("$cmd", "$arg");

                # create /usr/share/oss/setup/delete-guest-<GroupName>.pl script
                my $deletescripturl = "/usr/share/oss/setup/delete-guest-".$CN.".pl";
                open(FILE,"\> $deletescripturl") or die "Can't open $deletescripturl !\n";
		my $mailto = $this->get_attribute(main::GetSessionValue('dn'),'mail');
                my $deleteguestscript = '#!/usr/bin/perl

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

use strict;
use oss_group;
use oss_user;
use oss_utils;

system("touch /usr/share/oss/setup/deleting-guest-'.$CN.'");
my $user = oss_user->new( { withIMAP=>1 } );
my $users =$user->get_users_of_group("'.$dng.'");
foreach my $dnu (@$users){
   if ( $user->get_primary_group_of_user($dnu)  eq "'.$dng.'" ) {
      $user->delete("$dnu");
   }
}

my $group = oss_group->new( { withIMAP=>1 } );

$group->delete("'.$dng.'");

system(\'echo "Delete in the '.$CN.' Group and users"|mail -s "OSS: Delete one group an users" -r '.$mailto.' '.$mailto.'\');
system("rm -r /etc/apache2/vhosts.d/oss-ssl/'.$CN.'.conf; rmdir /home/test; rm /usr/share/oss/setup/delete-guest-'.$CN.'.pl");
system("rm /usr/share/oss/setup/deleting-guest-'.$CN.'");
';
                printf FILE $deleteguestscript;
                close (FILE);
                chmod(0755, $deletescripturl );

		return $this->default($reply);
	}else{
		$reply->{warning} = main::__('The given expirationdategroup\'s value is older than todays date. Please add a future date');
		return $this->addNewGuestGroup($reply);
	}

}

sub delete
{
        my $this   = shift;
        my $reply  = shift;
	my $cn     = $this->get_attribute($reply->{line},'cn');
	my $dn     = $reply->{line};
        if( -e '/usr/share/oss/setup/delete-guest-'.uc($cn).'.pl' ) {
                system('nohup /usr/share/oss/setup/delete-guest-'.uc($cn).'.pl &');
        }
        else
        {
                system('nohup /usr/share/oss/tools/delete-guest-group.pl '.$cn.' &');
        }

        $this->default();
}

#-----------------------------------------------------------------------
# Private finctions
#-----------------------------------------------------------------------

sub get_current_guestgroups
{
    my $this        = shift;
    my $writerDN    = shift;
    my $school_base = shift || $this->{LDAP_BASE};
    $school_base    = $this->get_school_base($school_base);
    my @dn          = ();

    my $filter      = '(&(objectClass=SchoolGroup)(groupType=guest)(|(writerDN='.$writerDN.')(!(writerDN=*))))';;

    my $mesg = $this->{LDAP}->search( base   => 'ou=group,'.$school_base,
                                      filter => $filter,
                                      scope  => 'one',
                                      attrs  => [ 'dn' ]
                                    );
    foreach my $entry ( $mesg->entries() )
    {
      push @dn, $entry->dn();
    }
    return \@dn;
}

1;
