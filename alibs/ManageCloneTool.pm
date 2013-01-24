# OSS Clone Tool Configuration Module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManageCloneTool;

use strict;
use oss_base;
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
	];
}

sub default
{
        my $this        = shift;
        my $reply       = shift;
        my @lines       = ('HW');

	my %SHW = ('SHW');
	foreach my $HW ( @{$this->get_HW_configurations(0)}  )
	{
		$SHW{SHW}->{$HW->[1]}=$HW->[0];
	}

	foreach my $HW_desc (sort keys %{$SHW{SHW}}  )
	{
		push @lines, { line => [ $SHW{SHW}->{$HW_desc}, { editHW => $HW_desc }, { startImaging => main::__('Start Imaging') }, { realy_delete_HW => main::__('delete')} ] };
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
	return [
		{ subtitle => 'Add New Computer Type' },
		{ name     => 'description', value => '' , attributes => [ type => 'string' ] },
		{ action   => 'cancel' },
		{ action   => 'insert' }
	];
}

sub insert
{
        my $this        = shift;
        my $reply       = shift;
	my $key		= $this->add_new_HW($reply->{description});
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
	push @r, { name => 'description',
		  value => $result->{'description'}->[0],
	     attributes => [ type => 'string' ] };


	push @r, { name => 'sw_autoinstall', value => main::__('details'), attributes => [ type => 'action' ] };


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
	$VALUES{WSType}     = 'FatClient' if( !defined $VALUES{WSType} );
	$VALUES{WSType} = [ 'FatClient', 'ThinClient', 'LinuxTerminalServer', 'WindowsTerminalServer',
			    '---DEFAULTS---', $VALUES{WSType} ];
	$VALUES{Warranty} ='' if ( !defined $VALUES{Warranty} );
	foreach ( sort keys %VALUES )
	{
		if( $_ eq 'WSType' )
		{
			push @table , { line => [ $_ , { name   => $_ } , 
					       { name   =>'val', value => $VALUES{$_}, attributes=> [ type => 'popup' ] } ] };
		}
		elsif( $_ eq 'Warranty' )
		{
			push @table , { line => [ $_ , { name   => $_ } , 
					       { name   =>'val', value => $VALUES{$_}, attributes=> [ type => 'date' ] } ] };
		}
		elsif( $_ eq 'SWPackage' ){
		}else
		{
			push @table , { line => [ $_ , { notranslate_name   => $_ } , 
					       { val    => $VALUES{$_} }, { delete => 0 } ] };
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
	my $sw_inst_msg = $this->install_deffault_software($reply);

	my @ret;
	if( scalar(@$sw_inst_msg) > 0 ){
		foreach my $item (@$sw_inst_msg){
			push @ret, $item;
		}
	}
	if ( $reply->{multicast} )
	{
		push @ret, { label  => 'start_imaging' };
		push @ret, { hw     => $reply->{hw}.'/'.$MYPART };
		push @ret, { action => 'cancel' };
		push @ret, { action => 'startMulticast' };
	}
	push @ret, { NOTICE => main::__('pxe_written') };
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
	my $rooms = $this->get_rooms();

	#set rooms and workstations "configurationValue= HW=-", if delete actual hw_config
	foreach my $dn_room (keys %{$rooms}){
		if( $rooms->{$dn_room}->{configurationvalue}->[0] eq "HW=$reply->{hw_config}"){
			$this->set_config_value($dn_room,'HW',"-");
		}
		foreach my $dn_ws (sort @{$this->get_workstations_of_room($dn_room)} ) {
			my @ws_hw_config = $this->get_attribute($dn_ws,'configurationValue');
			foreach my $config_value (@ws_hw_config){
				if( $config_value =~ /^HW=(.*)$/){
					if( "$1" eq "$reply->{hw_config}" ){
						$this->set_config_value($dn_ws,'HW',"-");
					}
				}
			}
		}
	}

	#delete actual hardware configuration in LDAP.
	my $hw_conf_dn = 'configurationKey='.$reply->{hw_config}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
        my $mesg = $this->{LDAP}->delete( $hw_conf_dn );
        if( $mesg->code() ){
                $this->ldap_error($mesg);
                return 0;
        }

	# delete hardwae configuration directories
	system("rm -r /srv/itool/images/$reply->{hw_config}");

	return $this->default();
}

sub sw_autoinstall
{
	my $this   = shift;
	my $reply  = shift;
	my $hw_dn  = 'configurationKey='.$reply->{dn}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my $hash;
	my @ret;

	my $obj = $this->search_vendor_object_for_vendor( 'osssoftware', "ou=Computers,$this->{LDAP_BASE}");
	foreach my $sw_dn ( sort @$obj )
	{
		my $h = $this->get_config_values($sw_dn, "", "HASH");
		$hash->{$h->{CATEGORIE}->[0]}->{$sw_dn} = $h;
	}

	foreach my $categorie ( sort keys %{$hash} )
	{
		push @ret, { label => $categorie };
		my @p = ( "$categorie" );
		push @p, { head => [ '', 'name', 'description', 'Version', 'type' ] };
		foreach my $sw_dn ( sort keys %{$hash->{$categorie}} ){
			my $pkg = $this->get_attribute( $sw_dn, 'configurationKey');
			my $is_set = $this->check_config_value( $hw_dn, 'SWPackage', "$pkg");
			push @p, { line => [ $sw_dn,
						{ inst => "$is_set" },
						{ namep => $pkg },
						{ description => $hash->{$categorie}->{$sw_dn}->{DESCRIPTION}->[0].'<BR><a href="'.$hash->{$categorie}->{$sw_dn}->{LICENSING}->[0].'" target="_blank">'.main::__('licens_link').'</a>'},
						{ version => $hash->{$categorie}->{$sw_dn}->{VERSION}->[0] },
						{ type => $hash->{$categorie}->{$sw_dn}->{TYPE}->[0] },
				]};
		}
                push @ret, { table  => \@p };
        }

	push @ret, { subtitle => 'set_software_to_img' };
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
	delete($reply->{NOTICE});
	delete($reply->{APPLICATION});
	delete($reply->{SESSIONID});
	delete($reply->{CATEGORY});
	delete($reply->{ACTION});
	delete($reply->{label});
	delete($reply->{rightaction});
	delete($reply->{dn});

	foreach my $categori ( keys %{$reply}){
		foreach my $sw_dn ( keys %{$reply->{$categori}} ){
			my $sw_name = $this->get_attribute($sw_dn, 'configurationKey');
			if( $reply->{$categori}->{$sw_dn}->{inst} ){
				$this->add_config_value( $hw_dn, 'SWPackage', "$sw_name");
			}else{
				$this->delete_config_value( $hw_dn, 'SWPackage', "$sw_name");
			}
		}
	}

	$reply->{dn} = $hwconf;
	$this->sw_autoinstall($reply);
}

sub install_deffault_software
{
	my $this   = shift;
	my $reply  = shift;
        my $hw_dn  = 'configurationKey='.$reply->{hw}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my $SOFTWARE = $this->get_config_values( $hw_dn, 'SWPackage' );

	my @workstations;
	if( $reply->{workstations}->{all}->{workstation} )
	{
		my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
						    scope  => 'sub',
						    filter =>  '(&(objectClass=dhcpHost)(configurationValue=HW='.$reply->{hw}.'))',
						    attrs  => ['cn'],
					);
		my $RES = $result->as_struct;
		foreach my $dn ( sort keys %$RES)
		{
			push @workstations, $RES->{$dn}->{cn}->[0];
		}
	}
	else
	{
		foreach ( keys %{$reply->{workstations}} )
		{
			next if ( $_ eq 'all' );
			if( $reply->{workstations}->{$_}->{workstation} )
			{
				push @workstations, $this->get_attribute($_, 'cn')
			}
		}
	}

	my $selected_computer = join(", ", @workstations);
	my $selected_software = '';
	$selected_software = join(", ", @$SOFTWARE) if($SOFTWARE ne '');
	my $no_prodkey = "";
	foreach my $ws_name ( sort @workstations ){
		my $ws_user_dn = 'o=oss,'.$this->get_user_dn("$ws_name");
		my $obj = $this->search_vendor_object_for_vendor( 'osssoftware', "$ws_user_dn");
		if( scalar(@$obj) > 0 ){
			foreach my $sw_user_dn ( @$obj ){
				my $sw_name = $this->get_attribute( $sw_user_dn, 'configurationKey' );
				my $sw_dn = "configurationKey=$sw_name,o=osssoftware,".$this->{SYSCONFIG}->{COMPUTERS_BASE};
				my $status= 1;
				if( $this->exists_dn( "o=productkeys,".$sw_dn )  ){
					$status = $this->prodkey_allocation($sw_dn, $ws_name);
					$no_prodkey .= $ws_name."  &lt;----  ".$sw_name.", <BR>" if($status eq 0);
				}
				$this->modify_vendor_object( $ws_user_dn, 'osssoftware', "$sw_name", "installation_scheduled") if($status);
			}
		}
		else
		{
			foreach my $sw_name ( @$SOFTWARE ){
				my $sw_dn = "configurationKey=$sw_name,o=osssoftware,".$this->{SYSCONFIG}->{COMPUTERS_BASE};
				my $status= 1;
				if( $this->exists_dn( "o=productkeys,".$sw_dn )  ){
					$status = $this->prodkey_allocation($sw_dn, $ws_name);
					$no_prodkey .= $ws_name."  &lt;----  ".$sw_name.", <BR>" if($status eq 0);
				}
				$this->create_vendor_object( $ws_user_dn, 'osssoftware', "$sw_name", "installation_scheduled") if($status);
			}
		}
	}

	my @ret;
	if( $selected_software ){
		push @ret, { NOTICE => main::__('selected_computer: ').$selected_computer."<BR>".main::__('selected_software: ').$selected_software };
	}
	if($no_prodkey){
		push @ret, { ERROR => main::__('The command can not be executable successfully the following PCs, because there is no license key:')."<BR>".$no_prodkey };
	}
	return \@ret;
}

1;
