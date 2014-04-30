# OSS Clone Tool Configuration Module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManageCloneTool;

use strict;
use oss_base;
use oss_utils;
use Net::LDAP::Entry;
use Data::Dumper;

use vars qw(@ISA);
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
                "addNewHW",
                "insert",
                "editHW",
                "setHW",
                "startImaging",
		"startMulticast",
		"killMulticast",
		"start",
		"realy_delete_HW",
		"deleteHW",
		"realy_delete_img",
		"delete_img",
		"set_default_img",
		"sw_autoinstall",
		"realy_set_sofware",
		"set_sofware",
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Workstation Cloning Tool' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'Network' },
		{ order        => 20 },
		{ variable     => [ 'partition',    [ type => 'boolean', label=>''] ]},
		{ variable     => [ 'workstation',  [ type => 'boolean', label=>''] ]},
		{ variable     => [ 'delete',       [ type => 'boolean', label=>''] ]},
		{ variable     => [ 'name',         [ type => 'label',   label=>''] ]},
		{ variable     => [ 'dn',           [ type => 'hidden'  ] ]},
		{ variable     => [ 'hw',           [ type => 'hidden'  ] ]},
		{ variable     => [ 'description',  [ type => 'label'   ] ]},
		{ variable     => [ 'WSType',       [ type => 'popup'   ] ]},
		{ variable     => [ 'editHW',       [ type => 'action'  ] ]},
		{ variable     => [ 'startImaging', [ type => 'action'  ] ]},
		{ variable     => [ 'realy_delete_HW',[ type => 'action'  ] ]},
		{ variable     => [ 'deleteHW',     [ type => 'action'  ] ]},
		{ variable     => [ 'realy_delete_img',     [ type => 'action' ] ]},
		{ variable     => [ 'set_default_img',      [ type => 'action' ] ]},
		{ variable     => [ 'inst',                 [ type => 'boolean'] ]},
		{ variable     => [ 'namep',                [ type => 'label', label => 'name'] ]},
		{ variable     => [ 'description',          [ type => 'label'] ]},
		{ variable     => [ 'version',              [ type => 'label'] ]},
		{ variable     => [ 'type',                 [ type => 'label'] ]},
		{ variable     => [ 'category_name',        [ type => 'label'] ]},
	];
}

sub default
{
        my $this        = shift;
        my $reply       = shift;
        my @lines       = ('HW', { head => [ "editHW", "startImaging", "realy_delete_HW" ] } );

	my %SHW = ('SHW');
	foreach my $HW ( @{$this->get_HW_configurations(0)}  )
	{
		$SHW{SHW}->{$HW->[1]}=$HW->[0];
	}

	foreach my $HW_desc (sort keys %{$SHW{SHW}}  )
	{
		if( $this->get_computer_config_value('WSType',$SHW{SHW}->{$HW_desc}) eq 'MobileDevice' ) {
			push @lines, { line => [ $SHW{SHW}->{$HW_desc}, { editHW => $HW_desc }, { type => "" }, { realy_delete_HW => main::__('delete')} ] };
		}
		else
		{
			push @lines, { line => [ $SHW{SHW}->{$HW_desc}, { editHW => $HW_desc }, { startImaging => main::__('Start Imaging') }, { realy_delete_HW => main::__('delete')} ] };
		}
	}

#	foreach my $HW ( @{$this->get_HW_configurations(0)}  )
#	{
#	   push @lines, { line => [ $HW->[0], { editHW => $HW->[1] }, { startImaging => 'Start Imaging' } ] };
#	}
	if( scalar(@lines) > 1 )
	{
		return [
			{ table  => \@lines },
			{ action => 'addNewHW'}
		];
	}
	else
	{
		return [
			{ action => 'addNewHW' }
		];
	}
}

