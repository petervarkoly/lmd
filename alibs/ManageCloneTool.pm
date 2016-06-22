# OSS Clone Tool Configuration Module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManageCloneTool;

use strict;
use oss_utils;
use Net::LDAP::Entry;
use Data::Dumper;
use vars qw(@ISA);

if( -e "/usr/share/oss/lib/oss_schools.pm" )
{
    require oss_schools;
    @ISA = qw(oss_schools);
}
else
{
    require oss_base;
    @ISA = qw(oss_base);
}

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my  $self   = undef;
    if( -e "/usr/share/oss/lib/oss_schools.pm" )
    {
       $self    = oss_schools->new($connect);
    }
    else
    {
       $self    = oss_base->new($connect);
    }
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
                "syncToSchools",
                "search",
                "startSync",
                "startImaging",
		"startMulticast",
		"killMulticast",
		"start",
		"realy_delete_HW",
		"deleteHW",
		"realy_delete_img",
		"delete_img",
		"set_default_img",
		"pkgCategory",
		"pkgCategoryDetails",
		"applyChangesForWs",
		"applyChangesForWsReally",
		"setPkgsForHW",
		"pkgFilter",
		"back",
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
		{ variable     => [ "schoolTypes",  [ type => "list", size => '9', label=>"School Type" ] ] },
		{ variable     => [ "schools",      [ type => "list", size => '20', multiple=>"true", label=>"School" ] ] },
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
                { variable     => [ "date",             [ type => "date" ] ] },
                { variable     => [ "time",             [ type => "time" ] ] },
                { variable     => [ "promptly",         [ type => "boolean" ] ] }
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
		push @r, { name => 'pkgCategory', value => main::__('details'), attributes => [ type => 'action', help => "pkgAutoinstallationNotice" ] };
	}
	elsif( $WSType eq 'MobileDevice' )
	{
		$VALUES{MDM_OS}        = "" if( ! defined $VALUES{MDM_OS} );
		$VALUES{MDM_Policy}    = 0  if( ! defined $VALUES{MDM_Policy} );
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
				push @table , { line => [ $value , { name   => $value } , { name   =>'val', value => $mdm->get_policies($VALUES{MDM_Policy}), attributes=> [ type => 'popup' ] } ] };
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
	if( -e "/usr/share/lmd/alibs/ManageSchools.pm" )
	{
	        push @r, { action => 'syncToSchools' };
	}

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

sub syncToSchools
{
        my $this   = shift;
        my $reply  = shift;

        return [
                { filter      => $this->{filter} || '*' },
                { schoolTypes => $this->schoolTypes() },
               { dn          => $reply->{dn} },
                { rightaction => 'search' },
                { rightaction => 'cancel' }
        ]

}

sub search
{
        my $this   = shift;
        my $reply  = shift;
	return [
		{ schools     => $this->searchSchools(1,$reply->{schoolTypes},$reply->{filter}) },
		{ date        => '' },
		{ time        => '' },
		{ promptly    => 1  },
		{ dn          => $reply->{dn} },
		{ rightaction => 'startSync' },
		{ rightaction => 'cancel' }
	];
}

sub startSync
{
        my $this    = shift;
        my $reply   = shift;
	my $hw      = $reply->{dn};
        my $time   = $reply->{time}.' '.$reply->{date};
        if( $reply->{promptly} )
        {
                $time = 'now';
        }
	my $WARNING = '';
	my $newhw   = 'cephalix'.$hw;
	my $hwConf  = $this->get_entry( 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE} );

	foreach my $school ( split /\n/, $reply->{schools} )
	{
		my ($ldap, $sdn) = $this->connectSchool($school);
		my $sCN  =get_name_of_dn($school);
		if( !$ldap ) {
			$WARNING .= "=================================================================<br>";
			$WARNING .= "Can not connect the school: $sCN<br>";
			$WARNING .= $this->{ERROR}->{code}."<br>" if defined $this->{ERROR}->{code};
			$WARNING .= $this->{ERROR}->{text}."<br>" if defined $this->{ERROR}->{text};
			next;

		}
		if( -e "/var/adm/oss/$sCN-$newhw" )
		{
			my $tmp   = `find /var/adm/oss/$sCN-$newhw -printf "%AY-%Am-%Ad %AH:%AM"`;
			$WARNING .= "=================================================================<br>";
			$WARNING .= "Synnchronization into $sCN was already started at: $tmp.<br>";
			$WARNING .= "If this is false you have to remove /var/adm/oss/$sCN-$newhw on CEPHALIX.<br>";
			next;
		}
		my $result = $ldap->add(
			dn   => "configurationKey=$newhw,ou=Computers,$sdn",
			attr => [
				objectclass        => $hwConf->{objectclass},
				configurationKey   => $newhw,
				description        => 'Cephalix '.$hwConf->{description}->[0],
				configurationValue => $hwConf->{configurationvalue}
			]
		);
		if( $result->code == 68 )
		{
			$WARNING .= "=================================================================<br>";
			$WARNING .= 'Image '.$hwConf->{description}->[0].' in school '.$sCN.' do exists allready. Synchronization was started.<br>';
			$ldap->modify(
				"configurationKey=$newhw,ou=Computers,$sdn",
				replace => { configurationValue => $hwConf->{configurationvalue} }
			);
			$ldap->modify(
				"configurationKey=$newhw,ou=Computers,$sdn",
				replace => { description => 'Cephalix '.$hwConf->{description}->[0] }
			);
		}
		elsif( $result->code )
                {
                    $this->ldap_error($result);
                    return {
                                TYPE    => 'ERROR',
                                MESSAGE => $this->{ERROR}->{text}
                        };
                }
		my $command = "touch /var/adm/oss/$sCN-$newhw ;
			       rsync -aAv /srv/itool/images/$hw/ $sCN:/srv/itool/images/$newhw/ ;
			       rm -f /var/adm/oss/$sCN-$newhw ;";
		my $job = create_job($command, "Sync Image '$hw' to '$school'","$time");
		$this->add_value_to_vendor_object($school,'CEPHALIX','JOBS',$job );
		sleep(5);
	}
        if( $WARNING )
        {
            return {
			TYPE                => 'NOTICE' ,
			MESSAGE_NOTRANSLATE => $WARNING
                };
        }
        $this->default();
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

	my $msgInstallDefaultPkg = $this->installDefaultPkg($reply, 0);
	push @ret , @$msgInstallDefaultPkg if( defined $msgInstallDefaultPkg );
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

sub pkgCategory
{
	my $this   = shift;
	my $reply  = shift;
	my $hw     = $reply->{dn};
	my $hwDn   = 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my $hwDesc = $this->get_attribute( $hwDn, 'description');
	my $tmpCategory = $this->getPackageCategory();

	my $actPkgMsg = main::__('The currently assigned packages list:')."<BR>";
	my $actualPkgs = $this->get_config_values( $hwDn, 'SWPackage', 'ARRAY');
	if( defined $actualPkgs ){
		foreach my $pkgDn ( sort @$actualPkgs ){
			my $pkgName = $this->get_attribute( $pkgDn, 'configurationKey');
			my $pkgCategory = $this->get_config_value( $pkgDn, 'pkgCategory');
			$actPkgMsg .= $pkgName." --&gt; ".$pkgCategory."<BR>";
		}
	}

	my @pkgFilter = ( 'pkgFilter' );
	push @pkgFilter, { badhead => [ '' ] };
	push @pkgFilter, { line => [ 'pkgFilter',
					{ pkgNameForFilter => '*' },
					{ name => 'pkgFilter', value => main::__('pkgFilter'), attributes => [ type => 'action' ] },
					{ dn   => $hw },
			]};

	my @category = ( 'category' );
	push @category, { head => [ 'myCheckBox', 'msghelp', 'pkgCategoryDetails', 'categoryContent', ''] };
	foreach my $categoryName ( sort keys %{$tmpCategory} )
	{
		my $color = 'black';
		my $msg   = '';
		foreach my $pkgDn ( sort @{$tmpCategory->{$categoryName}->{pkgDn}}){
			my $pkgInfo = $this->getPkgInfo($pkgDn);
			if( $pkgInfo->{pkgWpkgXmlError} or $pkgInfo->{pkgInstSrcError} ){
				$color = 'red';
				$msg .= "<B>".$pkgInfo->{pkgName}.":</B><BR>";
			}
			if( $pkgInfo->{pkgWpkgXmlError} ){
				$msg .= $pkgInfo->{pkgWpkgXmlError}."<BR>";
			}
			if( $pkgInfo->{pkgInstSrcError} ){
				$msg .= $pkgInfo->{pkgInstSrcError}."<BR>";
			}
		}
		my $swPackages .= join("<BR>",@{$tmpCategory->{$categoryName}->{pkgName}});
		my $firstPkg = $tmpCategory->{$categoryName}->{pkgName}->[0].", ...";

		my @line = ( "$categoryName" );
		if( 'all' eq "$categoryName" ){
			push @line, { name => 'myCheckBox', value => '', attributes => [ type => 'label' ] };
		}else{
			push @line, { name => 'myCheckBox', value => '', attributes => [ type => 'boolean' ] };
		}
		if( $msg ne '' ){
			push @line, { name => 'msghelp', value => "", attributes => [ type => 'label', help => $msg ] };
		}else{
			push @line, { name => 'msghelp', value => "", attributes => [ type => 'label' ] };
		}
		push @line, { name => 'pkgCategoryDetails', value => main::__("$categoryName"), attributes => [ type => 'action', style => "color:".$color ] };
		push @line, { name => 'categoryContent',    value => "$firstPkg",               attributes => [ type => 'label',  style => "color:".$color, help => "$swPackages" ] };
		push @line, { dn => $hw };
		push @category, { line => \@line };
	}

	my @ret;
	push @ret, { subtitle => $hwDesc." / ".main::__("setPkgCategoryForHW") };
	push @ret, { ERROR    => $reply->{error} }   if( exists($reply->{error}) );
	push @ret, { NOTICE   => $reply->{warning} } if( exists($reply->{warning}) );
	push @ret, { NOTICE   => $actPkgMsg } if( defined $actualPkgs );
	push @ret, { label    => 'Package fileter' };
	push @ret, { table    => \@pkgFilter };
	push @ret, { label    => 'Category list' };
	push @ret, { table    => \@category };
	push @ret, { rightaction => 'setPkgsForHW' };
	push @ret, { rightaction => 'applyChangesForWs' } if( defined $actualPkgs );
	push @ret, { rightaction => 'back' };
	push @ret, { rightaction => 'cancel' };
	push @ret, { dn => $hw };
	return \@ret;
}

sub pkgCategoryDetails
{
	my $this   = shift;
	my $reply  = shift;
	my $hw     = $reply->{category}->{$reply->{line}}->{dn};
	my $hwDn   = 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my $hwDesc = $this->get_attribute( $hwDn, 'description');
	my $category = $reply->{line};
	my $tmpCategory = $this->getPackageCategory($category);

	my $actPkgMsg = main::__('The currently assigned packages list:')."<BR>";
	my $actualPkgs = $this->get_config_values( $hwDn, 'SWPackage', 'ARRAY');
	if( defined $actualPkgs ){
		foreach my $pkgDn ( sort @$actualPkgs ){
			my $pkgName = $this->get_attribute( $pkgDn, 'configurationKey');
			my $pkgCategory = $this->get_config_value( $pkgDn, 'pkgCategory');
			$actPkgMsg .= $pkgName." --&gt; ".$pkgCategory."<BR>";
		}
	}

	my @pkgFilter = ( 'pkgFilter' );
	push @pkgFilter, { badhead => [ '' ] };
	push @pkgFilter, { line => [ 'pkgFilter',
					{ pkgNameForFilter => '*' },
					{ name => 'pkgFilter', value => main::__('pkgFilter'), attributes => [ type => 'action' ] },
					{ dn => $hw },
			]};

	my @swPackages = ( 'swPackages' );
	foreach my $pkgDn ( sort @{$tmpCategory->{$category}->{pkgDn}} ){
		my $is = 0;
		if( defined $actualPkgs ){
			foreach my $pkgDnCurrent ( sort @$actualPkgs ){
				$is = 1 if( $pkgDn eq $pkgDnCurrent );
			}
		}
		my $pkgInfo = $this->getPkgInfo($pkgDn);
		my $pkgName = $pkgInfo->{pkgName};
		my $pkgDescription = $pkgInfo->{pkgDescription};
		my $pkgVersion = $pkgInfo->{pkgVersion};
		my $swLicense = '<a href="'.$pkgInfo->{swLicense}.'" target="_blank">'.main::__('swLicense').'</a>';
		my $color = 'black';
		my $msg = '';
		if( $pkgInfo->{pkgWpkgXmlError} or $pkgInfo->{pkgInstSrcError} ){
		$color = 'red';
			$msg .= "<B>".$pkgInfo->{pkgName}.":</B><BR>";
		}
		if( $pkgInfo->{pkgWpkgXmlError} ){
			$msg .= $pkgInfo->{pkgWpkgXmlError}."<BR>";
		}
		if( $pkgInfo->{pkgInstSrcError} ){
			$msg .= $pkgInfo->{pkgInstSrcError};
		}
		my @line = ("$pkgDn");
		push @line, { name => 'myCheckBox',      value => $is, attributes => [ type => 'boolean' ] };
		if( $msg ne '' ){
			push @line, { name => 'msghelp', value => "",  attributes => [ type => 'label', help => $msg ] };
		}else{
			push @line, { name => 'msghelp', value => "",  attributes => [ type => 'label' ] };
		}
		push @line, { name => 'pkgName',        value => "$pkgName",        attributes => [ type => 'label', style => 'color:'.$color, help => "$pkgDescription" ] };
		push @line, { name => 'pkgVersion',     value => "$pkgVersion",     attributes => [ type => 'label', style => 'color:'.$color ] };
		push @line, { name => 'swLicense',      value => "$swLicense",      attributes => [ type => 'label', style => 'color:'.$color ] };
		push @swPackages, { line => \@line };
	}

	my @ret;
	push @ret, { subtitle => $hwDesc." / ".main::__("setPkgCategoryForHW")." / ".$reply->{line} };
	push @ret, { ERROR    => $reply->{error} }   if( exists($reply->{error}) );
	push @ret, { NOTICE   => $reply->{warning} } if( exists($reply->{warning}) );
	push @ret, { NOTICE   => $actPkgMsg } if( defined $actualPkgs );
	push @ret, { label    => 'Package fileter' };
	push @ret, { table    => \@pkgFilter };
	push @ret, { label    => 'Software list' };
	push @ret, { table    => \@swPackages };
	push @ret, { rightaction => 'setPkgsForHW' };
	push @ret, { rightaction => 'applyChangesForWs' } if( defined $actualPkgs );
	push @ret, { rightaction => 'back' };
	push @ret, { rightaction => 'cancel' };
	push @ret, { dn => $hw };
	push @ret, { name => 'category_h', value => "$category", attributes => [ type => 'hidden' ] };
	return \@ret;
}

sub setPkgsForHW
{
	my $this  = shift;
	my $reply = shift;
	my $hw    = $reply->{dn};
	my $hwDn  = 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};

	my %tmpPkgs;
	if(exists($reply->{category})){
		foreach my $categoryName (sort keys %{$reply->{category}}){
			next if( !$reply->{category}->{$categoryName}->{myCheckBox} );
			my $tmpCategory = $this->getPackageCategory($categoryName);
			foreach my $pkgDn ( sort @{$tmpCategory->{$categoryName}->{pkgDn}} ){
				$tmpPkgs{$pkgDn} = 1;
			}
		}
	}
	if(exists($reply->{swPackages})){
		foreach my $pkgDn (sort keys %{$reply->{swPackages}}){
			if( $reply->{swPackages}->{$pkgDn}->{myCheckBox} ){
				$tmpPkgs{$pkgDn} = 1;
			}else{
				$tmpPkgs{$pkgDn} = 0;
			}
		}
	}

	if( !%tmpPkgs ){
		if( exists($reply->{category}) ){
			$reply->{error} = main::__('Please select at least one package category!');
			return $this->pkgCategory($reply);
		}
	}

	foreach my $pkgDn ( sort keys %tmpPkgs ){
		if( $tmpPkgs{$pkgDn} ){
			$this->add_config_value( $hwDn, 'SWPackage', $pkgDn);
		}else{
			$this->delete_config_value( $hwDn, 'SWPackage', $pkgDn);
		}
	}

	return $this->pkgCategory($reply);
}

