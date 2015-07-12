# LMD ClassRoomOverview  modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ClassRoomOverview;

use strict;
use oss_base;
use oss_utils;
use oss_pedagogic;
use vars qw(@ISA);
use Data::Dumper;
@ISA = qw(oss_base);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_base->new($connect);
    return bless $self, $this;
}

sub interface
{
	return [
		"getCapabilities",
		"default",
		"apply",
		"close_room",
		"open_room",
		"WOLCmd",
		"shut_down",
		"printing_allowed",
		"direct_internet_access",
		"internet_allowed",
		"samba",
		"deactivate",
	];
}


sub getCapabilities
{
	return [
		{ title        => 'ClassRoomOverview' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ category     => 'Students' },
		{ order        => 3 },
		{ variable     => [ "name_rooms",                      [ type => "label" ] ] },
		{ variable     => [ "rooms",                           [ type => "popup" ] ] },
		{ variable     => [ "apply",                           [ type => "action" ] ] },
		{ variable     => [ "room_array",                      [ type => "hidden" ] ] },
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my $role   = main::GetSessionValue('role');
	if( $role =~ /^teachers/ )
	{
		$this->showMyClassRoomOverview($reply);
	}
	elsif( $role =~ /^root|sysadmins$/ )
	{
		$this->showClassRoomsOverview($reply);
	}
}

sub showClassRoomsOverview
{
	my $this   = shift;
	my $reply  = shift;
	my @rooms  = $this->get_rooms();
	if( ! @rooms  || !scalar(@rooms))
	{
		return { TYPE     => 'NOTICE',
			 MESSAGE  => 'no_rooms_defined',
			 MESSAGE1 => 'Please create rooms!'
			};
	}

	my $myroom = $this->get_room_by_name(main::GetSessionValue('room'));
	if( (!$myroom) or (exists($reply->{warning})) ){
		my @rooms = ('rooms');
		my @roomsname = $this->get_rooms();
		my @ret;
		push @rooms, { head => ['', '', '' ]};
		push @rooms, { line => [ 'schools_name',
						{ name_rooms => main::__('Please choose a room:') },
						{ rooms => \@roomsname },
						{ apply => main::__("apply")},
				]};
		push @ret, { table => \@rooms };
		return \@ret;
	}else{
		$reply->{rooms}->{schools_name}->{rooms} = "$myroom";
		$this->apply($reply);
	}
}

sub showMyClassRoomOverview
{
	my $this   = shift;
	my $reply  = shift;
	my $room   = main::GetSessionValue('room');
	my $LANG   = main::GetSessionValue('lang');
	$room      = $this->get_room_by_name($room);

	if( ! $room )
	{
		$this->chooseRoom();
	}else{
		my ( $control, $controller, $controllers ) = $this->get_room_control_state($room);
		if( $control eq 'no_control' )
		{
			$this->chooseRoom(main::__('No control allowed in this room.'));
		}

		$reply->{rooms}->{schools_name}->{rooms} = "$room";
		$this->apply($reply);
	}
}

sub apply
{
	my $this   = shift;
	my $reply  = shift;
	my @ret;
	my $room_dn = $reply->{rooms}->{schools_name}->{rooms};
	my $SESSIONID = $reply->{SESSIONID} || $reply->{rooms}->{schools_name}->{SESSIONID};

	if(!$room_dn){
		$reply->{warning} = 1;
		return $this->default($reply);
	}

	my $rooms;
	my @roomsname;
	my @rooms = ('rooms');
	if( exists($reply->{rooms}->{schools_name}->{room_array}) )
	{
		my @array = split( " ",$reply->{rooms}->{schools_name}->{room_array});
		foreach my $i (@array){
			my $dn    = $this->get_room_by_name($i);
			push @roomsname, [ $dn, $i ];
		}
		if($reply->{rooms}->{schools_name}->{rooms} !~ /^cn=(.*),cn=(.)/){
			$room_dn = $this->get_room_by_name($reply->{rooms}->{schools_name}->{rooms});
		}
		push @rooms, { head => ['', '', '' ]};
                push @rooms, { line => [ 'schools_name',
                                                { name_rooms => main::__('Please choose a room:') },
                                                { rooms =>  [ @roomsname, '---DEFAULTS---', $room_dn ] },
						{ room_array => "$reply->{rooms}->{schools_name}->{room_array}" },
                                                { apply => main::__("apply")},
                                        ]};
	}
	elsif( ($this->get_room_by_name(main::GetSessionValue('room'))) and (main::GetSessionValue('role') eq 'teachers') )
	{
	}
	else
	{
		#-------get rooms----------
		my @roomsname = $this->get_rooms();
		push @rooms, { head => ['', '', '' ]};
		push @rooms, { line => [ 'schools_name',
						{ name_rooms => main::__('Please choose a room:') },
						{ rooms =>  [ @roomsname, '---DEFAULTS---', $room_dn ] },
						{ apply => main::__("apply")},
					]};
	}
	push @ret, { table => \@rooms };

	#-------get room access control------------
	push @ret, { label => main::__("Room Access Control") };
	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($room_dn);
	my ($print_color, $all_color, $proxy_color, $samba_color) = '';
	my   @room_access_control = ('room_access_control');
	push @room_access_control, { head => [ '', '', '', '','']};
	if( $print || $all || $proxy || $samba )
	{
		push @room_access_control, { line => [ 'closeopen', 
						{ name => 'WOLCmd',     value => 'WOLCmd',     attributes => [ type => 'action', style => "color:green"] },
						{ name => 'close_room', value => 'close_room', attributes => [ type => 'action', style => "color:red"] },
						{ name => 'shut_down',  value => 'shut_down',  attributes => [ type => 'action', style => "color:red"] },
						{ name => 'room_dn',    value => "$room_dn",   attributes => [ type => 'hidden' ] } ] };
	}
	else
	{
		push @room_access_control, { line => [ 'closeopen', 
						{ name => 'WOLCmd',     value => 'WOLCmd',    attributes => [ type => 'action', style => "color:green"] },
						{ name => 'open_room',  value => 'open_room', attributes => [ type => 'action', style => "color:green"] },
						{ name => 'shut_down',  value => 'shut_down', attributes => [ type => 'action', style => "color:red"] },
						{ name => 'room_dn',    value => "$room_dn",  attributes => [ type => 'hidden' ] } ] };
	}
	if($print){ $print = "Disable Printing"; $print_color = "green"; }         else{ $print = "Enable Printing"; $print_color = "red"; }
	if($all)  { $all   = "Disable Direct Internet"; $all_color = "green"; }    else{ $all = "Enable Direct Internet"; $all_color = "red"; }
	if($proxy){ $proxy = "Disable filtered Internet"; $proxy_color = "green"; }else{ $proxy = "Enable filtered Internet"; $proxy_color = "red"; }
	if($samba){ $samba = "Disable Windows Login"; $samba_color = "green"; }    else{ $samba = "Enable Windows Login"; $samba_color = "red"; }

	if( main::isAllowed('RoomAccessControl.showMyRoom.all') )
	{
		push @room_access_control, { line => [ 'room_access_control',
						{ name => 'printing_allowed', value => main::__("$print"), attributes => [ type => 'action', style => "color:".$print_color] },
						{ name => 'direct_internet_access', value => main::__("$all"), attributes => [ type => 'action', style => "color:".$all_color] },
						{ name => 'internet_allowed', value => main::__("$proxy"), attributes => [ type => 'action', style => "color:".$proxy_color] },
						{ name => 'samba', value => main::__("$samba"), attributes => [ type => 'action', style => "color:".$samba_color] },
						{ name => 'room_dn', value => "$room_dn", attributes => [ type => 'hidden' ] },
					]};
	}
	else
	{
		push @room_access_control, { line => [ 'room_access_control',
						{ name => 'printing_allowed', value => main::__("$print"), attributes => [ type => 'action', style => "color:".$print_color] },
						{ name => 'internet_allowed', value => main::__("$proxy"), attributes => [ type => 'action', style => "color:".$proxy_color] },
						{ name => 'samba', value => main::__("$samba"), attributes => [ type => 'action', style => "color:".$samba_color] },
						{ name => 'room_dn', value => "$room_dn", attributes => [ type => 'hidden' ] },
					]};
	}
	push @ret, { table => \@room_access_control };

	#------get printer proplem-------
	push @ret, { label => "Printers Problem" };
	my @room_access_control = ('room_access_control');
	my $printer_problem = $this->get_printer_problem("$room_dn");
	foreach my $printer_name (sort keys %{$printer_problem}){
		push @room_access_control, { line => [ "$printer_name",
							{ name => 'printer_name', value => "$printer_name", attributes => [ type => 'label' , help => "$printer_problem->{$printer_name}->{status}"] },
							{ name => 'printer_problems', value => "$printer_problem->{$printer_name}->{value}", attributes => [ type => 'label'] },
						]};
	}

	if(scalar(@room_access_control) > 2){
		push @ret, { table => \@room_access_control };
	}

	#-------get white list----------
	push @ret, { label => "Internet Permission" };
	my $actuale_room   = main::GetSessionValue('room');
	$actuale_room      = $this->get_room_by_name($actuale_room);
	my $LANG       = main::GetSessionValue('lang');
	my @internet_permission = ('internet_permission');
	push @internet_permission, { head => ['whitelist_name', 'whitelist_description', 'allowedDomain' ]};
	my $white_lists = $this->get_vendor_object($room_dn,'oss','whiteLists');
	foreach my $whitelist (@$white_lists){
		my $whl_attrs = $this->get_attributes($whitelist, ['description', 'cn', 'allowedDomain']);
		my $allowDom_array = $whl_attrs->{allowedDomain};
		my $allowedDomain = '';
		foreach my $item (@$allowDom_array){
			$allowedDomain .= $item."<BR>";
		}
		my $label = get_name_of_dn($whitelist);
		if( $whl_attrs->{description}->[0]  =~ /^NAME-$LANG=(.*)$/m)
		{
			$label = $1;
		}
		push @internet_permission, { line => [ "$whitelist",
						{ name => 'whl_name', value => "$whl_attrs->{cn}->[0]", attributes => [type => 'label']},
						{ name => 'whl_description', value => "$label", attributes => [type => 'label']},
						{ name => 'whl_allowedDomain', value => "$allowedDomain", attributes => [type => 'label']},
						{ name => 'deactivate', value => main::__("deactivate"), attributes => [ type => 'action' ] },
						{ name => 'room_dn', value => "$room_dn", attributes => [ type => 'hidden' ] },
					]};		
	}
	if( scalar(@internet_permission) > 2){
		push @ret, { table => \@internet_permission };
	}
	if( "$actuale_room" eq "$room_dn" ){
                push @ret, {name => 'white_list_link', value => '<a href="/ossadmin/?application=WhiteLists" target="_blank">'.main::__('Activate additional List').'</a>', attributes => [ type => 'label', style => "width:150px", label => ""] };
	}

	#------set action---------------
	push @ret, { label => "Actions" };
	my @actions = ('actions');
        push @actions, { head => ['', '', '' ]};
	my $get_install_clax = `zypper --no-gpg-checks --gpg-auto-import-keys -n se oss-clax | grep oss-clax | gawk '{print \$1 }'`; 
	my @splt_get_install_clax = split("\n",$get_install_clax);
	if($splt_get_install_clax[0] eq "i"){
		push @actions, { line => [ "classroom_monitor",
							{ name => 'notranslate_classroom_monitor', value => '<a href="/monitor/rap?startup=main&sid='.$SESSIONID.'" target="_blank">'.main::__('ClientControl').'</a>', attributes => [ type => 'label'] },
					]};
	}
	push @actions, { line => [ "change_student_passw",
						{ name => 'notranslate_change_student_passw', value => '<a href="/ossadmin/?application=ManageStudents" target="">'.main::__('Change Student Password').'</a>', attributes => [ type => 'label'] }
					]};
	push @actions, { line => [ "test_wizard",
						{ name => 'notranslate_test_wizard', value => '<a href="/ossadmin/?application=TeacherTestWizard" target="">'.main::__('TeacherTestWizard').'</a>', attributes => [ type => 'label'] }
					]};
	push @ret, { table => \@actions };

	return \@ret;
}

sub chooseRoom
{
	my $this   = shift;
	my $reply  = shift;
	my $message= shift;
	$message .= main::__('You have to selet a room to control.');
	my @rooms  = ();
	push @rooms, @{$this->get_free_mobile_rooms()};
	push @rooms, @{$this->get_controlled_mobile_rooms()};
	if( ! scalar @rooms )
	{
		if( main::GetSessionValue('role') eq 'teachers,sysadmins' )
		{
			$this->showClassRoomsOverview();
		}
		else
		{
			return {
				TYPE     => 'NOTICE',
				MESSAGE  => 'control_only_in_classroom'
			};
		}
	}
	else
	{
		if( main::GetSessionValue('role') eq 'teachers,sysadmins' )
		{
			$this->showClassRoomsOverview();
		}
		else
		{
			my $room_array = '';
			foreach my $i (@rooms){
				my @array = split( " ",$i);
				$i = $array[0];
				$room_array .= $i." ";
			}
			my @ret;
			my @room = ('rooms');
			push @room, { head => ['', '', '' ]};
			push @room, { line => [ 'schools_name',
						{ name_rooms => main::__('Please choose a room:') },
						{ rooms => \@rooms},
						{ room_array => $room_array },
						{ apply => main::__("apply")},
					]};
			push @ret, { table => \@room };
			return \@ret;		
		}
	}
}

sub close_room
{

	my $this   = shift;
	my $reply  = shift;
	my $room = $reply->{room_access_control}->{closeopen}->{room_dn};
	my $ip = main::GetSessionValue('ip');
	$this->set_room_access_state( $room, 'printing', "0", $ip );
	$this->set_room_access_state( $room, 'all', "0", $ip );
	$this->set_room_access_state( $room, 'proxy', "0", $ip );
	$this->set_room_access_state( $room, 'samba', "0", $ip );
	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);
}