sub addNewHW
{
	my @WSType = (  'FatClient', 'ThinClient', 'LinuxTerminalServer', 'WindowsTerminalServer', '---DEFAULTS---',  'FatClient' );
	if( -e "/etc/sysconfig/OSS_MDM" && -e "/usr/share/lmd/helper/OSSMDM.pm" ) {
	   @WSType = (  'FatClient', 'MobileDevice', 'ThinClient', 'LinuxTerminalServer', 'WindowsTerminalServer', '---DEFAULTS---',  'FatClient' );
	}
	return [
		{ subtitle => 'Add New Computer Type' },
		{ name     => 'description', value => '' , attributes => [ type => 'string' ] },
		{ WSType   => \@WSType },
		{ action   => 'cancel' },
		{ action   => 'insert' }
	];
}

sub insert
{
        my $this        = shift;
        my $reply       = shift;
	my $key		= $this->add_new_HW($reply->{description},$reply->{WSType});
	if( ! $key )
	{
	   return {
                TYPE    => 'ERROR',
                CODE    => $this->{ERROR}->{code},
                MESSAGE_NOTRANSLATE => $this->{ERROR}->{text}
           }
	}
	$this->editHW({ line => $key });
}

sub editHW
{
        my $this   = shift;
        my $reply  = shift;
	my $hw	   = $reply->{line};
	my @r      = ();
	my %VALUES = ();
	my @table  = ( 'values' , { head => [ 'key' , 'value' , 'delete' ] } );
	my $result = $this->get_attributes( 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE},
					    ['configurationvalue','description']
					  );
	push @r, { name       => 'description',
		   value      => $result->{'description'}->[0],
	           attributes => [ type => 'string' ] };




	if( -e "/srv/itool/images/$hw/" ){
		push @r, { line => [ "/srv/itool/images/$hw/",
					{ name => 'image_path', value => main::__('image_path'), attributes => [ type => 'label' ] },
					{ name => 'image_path', value => "/srv/itool/images/$hw/", attributes => [ type => 'label' ] },
					{ realy_delete_img => main::__('realy_delete_img') },
			]};
	}
	foreach my $f ( sort ( glob "/srv/itool/images/$hw/*.img" ) ){
		next if($f !~ /^\/srv\/itool\/images\/(.*)\/([0-9:-]{20})(.*)\.img$/);
		my $change_name = $3;
		push @r, { line => [ "$f",
					{ name => 'backup_image', value => main::__('backup_image'), attributes => [ type => 'label' ] },
					{ name => 'img_name', value => "$2$3.img", attributes => [ type => 'label' ] },
					{ realy_delete_img => main::__('realy_delete_img') },
					{ set_default_img => main::__('set_default_img') },
			]};
	}

	foreach my $i ( @{$result->{'configurationvalue'}} )
	{
	    my ($k,$v) = split /=/,$i,2;
	    next if( $k eq 'TYPE' );
	    $VALUES{$k}=$v;
	}
	$VALUES{WSType} = 'FatClient' if( !defined $VALUES{WSType} );
	my $WSType      = $VALUES{WSType};
	if( $WSType eq 'FatClient' ) {
		push @r, { name => 'sw_autoinstall', value => main::__('details'), attributes => [ type => 'action' ] };
	}
	elsif( $WSType eq 'MobileDevice' )
	{
		$VALUES{MDM_OS}        = "" if( ! defined $VALUES{MDM_OS} );
		$VALUES{MDM_Policy}    = "" if( ! defined $VALUES{MDM_Policy} );
		$VALUES{MDM_Ownership} = "" if( ! defined $VALUES{MDM_Ownership} );
	}
	$VALUES{WSType} = [ 'FatClient', 'ThinClient', 'LinuxTerminalServer', 'WindowsTerminalServer', '---DEFAULTS---', $WSType ];
        if( -e "/etc/sysconfig/OSS_MDM" && -e "/usr/share/lmd/helper/OSSMDM.pm" ) {
           $VALUES{WSType} = [ 'FatClient', 'MobileDevice', 'ThinClient', 'LinuxTerminalServer', 'WindowsTerminalServer', '---DEFAULTS---',  $WSType ];
        }
	$VALUES{Warranty} ='' if ( !defined $VALUES{Warranty} );
	foreach my $value ( sort keys %VALUES )
	{
		if( $value eq 'WSType' )
		{
		        push @table , { line => [ $value , { name   => $value } , { name   =>'val', value => $VALUES{$value}, attributes=> [ type => 'popup' ] } ] };
		}
		elsif( $value eq 'MDM_Ownership' ) {
			my @VAL = ('COD','BYOD','UNKNOWN');
			push @VAL, ('---DEFAULTS---',$VALUES{MDM_Ownership}) if $VALUES{MDM_Ownership} ne "";
			push @table , { line => [ $value , { name   => $value } , { name   =>'val', value => \@VAL, attributes=> [ type => 'popup' ] } ] };
		}
		elsif( $value eq 'MDM_OS' ) {
			my @VAL = ('IOS','ANDROID');
			push @VAL, ('---DEFAULTS---',$VALUES{MDM_OS}) if $VALUES{MDM_OS} ne "";
			push @table , { line => [ $value , { name   => $value } , { name   =>'val', value => \@VAL, attributes=> [ type => 'popup' ] } ] };
		}
		elsif( $value eq 'MDM_Policy' ) {
			if( $WSType eq 'MobileDevice' && -e "/etc/sysconfig/OSS_MDM" && -e "/usr/share/lmd/helper/OSSMDM.pm" )
			{
				push    @INC,"/usr/share/lmd/helper/";
				require OSSMDM;
				my $mdm = new OSSMDM;
				my @policies = ();
				foreach my $p ( @{$mdm->get_policies()} ) {
				    if( defined $p->{published}->{name} ) {
				    	push @policies, [ $p->{uuid} , $p->{published}->{name} ];
				    }
				}
				push @policies, ('---DEFAULTS---',$VALUES{MDM_Policy}) if $VALUES{MDM_Policy} ne "";
				push @table , { line => [ $value , { name   => $value } , { name   =>'val', value => \@policies, attributes=> [ type => 'popup' ] } ] };
			}
		}
		elsif( $value eq 'Warranty' )
		{
			push @table , { line => [ $value , { name   => $value } , { name   =>'val', value => $VALUES{$value}, attributes=> [ type => 'date' ] } ] };
		}
		elsif( $value eq 'SWPackage' or $value eq 'SWPackageCategory' ){
			next;
		}
		else
		{
			push @table , { line => [ $value , { notranslate_name   => $value } , { val    => $VALUES{$value} }, { delete => 0 } ] };
		}
	}
	push @r, { table  => \@table };
	push @r, { label  => 'New Value' };
	push @r, { table  => [ new => { line => [ 'new' , { key => '' } , { value => '' } ] }]};
	push @r, { dn     => $reply->{line} };
	push @r, { action => 'cancel' };
	push @r, { name => 'action', value => "setHW", attributes => [ label => 'apply' ] };
	return \@r;
}