sub pkgFilter
{
	my $this   = shift;
	my $reply  = shift;
	my $hw     = $reply->{pkgFilter}->{pkgFilter}->{dn}; 
	my $hwDn   = 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my $hwDesc = $this->get_attribute( $hwDn, 'description');
	my $filter = lc($reply->{pkgFilter}->{pkgFilter}->{pkgNameForFilter});

	my $actPkgMsg = main::__('The currently assigned packages list:')."<BR>";
	my $actualPkgs = $this->get_config_values( $hwDn, 'SWPackage', 'ARRAY');
	if( defined $actualPkgs ){
		foreach my $pkgDn ( sort @$actualPkgs ){
			my $pkgName = $this->get_attribute( $pkgDn, 'configurationKey');
			my $pkgCategory = $this->get_config_value( $pkgDn, 'pkgCategory');
			$actPkgMsg .= $pkgName." --&gt; ".$pkgCategory."<BR>";
		}
	}

	my @pkgFilter = ( 'pkgFilter' );
	push @pkgFilter, { badhead => [ '' ] };
	push @pkgFilter, { line => [ 'pkgFilter',
					{ pkgNameForFilter => '*' },
					{ name => 'pkgFilter', value => main::__('pkgFilter'), attributes => [ type => 'action' ] },
					{ dn => $hw },
				]};

	my @package = ( 'swPackages' );
	my $allPackage = $this->getAllPackage(1);
	foreach my $pkgDn ( sort keys %{$allPackage} )
	{
		my $pkgNameFilter = lc($allPackage->{$pkgDn}->{pkgName});
		next if( $pkgNameFilter !~ /(.*)$filter(.*)/ );
		my $is = 0;
		if( defined $actualPkgs ){
			foreach my $pkgDnCurrent ( sort @$actualPkgs ){
				$is = 1 if( $pkgDn eq $pkgDnCurrent );
			}
		}
		my $pkgName = $allPackage->{$pkgDn}->{pkgName};
		my $pkgDescription = $allPackage->{$pkgDn}->{pkgDescription};
		my $pkgVersion = $allPackage->{$pkgDn}->{pkgVersion};
		my $swLicense = '<a href="'.$allPackage->{$pkgDn}->{swLicense}.'" target="_blank">'.main::__('swLicense').'</a>';
		my $color = 'black';
		my $msg = '';
		if( $allPackage->{$pkgDn}->{pkgWpkgXmlError} or $allPackage->{$pkgDn}->{pkgInstSrcError} ){
			$color = 'red';
			$msg .= "<B>".$allPackage->{$pkgDn}->{pkgName}.":</B><BR>";
		}
		if( $allPackage->{$pkgDn}->{pkgWpkgXmlError} ){
			$msg .= $allPackage->{$pkgDn}->{pkgWpkgXmlError}."<BR>";
		}
		if( $allPackage->{$pkgDn}->{pkgInstSrcError} ){
			$msg .= $allPackage->{$pkgDn}->{pkgInstSrcError};
		}
		my @line = ("$pkgDn");
		push @line, { name => 'myCheckBox',      value => $is, attributes => [ type => 'boolean' ] };
		if( $msg ne '' ){
			push @line, { name => 'msghelp', value => "",  attributes => [ type => 'label', help => $msg ] };
		}else{
			push @line, { name => 'msghelp', value => "",  attributes => [ type => 'label' ] };
		}
		push @line, { name => 'pkgName',        value => "$pkgName",        attributes => [ type => 'label', style => 'color:'.$color, help => "$pkgDescription" ] };
		push @line, { name => 'pkgVersion',     value => "$pkgVersion",     attributes => [ type => 'label', style => 'color:'.$color ] };
		push @line, { name => 'swLicense',      value => "$swLicense",      attributes => [ type => 'label', style => 'color:'.$color ] };
		push @package, { line => \@line };
	}

	my @ret;
	push @ret, { subtitle => $hwDesc." / ".main::__("pkgFilter") };
	push @ret, { ERROR    => $reply->{error} }   if( exists($reply->{error}) );
	push @ret, { NOTICE   => $reply->{warning} } if( exists($reply->{warning}) );
	push @ret, { NOTICE   => $actPkgMsg } if( defined $actualPkgs );
	push @ret, { label    => 'Package fileter' };
	push @ret, { table    => \@pkgFilter };
	push @ret, { label    => 'Software list' };
	push @ret, { table    => \@package };
	push @ret, { rightaction => 'setPkgsForHW' };
	push @ret, { rightaction => 'applyChangesForWs' };
	push @ret, { rightaction => 'back' };
	push @ret, { rightaction => 'cancel' };
	push @ret, { dn => $hw };
	return \@ret;
}