sub open_room
{

	my $this   = shift;
	my $reply  = shift;
	my $room = $reply->{room_access_control}->{closeopen}->{room_dn};
	my $ip = main::GetSessionValue('ip');
	$this->set_room_access_state( $room, 'printing', "1", $ip );
	$this->set_room_access_state( $room, 'all', "1", $ip );
	$this->set_room_access_state( $room, 'proxy', "1", $ip );
	$this->set_room_access_state( $room, 'samba', "1", $ip );
	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);
}

sub printing_allowed
{
	my $this   = shift;
	my $reply  = shift;
	my $room = $reply->{room_access_control}->{room_access_control}->{room_dn};
	my $ip = main::GetSessionValue('ip');

	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($room);
	if( $print ){
		$this->set_room_access_state( $room, 'printing', "0", $ip );
	}else{
		$this->set_room_access_state( $room, 'printing', "1", $ip );
	}
	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);
}

sub WOLCmd
{

	my $this   = shift;
	my $reply  = shift;
	my $room = $reply->{room_access_control}->{closeopen}->{room_dn};
        my $net     = new Net::Netmask( $this->get_school_config('SCHOOL_NETWORK'), $this->get_school_config('SCHOOL_NETMASK') );
        my $BC      = $net->broadcast();
        my @WSS     = ();
        foreach my $ws ( @{$this->get_workstations_of_room($room)} )
        {
	   print STDERR "Waking up:".get_name_of_dn($ws)."\n";
	   system('/usr/sbin/oss_control_client.pl --cmd WOLCmd --client '.get_name_of_dn($ws).' &');
        }
	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);

}