sub setHW
{
        my $this   = shift;
        my $reply  = shift;
	my $dn     = 'configurationKey='.$reply->{dn}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};

	$this->{LDAP}->modify( $dn, replace => { description => $reply->{description} } );
	foreach my $key ( keys %{$reply->{values}} )
	{
                if( $reply->{values}->{$key}->{delete} ){
			$this->delete_config_value( $dn, "$key", "$reply->{values}->{$key}->{val}");
		}else{
			$this->set_config_value( $dn, "$key", "$reply->{values}->{$key}->{val}");
		}
	}
	if( $reply->{new}->{new}->{key} && $reply->{new}->{new}->{value} )
	{
		$this->add_config_value( $dn, "$reply->{new}->{new}->{key}", "$reply->{new}->{new}->{value}");
	}
	$this->editHW({ line=>$reply->{dn} });
}

sub realy_delete_img
{
	my $this   = shift;
	my $reply  = shift;
	my @ret;

	if( $reply->{line} =~ /^\/(.*)\/$/){
		push @ret, { subtitle    => main::__("Do you realy want to delete this hardware configuration directory?") };
	}else{
		push @ret, { subtitle    => main::__("Do you realy want to delete this image?") };
	}
	push @ret, { label       => $reply->{line} };
	push @ret, { action      => "cancel" };
	push @ret, { name => 'action', value => 'delete_img',  attributes => [ label => 'delete' ] };
	return \@ret;
}