sub applyChangesForWs
{
	my $this   = shift;
	my $reply  = shift;
	my $hw     = $reply->{dn};
	my $hwDn   = 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my $hwDesc = $this->get_attribute( $hwDn, 'description');

	my $actPkgMsg = main::__('The currently assigned packages list:')."<BR>";
	my $actualPkgs = $this->get_config_values( $hwDn, 'SWPackage', 'ARRAY');
	if( defined $actualPkgs ){
		foreach my $pkgDn ( sort @$actualPkgs ){
			my $pkgName = $this->get_attribute( $pkgDn, 'configurationKey');
			my $pkgCategory = $this->get_config_value( $pkgDn, 'pkgCategory');
			$actPkgMsg .= $pkgName." --&gt; ".$pkgCategory."<BR>";
		}
	}

	my @works  = ('workstations');
        push @works, { line => [ 'all', { name =>  'all' }, { workstation => 0 } ] };
	my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
					    scope  => 'sub',
					    filter =>  '(&(objectClass=dhcpHost)(configurationValue=HW='.$hw.'))',
					    attrs  => ['cn'],
					);
	my $RES = $result->as_struct;
	foreach my $dn ( sort keys %$RES)
	{
		push @works, { line => [ $dn, { name => $RES->{$dn}->{cn}->[0] },{workstation => 0 }] };
	}


	my @ret;
	push @ret, { subtitle => $hwDesc." / ".main::__("applyChangesForWs") };
	push @ret, { ERROR    => $reply->{error} }   if( exists($reply->{error}) );
	push @ret, { NOTICE   => $reply->{warning} } if( exists($reply->{warning}) );