sub shut_down
{

	my $this   = shift;
	my $reply  = shift;
	my $room   = $reply->{room_access_control}->{closeopen}->{room_dn};
	my $mypc   = $this->get_workstation(main::GetSessionValue('ip'));
        foreach my $ws ( @{$this->get_workstations_of_room($room)} )
        {
	   next if ( $ws eq $mypc );
	   system('/usr/sbin/oss_control_client.pl --cmd ShutDownCmdSHUTDOWN --client '.get_name_of_dn($ws).' &');
	}
	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);
}


sub direct_internet_access
{
	my $this   = shift;
	my $reply  = shift;
	my $room = $reply->{room_access_control}->{room_access_control}->{room_dn};
	my $ip = main::GetSessionValue('ip');

	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($room);
	if( $all ){
		$this->set_room_access_state( $room, 'all', "0", $ip );
	}else{
		$this->set_room_access_state( $room, 'all', "1", $ip );
	}
	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);
}

sub internet_allowed
{
	my $this   = shift;
	my $reply  = shift;
	my $room = $reply->{room_access_control}->{room_access_control}->{room_dn};
	my $ip = main::GetSessionValue('ip');

	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($room);
	if( $proxy ){
		$this->set_room_access_state( $room, 'proxy', "0", $ip );
	}else{
		$this->set_room_access_state( $room, 'proxy', "1", $ip );
	}
	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);
}