sub delete_img
{
	my $this   = shift;
	my $reply  = shift;

	system("rm -r $reply->{label}");

	$reply->{label} =~ /^\/(.*)\/(.*)\/(.*)/;
	$reply->{line} = $2;
	$this->editHW($reply);
}

sub set_default_img
{
	my $this   = shift;
	my $reply  = shift;

	#backup img  ----> real img
	$reply->{line} =~ /^(.*)\/(.*)\/([0-9:-]{20})(.*)\.img$/;
	my $new_path = $1.'/'.$2.'/'.$4.'.img';

	# real img ----> backup img
	my $date = `ls --full-time $new_path | gawk '{print \$6"-"\$7}' | sed s/\.000000000//`; chomp($date);
	my $old_path = $1.'/'.$2.'/'.$date.'-'.$4.'.img';

	system("mv $new_path $old_path"); #Ex: sda3.img ---> 2011-09-02-15:32:39-sda3.img
	system("mv $reply->{line} $new_path"); #Ex: 2011-09-02-15:14:04-sda3.img ---> sda3.img

	$reply->{line} =~ /^\/(.*)\/(.*)\/(.*)/;
	$reply->{line} = $2;
	$this->editHW($reply);
}

sub startImaging
{
        my $this   = shift;
        my $reply  = shift;
	my $hw	   = $reply->{line};
	my @r      = ();
	my @lparts = ();
	my %parts  = ();
	my %os     = ();
	my @parts  = ('partitions');
	my @works  = ('workstations');


	my $result = $this->get_attributes( 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE},
					    ['configurationvalue','description']);
	push @r , { subtitle => $result->{'description'}->[0] };
	push @r , { name => 'multicast' , value => 0 ,     attributes => [ type => 'boolean',  label => 'Multicast' ] };
	push @r , { label    => 'Partitions' };
        foreach ( @{$result->{'configurationvalue'}} )
        {
	       if( /PART_(.*)_DESC=(.*)/)
		{
		   push @lparts, $1;
		   $parts{$1} = $2;
		}
		if( /PART_(.*)_OS=(.*)/)
		{
		   $os{$1} = $2;
		}
        }
	if( scalar(@lparts) > 1 )
	{
		push @parts, { line => [ 'all', { name=>'all' }, { partition => 0 } ] } ;
	}
	push @parts, { line => [ 'MBR', { name=>'MBR' }, { partition => 0 } ] } ;
	foreach ( @lparts )
	{
		push @parts, { line => [ $_, { name=>$_.' : '.$parts{$_} } , { partition => 0 } ]} ;
	}
	push @r , { table => \@parts };
	push @r , { label => 'Workstations' };
	push @works, { line => [ 'all', { name =>  'all' }, {workstation => 0 }] };
	$result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
					    scope  => 'sub',
					    filter =>  '(&(objectClass=dhcpHost)(configurationValue=HW='.$hw.'))',
					    attrs  => ['cn'],
					  );
        my $RES = $result->as_struct;
        foreach my $dn ( sort keys %$RES)
        {
                push @works, { line => [ $dn, { name => $RES->{$dn}->{cn}->[0] },{workstation => 0 }] };
	}
	push @r, { table => \@works };
	push @r, { hw     => $reply->{line} };
	push @r, { action => 'cancel' };
	push @r, { action => 'start' };
	return \@r;
}