#	push @ret, { NOTICE   => main::__('applyChangesForWsNotice') };
	push @ret, { NOTICE   => $actPkgMsg } if( defined $actualPkgs );
	push @ret, { label    => 'installNow' };
	push @ret, { name     => 'installNow', value => 0, attributes => [ type => 'boolean' ] };
	push @ret, { label    => 'workstations' };
	push @ret, { table    => \@works };
	push @ret, { rightaction => 'applyChangesForWsReally' };
	push @ret, { rightaction => 'back' };
	push @ret, { rightaction => 'cancel' };
	push @ret, { dn => $hw };
	return \@ret;
}

sub applyChangesForWsReally
{
	my $this   = shift;
	my $reply  = shift;
	my $installNow = $reply->{installNow};

	$reply->{hw} = $reply->{dn};
	my $msgInstallDefaultPkg = $this->installDefaultPkg($reply, $installNow);

	my @ret;
	push @ret, @{$msgInstallDefaultPkg};
	push @ret, { action => 'cancel' };
	return \@ret;
}

sub back
{
	my $this  = shift;
	my $reply = shift;

	if( $reply->{rightaction} eq 'applyChangesForWsReally' ){
		return $this->pkgCategory($reply);
	}
	if( exists($reply->{swPackages}) ){
		return $this->pkgCategory($reply);
	}
	if( exists($reply->{category}) ){
		$reply->{line} = $reply->{dn};
		return $this->editHW($reply);
	}
	return $this->default();
}