sub samba
{
	my $this   = shift;
	my $reply  = shift;
	my $room = $reply->{room_access_control}->{room_access_control}->{room_dn};
	my $ip = main::GetSessionValue('ip');

	my ( $all, $mail, $print, $proxy, $samba ) = $this->get_room_access_state($room);
	if( $samba ){
		$this->set_room_access_state( $room, 'samba', "0", $ip );
	}else{
		$this->set_room_access_state( $room, 'samba', "1", $ip );
	}
	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);
}

sub deactivate
{
	my $this   = shift;
	my $reply  = shift;
	my $room = $reply->{internet_permission}->{$reply->{line}}->{room_dn};
#	my $room   = main::GetSessionValue('room');
#	$room      = $this->get_room_by_name($room);

	my $ped_wl = oss_pedagogic->new();
	$ped_wl->deactivate_whitelist($reply->{line},$room);

	$reply->{rooms}->{schools_name}->{rooms} = "$room";
	$this->apply($reply);
}

sub get_printer_problem
{
	my $this   = shift;
	my $room_dn  = shift;
	my %hash;

	my $dprinter =  $this->get_vendor_object($room_dn,'EXTIS','DEFAULT_PRINTER');
	$hash{$dprinter->[0]}->{status} = main::__("Default Printer");

	my $aprinters = $this->get_vendor_object($room_dn,'EXTIS','AVAILABLE_PRINTER');
	my @aprint = split ('\n',$aprinters->[0]);
	foreach my $aprinter ( @aprint ){
		$hash{$aprinter}->{status} = main::__("Available Printer");

	}

	foreach my $printer (sort keys %hash){
#		$hash{$printer}->{value} = main::__("Printer State : ");

		my $lpstat_p = `lpstat -p $printer`;
		my @lpstat_p = split(" ", $lpstat_p);
		if( $lpstat_p[2] eq 'disabled'){
			$hash{$printer}->{value} .= main::__("stopped, "); 
		}elsif( ($lpstat_p[4] eq 'enabled') and ($lpstat_p[3] eq 'idle.') ){
			$hash{$printer}->{value} .= main::__("idle, ");
		}

		my $lpstat_a = `lpstat -a $printer`;
		my @lpstat_a = split(" ", $lpstat_a);
		if( ($lpstat_a[1] eq 'not') and ($lpstat_a[2] eq 'accepting') ){
			$hash{$printer}->{value} .= main::__("rejecting jobs, ");
		}elsif( $lpstat_a[1] eq 'accepting' ){
			$hash{$printer}->{value} .= main::__("accepting jobs, ");
		}
	}

	return \%hash;
}

1;