sub start
{
        my $this   = shift;
        my $reply  = shift;
	my $WORKSTATIONS = '';
	my $PARTITIONS   = 'partitions ';
	my $MYPART       = '';

	if( $reply->{workstations}->{all}->{workstation} )
	{
		$WORKSTATIONS = "hw ".$reply->{hw}."\n";
	}
	else
	{
		foreach ( keys %{$reply->{workstations}} )
		{
			next if ( $_ eq 'all' ); 
			if( $reply->{workstations}->{$_}->{workstation} )
			{
				$WORKSTATIONS .= 'workstation '.$_."\n";
			}
		}
	}
	if( $reply->{partitions}->{all}->{partition} )
	{
		$PARTITIONS   = "partitions all\n";	
	}
	else
	{
		foreach ( keys %{$reply->{partitions}} )
		{
			next if ( $_ eq 'all' ); 
			if( $reply->{partitions}->{$_}->{partition} )
			{
				$MYPART      = $_;
				$PARTITIONS .= "$_,";
			}
		}
		$PARTITIONS =~ s/,$/\n/;
	}
	if( $WORKSTATIONS eq '' )
	{
		return { TYPE => 'ERROR', CODE => 'NO_WORKSTATION', MESSAGE => 'choose_workstation'};
	}

	if( $PARTITIONS eq 'partitions ' )
	{
		return { TYPE => 'ERROR', CODE => 'NO_PARTITION', MESSAGE => 'choose_partitions'};
	}

	if ( $reply->{multicast} )
	{
		$PARTITIONS .= "multicast 1\n".$PARTITIONS;
		if( $reply->{partitions}->{all}->{partition} || $PARTITIONS =~ /,/ )
		{
			return { TYPE => 'ERROR', CODE => 'TO_MUCH_PARTITIONS', MESSAGE => 'multicast_only_one_partition'};
		}
	}
	$PARTITIONS .= $WORKSTATIONS;
print "\nPARTITIONS $PARTITIONS\n";
	my $count = `echo "$PARTITIONS" | oss_restore_workstations.pl`;

	my @ret;
	if ( $reply->{multicast} )
	{
		push @ret, { label  => 'start_imaging' };
		push @ret, { hw     => $reply->{hw}.'/'.$MYPART };
		push @ret, { action => 'cancel' };
		push @ret, { action => 'startMulticast' };
	}
	push @ret, { NOTICE => main::__('pxe_written') };

	my $sw_inst_msg = $this->install_default_software($reply, 0);
	push @ret , @$sw_inst_msg if( scalar(@$sw_inst_msg) > 1 );
	return \@ret;
}

sub killMulticast
{
        my $this   = shift;
        my $reply  = shift;
	system("killall -9 udp-sender");
	$this->startMulticast($reply);
}

sub startMulticast
{
        my $this   = shift;
        my $reply  = shift;
	my $img    = '/srv/itool/images/'.$reply->{hw}.'.img';

	if ( `ps aux | grep udp-sender | grep -v 'grep udp-sender'` )
	{
		return [
			{ label  => 'An other UDP sender process is running:' },
			{ hw     => $reply->{hw} },
			{ action => 'cancel' },
			{ action => 'killMulticast' },
			{ action => 'startMulticast' }
		];
	}
	if( ! -e $img )
	{
		return { TYPE => 'ERROR', CODE => 'IMAGE_DOES_NOT_EXISTS', MESSAGE => 'image_do_not_exists', MESSAGE_NOTRANSLATE => $img};
	}
	# search for intern device
	# TODO it works only if firewall is configured
	my $dev = `. /etc/sysconfig/SuSEfirewall2; echo \$FW_DEV_INT | gawk '{ print \$1 }';`; chomp $dev;
	$dev = 'eth0' if( ! $dev ); 
	system("/usr/sbin/udp-sender --nokbd --interface $dev --file $img --autostart 2 2>/dev/null 1>/dev/null &");
	return { TYPE => 'NOTICE', MESSAGE => 'pxe_written'};
}

sub realy_delete_HW
{
	my $this  = shift;
	my $reply = shift;
	my $HW_desc = $this->get_attribute( "configurationKey=$reply->{line},$this->{SYSCONFIG}->{COMPUTERS_BASE}" ,'description');

	return [
		{ subtitle    => "Do you realy want to delete this Hardware Configuration" },
                { label       => $HW_desc },
                { action      => "cancel" },
                { name => 'action', value => 'deleteHW',  attributes => [ label => 'delete' ] },
		{ name => 'hw_config', value => "$reply->{line}", attributes => [ type => 'hidden']},
	];
}