sub installDefaultPkg
{
	my $this   = shift;
	my $reply  = shift;
	my $installNow = shift || 0;
	my $hw     = $reply->{hw};
	my $hwDn   = 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
	my $hwDesc = $this->get_attribute( $hwDn, 'description');

	my @wsUserDns = ();
	if( exists($reply->{workstations}) ){
		if( $reply->{workstations}->{all}->{workstation} ){
			my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
							    scope  => 'sub',
							    filter =>  '(&(objectClass=dhcpHost)(configurationValue=HW='.$hw.'))',
							    attrs  => ['cn'],
						);
			my $RES = $result->as_struct;
			foreach my $dn ( sort keys %$RES){
				my $hostname = $RES->{$dn}->{cn}->[0];
				push @wsUserDns, $this->get_user_dn($hostname);
			}
		}else{
			foreach ( keys %{$reply->{workstations}} ){
				next if ( $_ eq 'all' );
				if( $reply->{workstations}->{$_}->{workstation} ){
					my $hostname = $this->get_attribute($_,'cn');
					push @wsUserDns, $this->get_user_dn($hostname);
				}
			}
		}
	}
	if( !scalar(@wsUserDns) ){
		$reply->{dn} = $hw;
		$reply->{error} = main::__('Please, choose at least one workstation!');
		return $this->applyChangesForWs($reply);
	}

	my $actualPkgs = $this->get_config_values( $hwDn, 'SWPackage', 'ARRAY');
	if( ! defined $actualPkgs ){
		$reply->{dn} = $hw;
		$reply->{error} = main::__('Please, configure at least one default package!');
		return $this->applyChangesForWs($reply);
	}
	my @selectedPkg;
	foreach my $pkgDn ( sort @$actualPkgs ){
		push @selectedPkg, $this->get_attribute( $pkgDn, 'configurationKey' );
	}

	my @wsList = ();
	my $h = $this->makeInstallDeinstallCmd('install', \@wsUserDns, $actualPkgs );
	foreach my $wsUserDn ( keys %{$h}){
		my $wsUserUid = $this->get_attribute($wsUserDn, 'uid');
		push @wsList, $wsUserUid;
	}

	if( $installNow and scalar(@wsList) ){
		makeInstallationNow(\@wsList);
	}

	my @ret;
	# Selected pc's and softwares
	push @ret, { NOTICE => main::__('selected_workstation:')." ".join(', ', @wsList)."<BR>".main::__('selected_package:')." ".join(', ', @selectedPkg) };

        # Missing sw requiremente