sub deleteHW
{
        my $this  = shift;
        my $reply = shift;

	#set rooms and workstations "configurationValue= HW=-", if delete actual hw_config
	foreach my $room ($this->get_rooms())
	{
		my $dn_room = $room->[0];
		
		if( $this->check_config_value($dn_room,'HW',$reply->{hw_config}) )
		{
			$this->set_config_value($dn_room,'HW',"-");
		}
		foreach my $dn_ws (sort @{$this->get_workstations_of_room($dn_room)} )
		{
			if( $this->check_config_value($dn_ws,'HW',$reply->{hw_config}) )
			{
				$this->set_config_value($dn_ws,'HW',"-");
			}
		}
	}

	#delete actual hardware configuration in LDAP.
	my $hw_conf_dn = 'configurationKey='.$reply->{hw_config}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
        my $mesg = $this->{LDAP}->delete( $hw_conf_dn );
        if( $mesg->code() )
	{
                $this->ldap_error($mesg);
                return 0;
        }

	# delete hardwae configuration directories
	system('test -d /srv/itool/images/'.$reply->{hw_config}.' && rm -r /srv/itool/images/'.$reply->{hw_config});

	return $this->default();
}

sub sw_autoinstall
{
	my $this   = shift;
	my $reply  = shift;
	my $hw_dn  = 'configurationKey='.$reply->{dn}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my $hash   = $this->get_software_category();
	my @ret;

	my @categories = ( 'categories' );
	push @categories, { head => [ '', 'category_name', 'package_list', '' ] };
	foreach my $category ( sort keys %{$hash} ){
		my $package_list = '';
		my @sw_list;
		my $softwarePerCategory = '';
		foreach my $sw_dn ( sort keys %{$hash->{$category}} ){
			$package_list .= $hash->{$category}->{$sw_dn}."<BR>";
			push @sw_list, $hash->{$category}->{$sw_dn};
		}
		my @first_package = split("<BR>", $package_list);

		my @item = ( "$category" );
		if( $this->check_config_value($hw_dn, 'SWPackageCategory', "$category") ){
			push @item, {inst => "1"};
		}else{
			push @item, {inst => ""};
		}
		push @item, {category_name => $category};
		push @item, {name => 'package_list', value => $first_package[0]." ...", attributes => [ type => 'label', help => $package_list]};
		push @categories, { line => \@item };

	}

	push @ret, { subtitle => 'set_software_to_img' };
	push @ret, { table  => \@categories };
	push @ret, { action => 'cancel' };
	if( keys %{$hash} ){
		push @ret, { NOTICE => main::__('sw_autoinstall_note') };
		push @ret, { dn => $reply->{dn} };
		push @ret, { action => 'set_sofware' };
	}else{
		push @ret, { NOTICE => main::__('not_exist_software_package') };
	}
	return \@ret;	
}