#       push @ret, { ERROR  => main::__('The following requirement packages are missing:')." <B>".$result->{missing_sw_list}."</B>" } if($result->{missing_sw_list});

	# Exists status
	my $exist = '';
	foreach my $wsUidDn ( sort keys %{$h} ){
		my $wsName = $this->get_attribute( $wsUidDn, 'uid' );
		foreach my $pkgDn ( sort keys %{$h->{$wsUidDn}} ){
			next if(!exists($h->{$wsUidDn}->{$pkgDn}->{exist}));
			my $swName = $this->get_attribute( $pkgDn, 'configurationKey' );
			my $status = $h->{$wsUidDn}->{$pkgDn}->{exist};
			$exist .= $wsName."  &lt;----  ".$swName."  <B>(".main::__($status).")</B>, <BR>";
		}
	}
	push @ret, { NOTICE => main::__('There is an installation status for the selected computers and packages:')."<BR>".$exist } if($exist);

	# Install cmd 
	my $inst_ok  = '';
        my $inst_nok = '';
        my $remove_old_version = '';
        foreach my $wsUidDn ( sort keys %{$h} ){
                my $wsName = $this->get_attribute( $wsUidDn, 'uid' );
                foreach my $pkgDn (sort keys %{$h->{$wsUidDn}->{install}} ){
                        my $swName = $this->get_attribute( $pkgDn, 'configurationKey' );
                        if ( exists($h->{$wsUidDn}->{install}->{$pkgDn}->{removefirst}) ){
                                foreach my $pkgn ( sort @{$h->{$wsUidDn}->{install}->{$pkgDn}->{removefirst}}){
                                        $remove_old_version .= $wsName."  ----&gt;  ".$pkgn."<BR>";
                                }
                        }elsif( $h->{$wsUidDn}->{install}->{$pkgDn}->{flag} ){
                                $inst_ok  .= $wsName."  &lt;----  ".$swName."  <B>(".main::__('installation_scheduled').")</B>, <BR>";
                        }else{
                                $inst_nok .= $wsName."  &lt;----  ".$swName."  <B>(".main::__('installation_scheduled').")</B>, <BR>";
                        }
                }
        }
        push @ret, { NOTICE => main::__('installation_scheduled').":<BR>".$inst_ok } if($inst_ok);
        push @ret, { ERROR  => main::__('Install command can not be executable successfully the following PCs, because there is no license key or have other problem:')."<BR>".$inst_nok } if($inst_nok);
        push @ret, { ERROR  => main::__('Remove the following packages if you want to install the selected packages:')."<BR>".$remove_old_version } if($remove_old_version);

        # Deinstall cmd
        my $deinst_ok  = '';
        my $deinst_nok = '';
        foreach my $wsUidDn ( sort keys %{$h} ){
                my $wsName = $this->get_attribute( $wsUidDn, 'uid' );
                foreach my $pkgDn (sort keys %{$h->{$wsUidDn}->{deinstall}} ){
                        my $swName = $this->get_attribute( $pkgDn, 'configurationKey' );
                        if( $h->{$wsUidDn}->{deinstall}->{$pkgDn}->{flag} ){
                                $deinst_ok  .= $wsName."  ----&gt;  ".$swName."  <B>(".main::__('deinstallation_scheduled').")</B>, <BR>";
                        }else{
                                $deinst_nok .= $wsName."  ----&gt;  ".$swName."  <B>(".main::__('deinstallation_scheduled').")</B>, <BR>";
                        }
                }
        }
        push @ret, { NOTICE => main::__('deinstallation_scheduled')."<BR>".$deinst_ok } if($deinst_ok);
        push @ret, { ERROR => main::__('Deinstall command can not be executable successfully the following PCs, because there is not installed:')."<BR>".$deinst_nok } if($deinst_nok);

        return \@ret;
}

1;