sub set_sofware
{
	my $this   = shift;
        my $reply  = shift;
	my $hwconf = $reply->{dn};
	my $hw_dn  = 'configurationKey='.$hwconf.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my @ret;

	# clean swPackages from hwconf ldap settings
	my $addedSoftwares = $this->get_config_values($hw_dn, 'SWPackage', 'ARRAY');
	if( $addedSoftwares->[0] ){
		foreach my $hw_sw_value ( sort @$addedSoftwares ){
			$this->delete_config_value( $hw_dn, 'SWPackage', "$hw_sw_value");
		}
	}
	$addedSoftwares = $this->get_config_values($hw_dn, 'SWPackageCategory', 'ARRAY');
        if( $addedSoftwares->[0] ){
		foreach my $hw_sw_value ( sort @$addedSoftwares ){
			$this->delete_config_value( $hw_dn, 'SWPackageCategory', "$hw_sw_value");
		}
	}

	# insert swPackages to hwconf ldap settings
	foreach my $category ( keys %{$reply->{categories}})
	{
		if( $reply->{categories}->{$category}->{inst} )
		{
			$this->add_config_value( $hw_dn, 'SWPackageCategory', "$category");
			my $category_sw_list = $this->get_software_category($category);
			foreach my $sw_dn ( sort keys %{$category_sw_list->{$category}} ){
				my $sw_name = $category_sw_list->{$category}->{$sw_dn};
				$this->add_config_value( $hw_dn, 'SWPackage', "$sw_name");
			}
		}
	}


	my $softwares = $this->get_config_values( $hw_dn, 'SWPackage', 'ARRAY' );
	my $newsw = '';
	foreach my $i ( @{$softwares}){
		$newsw .= $i."<BR>";
	}
	my @ws = ( 'workstations' );
	push @ws, { head => [ 'pc_name', 'installed_sw', 'new_sw', 'install_new_sw' ] };
	foreach my $room ($this->get_rooms()){
		my $dn_room = $room->[0];
		foreach my $dn_ws (sort @{$this->get_workstations_of_room($dn_room)} ){
			if( $this->check_config_value($dn_ws,'HW',$hwconf) ){
				my $hostname = $this->get_attribute($dn_ws,'cn');
				my $user_dn = $this->get_user_dn($hostname);
				my $oldsw = '';
				foreach my $i (sort @{$this->search_vendor_object_for_vendor( 'osssoftware', $user_dn)}){
					my $sw_name = $this->get_attribute($i, 'configurationKey');
					my $status  = $this->get_attribute($i, 'configurationValue');
					$oldsw .= $sw_name."<BR>" if( $status eq 'installed');
				}
				push @ws, { line => [ $dn_ws, 
							{ name => 'pcname',      value => $hostname, attributes => [type => 'label'] },
							{ name => 'oldsw',       value => $oldsw,    attributes => [type => 'label'] },
							{ name => 'newsw',       value => $newsw,    attributes => [type => 'label'] },
							{ name => 'workstation', value => '1',       attributes => [type => 'boolean'] },
						 ]};
			}
		}
	}

	push @ret, { subtitle => 'set_software_to_img' };
	push @ret, { NOTICE => 'Software category was added successfully to the current hw config!' };
	push @ret, { action => 'cancel' };
	if( scalar(@ws) > 2 ){
		push @ret, { NOTICE =>  main::__('It was changed the available software package of the hw config, so it  can be installed for the PCs bellow.')."<BR>".
					main::__('Please, leave selected the PCs where do you wish to install the new softwares.') };
		push @ret, { table  => \@ws };
		push @ret, { name => 'sw_installing_now', value => "", attributes => [label => '', type => 'boolean', backlabel => 'Run now the install/deinstall command on these selected workstations'] };
		push @ret, { action => 'realy_set_sofware' };
	}else{
		push @ret, { NOTICE => 'There is no hw config associated to the PCs bellow' };
	}
	push @ret, { dn => $reply->{dn} };
	return \@ret;
}

sub realy_set_sofware
{
	my $this  = shift;
	my $reply = shift;
	my $hw_dn = 'configurationKey='.$reply->{dn}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	$reply->{hw} = $reply->{dn};
	$this->install_default_software($reply, $reply->{sw_installing_now});
}

sub install_default_software
{
	my $this   = shift;
	my $reply  = shift;
	my $sw_installing_now = shift || 0;
	my $hw_dn  = 'configurationKey='.$reply->{hw}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};

	my @ws_dns;
	if( exists($reply->{workstations}) ){
		if( $reply->{workstations}->{all}->{workstation} ){
			my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
							    scope  => 'sub',
							    filter =>  '(&(objectClass=dhcpHost)(configurationValue=HW='.$reply->{hw}.'))',
							    attrs  => ['cn'],
							);
			my $RES = $result->as_struct;
			foreach my $dn ( sort keys %$RES){
				my $hostname = $RES->{$dn}->{cn}->[0];
				push @ws_dns, $this->get_user_dn($hostname);
			}
		}else{
			foreach ( keys %{$reply->{workstations}} ){
				next if ( $_ eq 'all' );
				if( $reply->{workstations}->{$_}->{workstation} ){
					my $hostname = $this->get_attribute($_,'cn');
					push @ws_dns, $this->get_user_dn($hostname);
				}
			}
		}
	}else{
		foreach my $room ($this->get_rooms())
		{
			my $dn_room = $room->[0];
			foreach my $dn_ws (sort @{$this->get_workstations_of_room($dn_room)} )
			{
				if( $this->check_config_value($dn_ws,'HW',$reply->{hw}) )
				{
					my $hostname = $this->get_attribute($dn_ws,'cn');
					push @ws_dns, $this->get_user_dn($hostname);
				}
			}
		}
		
	}
	#print Dumper(@ws_dns);

	my $softwares = $this->get_config_values( $hw_dn, 'SWPackage', 'ARRAY' );
	my @sw_name_list;
	@sw_name_list = @{$softwares} if( ref($softwares) eq 'ARRAY');
	#print Dumper(@sw_name_list);

	my $result;
	if(ref($softwares) eq 'ARRAY' ){
		$result = $this->software_install_cmd(\@ws_dns, \@sw_name_list, $sw_installing_now);
	}
	#print Dumper($result);

	my $msg = $this->createSwInstallationStatusTable($result);
	#print Dumper($msg);
	return $msg;
}

sub createSwInstallationStatusTable
{
	my $this   = shift;
	my $result = shift;
	my @ret;

	# Selected pc's and softwares
	push @ret, { NOTICE => main::__('selected_computer: ')." ".$result->{selected_computer}."<BR>".main::__('selected_software: ')." ".$result->{selected_software} };

	# Missing sw requiremente
	push @ret, { ERROR  => main::__('The following requirement packages are missing:')." <B>".$result->{missing_sw_list}."</B>" } if($result->{missing_sw_list});

	# Install cmd 
	my $inst_ok  = '';
	my $inst_nok = '';
	foreach my $pc (sort keys %{$result->{installation_scheduled}} ){
		foreach my $sw (sort keys %{$result->{installation_scheduled}->{$pc}} ){
			if( $result->{installation_scheduled}->{$pc}->{$sw} ){
				$inst_ok  .= $pc."  &lt;----  ".$sw."  <B>(".main::__('installation_scheduled').")</B>, <BR>";
			}else{
				$inst_nok .= $pc."  &lt;----  ".$sw."  <B>(".main::__('installation_scheduled').")</B>, <BR>";
			}
		}
	}
	push @ret, { NOTICE => main::__('Executable successfully install command in the following PCs:')."<BR>".$inst_ok } if($inst_ok);
	push @ret, { ERROR  => main::__('Install command can not be executable successfully the following PCs, because there is no license key or have other problem:')."<BR>".$inst_nok } if($inst_nok);

	# Deinstall cmd
	my $deinst_ok  = '';
	my $deinst_nok = '';
	foreach my $pc (sort keys %{$result->{deinstallation_scheduled}} ){
		foreach my $sw (sort keys %{$result->{deinstallation_scheduled}->{$pc}} ){
			if( $result->{deinstallation_scheduled}->{$pc}->{$sw} ){
				$deinst_ok  .= $pc."  &lt;----  ".$sw."  <B>(".main::__('deinstallation_scheduled').")</B>, <BR>";
			}else{
				$deinst_nok .= $pc."  &lt;----  ".$sw."  <B>(".main::__('deinstallation_scheduled').")</B>, <BR>";
			}
		}
	}
	push @ret, { NOTICE => main::__('Executable successfully deinstall command in the following PCs:')."<BR>".$deinst_ok } if($deinst_ok);
	push @ret, { ERROR => main::__('Deinstall command can not be executable successfully the following PCs, because there is not installed:')."<BR>".$deinst_nok } if($deinst_nok);

	# Exists status
	my $exist = '';
        foreach my $pc (sort keys %{$result->{exists_status}} ){
                foreach my $sw (sort keys %{$result->{exists_status}->{$pc}} ){
			my $status = $result->{exists_status}->{$pc}->{$sw};
                        $exist .= $pc."  &lt;----  ".$sw."  <B>(".main::__($status).")</B>, <BR>";
                }
        }
        push @ret, { NOTICE => main::__('On the following PCs have the following command to be implemented:')."<BR>".$exist } if($exist);

	return \@ret;
}

1;
