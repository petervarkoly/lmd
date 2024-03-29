# OSS Room Configuration Module
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ManageRooms; 

use strict;
use oss_user;
use oss_utils;
use Net::LDAP::Entry;
use Data::Dumper;
use DBI;
use Net::Netmask;
use MIME::Base64;
use Storable qw(thaw freeze);

use vars qw(@ISA);
@ISA = qw(oss_user);

my @DHCPOptions = qw(
all-subnets-local
arp-cache-timeout
bootfile-name
boot-size
broadcast-address
cookie-servers
default-ip-ttl
default-tcp-ttl
dhcp-client-identifier
dhcp-lease-time
dhcp-max-message-size
dhcp-message
dhcp-message-type
dhcp-option-overload
dhcp-parameter-request-list
dhcp-rebinding-time
dhcp-renewal-time
dhcp-requested-address
dhcp-server-identifier
domain-name
domain-name-servers
extensions-path
finger-server
font-servers
host-name
ieee802-3-encapsulation
ien116-name-servers
impress-servers
interface-mtu
ip-forwarding
irc-server
log-servers
lpr-servers
mask-supplier
max-dgram-reassembly
merit-dump
mobile-ip-home-agent
nds-context
nds-servers
nds-tree-name
netbios-dd-server
netbios-name-servers
netbios-node-type
netbios-scope
nis-domain
nis-servers
nisplus-domain
nisplus-servers
nntp-server
non-local-source-routing
ntp-servers
nwip-domain
nwip-suboptions
path-mtu-aging-timeout
path-mtu-plateau-table
perform-mask-discovery
policy-filter
pop-server
resource-location-servers
root-path
router-discovery
router-solicitation-address
routers
slp-directory-agent
slp-service-scope
smtp-server
space
static-routes
streettalk-directory-assistance-server
streettalk-server
subnet-mask
subnet-selection
swap-server
tcp-keepalive-garbage
tcp-keepalive-interval
tftp-server-name
time-offset
time-servers
trailer-encapsulation
uap-servers
user-class
vendor-class-identifier
vendor-encapsulated-options
www-server
x-display-manager
);

my @DHCPStatements = qw(
allow
always-broadcast
authoritative
ddns-update-style
default-lease-time
deny
filename
get-lease-hostnames
use-host-decl-names
if
include
max-lease-time
next-server
option
range
type
);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_user->new($connect);
    $self->{RADIUS} = ($self->get_school_config('SCHOOL_USE_RADIUS') eq 'yes') ? 1 : 0;
    return bless $self, $this;
}

sub interface
{
        return [
                "addNewPC",
                "addNewRoom",
                "addEnrollment",
                "addPC",
                "addRoom",
                "control",
                "default",
                "del_room",
                "DHCP",
		"editPC",
                "getCapabilities",
                "modifyRoom",
                "realy_delete",
                "room",
                "roomGeometry",
                "roomType",
                "scanPCs",
                "setControl",
		"setDHCP",
                "setRoomGeometry",
                "setRooms",
                "setRoomType",
		"setWlanUser",
		"stateOfRooms",
		"renamePC",
		"applyRenamePC",
		"selectWlanUser",
		"setWlanUser",
		"ANON_DHCP",
		"insert_in_to_room",
		"install_software",
        ];
}

sub getCapabilities
{
        return [
                { title        => 'Managing the Rooms' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'teachers' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'Network' },
		{ order        => 10 },
		{ variable     => [ 'addNewPC',          [ type => 'action' ] ]},
		{ variable     => [ 'ANON_DHCP',         [ type => 'action' ] ]},
		{ variable     => [ 'DHCP',              [ type => 'action' ] ]},
		{ variable     => [ 'renamePC',          [ type => 'action' ]]},
		{ variable     => [ 'editPC',            [ type => 'action' , label => 'edit' ]] },
		{ variable     => [ 'room',              [ type => 'action' ]] },
		{ variable     => [ 'control',           [ type => 'action' ]] },
		{ variable     => [ 'del_room',          [ type => 'action', label => 'delete' ]] },
		{ variable     => [ 'set_free',          [ type => 'boolean' ]]  },
		{ variable     => [ 'wlanaccess',        [ type => 'boolean' ]]},
		{ variable     => [ 'mdm',               [ type => 'boolean' ]]},
		{ variable     => [ 'master',            [ type => 'boolean' ]]},
		{ variable     => [ 'delete',            [ type => 'boolean' ]]},
		{ variable     => [ 'free_busy',         [ type => 'img',    style => 'margin-right:80px;' ]]},
		{ variable     => [ 'description',       [ type => 'label'  ] ]},
		{ variable     => [ 'network',           [ type => 'label', ] ]},
		{ variable     => [ 'users',             [ type => 'label', ] ]},
		{ variable     => [ 'teachers',          [ type => 'list', size => '15', multiple=>"true" ]]  },
		{ variable     => [ 'workstations',      [ type => 'list', size => '10' ]]  },
		{ variable     => [ 'dn',                [ type => 'hidden' ]]  },
		{ variable     => [ 'rdn',               [ type => 'hidden' ]]  },
		{ variable     => [ 'roomtype',          [ type => 'hidden' ]]  },
		{ variable     => [ 'OS',                [ type => 'popup' ]] },
		{ variable     => [ 'ownership',         [ type => 'popup' ]] },
		{ variable     => [ 'role',              [ type => "list", size=>"6",  multiple=>"true" ]] },
		{ variable     => [ 'class',             [ type => "list", size=>"10", multiple=>"true" ]] },
		{ variable     => [ 'workgroup',         [ type => "list", size=>"10", multiple=>"true" ]] },
		{ variable     => [ 'freerooms',         [ type => 'popup' ]] },
		{ variable     => [ 'rooms',             [ type => 'popup' ]] },
		{ variable     => [ 'dhcpOptions',       [ type => 'popup' ]] },
		{ variable     => [ 'dhcpStatements',    [ type => 'popup' ]] },
		{ variable     => [ 'hwconfig',          [ type => 'popup', style => 'width:180px;' ]]  },
		{ variable     => [ 'hwaddress',         [ type => 'string'  ] ]},
		{ variable     => [ 'hwaddresses',       [ type => 'text', rows => '10', cols => '20'  ]]},
		{ variable     => [ 'control_mode',      [ type => 'translatedpopup' ]]  },
	];
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my @rooms  = undef; 
	my $role   = main::GetSessionValue('role');
	my @head   = ();
	push @head, { name => 'room',    attributes => [ label => main::__('room'),    help => main::__('Push the button to edit the room') ] },
               { name => 'network', attributes => [ label => main::__('network')] },
               { name => 'add',     attributes => [ label => main::__('add'),     help => main::__('Push the button to add a new workstation to the room') ] },
               { name => 'DHCP',    attributes => [ label => 'DHCP',              help => main::__('Push the button to set special DHCP parameter for the room.') ] },
               { name => 'hwconfig',attributes => [ label => main::__('hwconfig'),help => main::__('Select the standard workstation configuration for the room.') ] },
               { name => 'control', attributes => [ label => main::__('control'), help => main::__('Push the button to edit control method for the room.') ] };
        push @head, { name => 'delete',  attributes => [ label => main::__('delete'),  help => main::__('Push the button to delete room with all workstations.') ] };
	if( main::GetSessionValue('role') eq 'teachers' )
	{
		@rooms = $this->get_rooms(main::GetSessionValue('dn'));
	}
	else
	{
		@rooms = $this->get_rooms('all');
	}
	my @lines       = ('rooms');
	my @dns         = ();
	my %tmp		= ();

	push @lines, { head => \@head };

	foreach my $room ( @rooms )
	{
		my $dn       = $room->[0];
		my $desc     = $room->[1];
		my @hwconf   = @{$this->get_HW_configurations(1)};
		my $network  = $this->get_attribute($dn,"dhcprange").'/'.$this->get_attribute($dn,"dhcpnetmask");
		my ( $control, $controller, $controllers )  = $this->get_room_control_state($dn);
		my $hw       = $this->get_config_value($dn,'HW') || '-';
		push @hwconf,  [ '---DEFAULTS---' ], [ $hw ];
		if( $desc =~ /^ANON_DHCP/ )
		{
			my $result = $this->{LDAP}->search( base => $this->{SYSCONFIG}->{DHCP_BASE}, filter => 'cn=Pool1' );
			if(defined $result && $result->count() > 0)
			{
		    		$dn = $result->entry(0)->dn;
				push @lines, { line => [ $dn , { description => $desc } , {network => $network}, {ANON_DHCP=>main::__('add')}, { DHCP=>'DHCP'} ]}; 
			}
		}
		elsif( $desc =~ /^SERVER_NET/ )
		{
			push @lines, { line => [ $dn , {room => $desc } , {network => $network}, {addNewPC=>main::__('add')}, { DHCP=>'DHCP'} ]}; 
		}
		else
		{
			my @line = ( $dn );
			push @line, {room => $desc }, {network => $network}, {addNewPC=>main::__('add')}, { DHCP=>'DHCP'},
				    { hwconfig => \@hwconf }, {control => main::__($control)} ;
			push @line, { del_room => main::__('delete') };
			push @lines, { line => \@line }; 
		}
	}
	if( scalar(@lines) > 19 )
	{
		return 
		[
		   { table  =>  \@lines },
		   { rightaction => "stateOfRooms" },
		   { rightaction => "scanPCs" },
		   { rightaction => "addNewRoom" },
		   { rightaction => "setRooms" }
		];
	}
	elsif( scalar(@lines) > 1 )
	{
		return 
		[
		   { table  =>  \@lines },
		   { action => "stateOfRooms" },
		   { action => "scanPCs" },
		   { action => "addNewRoom" },
		   { action => "setRooms" }
		];
	}
	else
	{
		return 
		[
		   { action => "addNewRoom" }
		];
	}
}

sub stateOfRooms
{
	my $this   = shift;
	my $reply  = shift;
	my @rooms  = undef;
	my $free   = `base64 /srv/www/oss/img/accept.png`;
	my $busy   = `base64 /srv/www/oss/img/delete.png`;
	system("/usr/share/oss/tools/clean-up-sambaUserWorkstations.pl");
	if( main::GetSessionValue('role') eq 'teachers' )
	{
		@rooms = $this->get_rooms(main::GetSessionValue('dn'));
	}
	else
	{
		@rooms = $this->get_rooms('all');
	}
	my @lines       = ('rooms');
	my @dns         = ();
	foreach my $room ( @rooms )
	{
		my $dn    = $room->[0];
		my $desc  = $room->[1];
		my $users = "";

                my $lu = {};
                foreach my $logged_user (@{ $this->get_logged_users($dn) } )
                {
                        $lu->{$logged_user->{host_name}}->{user_cn}   = $logged_user->{user_cn};
                        $lu->{$logged_user->{host_name}}->{user_name} = $logged_user->{user_name};
                }
		foreach my $hostname (sort keys %{$lu} )
		{
			$users .= $hostname.': '.$lu->{$hostname}->{user_cn}.'('.$lu->{$hostname}->{user_name}.')<br>';
		}
		if( $users eq "" )
		{
			push @lines, { line => [ $dn , { description => $desc }, { free_busy => $free } ] };
		}
		else
		{
			push @lines, { line => [ $dn , { description => $desc }, { free_busy => $busy }, { network => $users } ] };
		}
	}
	return [
		{ table       => \@lines  }
	];
}

sub DHCP
{
	my $this 	= shift;
	my $reply	= shift;
	my $ENTRY	= $this->get_entry($reply->{line});
	my $st		= $ENTRY->{description}->[0] || $ENTRY->{cn}->[0];
	my @r		= ( { subtitle => 'DHCP '.$st }, { NOTICE => main::__('Please be carefull! Bad entries can destroy the DHCP configuration.') });
	my @options	= ( 'options'    , { head => [ 'DHCP-Option', 'Value' , 'Delete' ] } );
	my @statements	= ( 'statements' , { head => [ 'DHCP-Statement', 'Value', 'Delete' ] });
	if( defined $ENTRY->{dhcprange} && $ENTRY->{cn}->[0] =~ /^Pool/ ){
		push @r, { dhcprange => $ENTRY->{dhcprange}->[0] };
	}
	if( defined $ENTRY->{dhcpoption} )
	{
		my $i = 0;
		foreach(@{$ENTRY->{dhcpoption}})
		{
			my ( $o, $v ) = split / /,$_,2;
			push @options , { line => [ $i , { option => $o }, { value => $v } , { delete => 0 } ] }; 
			$i++;
		}
		push @r, { label => main::__('DHCP-Options') };
		push @r, { table => \@options };
	}
	if( defined $ENTRY->{dhcpstatements} )
	{
		my $i = 0;
		foreach(@{$ENTRY->{dhcpstatements}})
		{
			my ( $o, $v ) = split / /,$_,2;
			push @statements , { line => [ $i , { statements => $o } , { value => $v }, { delete => 0 } ] }; 
			$i++;
		}
		push @r, { label => main::__('DHCP-Statements') };
		push @r, { table => \@statements };
	}
	push @r, { label => main::__('Add New DHCP-Option') };
	push @r, { table => [ 'newOption' , { head => [ 'DHCP-Options', 'Value' ] }, { line => [ 0, { dhcpOptions => \@DHCPOptions }, { value => '' } ] } ] };
	push @r, { label => main::__('Add New DHCP-Statement') };
	push @r, { table => [ 'newStatement' , { head => [ 'DHCP-Statement', 'Value' ] }, { line => [ 0, { dhcpStatements => \@DHCPStatements }, { value => '' } ] } ] };
	push @r, { dn    => $reply->{line} };
	push @r, { action => 'cancel' };
	push @r, { name => 'action', value => 'setDHCP', attributes => [ label => 'apply'] };
	return \@r;

}

sub setDHCP
{
	my $this 	= shift;
	my $reply	= shift;
	my @options     = ();
	my @statements  = ();
	if( defined $reply->{options} )
	{
		foreach my $i ( keys %{$reply->{options}} )
		{
			next if ( $reply->{options}->{$i}->{delete} );
			if( length( $reply->{options}->{$i}->{value} ) )
			{
				push @options, $reply->{options}->{$i}->{option}.' '.$reply->{options}->{$i}->{value};
			}
			else
			{
				push @options, $reply->{options}->{$i}->{option};
			}
		}
	}
	if( defined $reply->{statements} )
	{
		foreach my $i ( keys %{$reply->{statements}} )
		{
			next if ( $reply->{statements}->{$i}->{delete} );
			if( length( $reply->{statements}->{$i}->{value} ) )
			{
				push @statements, $reply->{statements}->{$i}->{statements}.' '.$reply->{statements}->{$i}->{value};
			}
			else
			{
				push @statements, $reply->{statements}->{$i}->{statements};
			}
		}
	}
	if( $reply->{newOption}->{0}->{dhcpOptions} )
	{
		push @options, $reply->{newOption}->{0}->{dhcpOptions}.' '.$reply->{newOption}->{0}->{value};
	}
	if( $reply->{newStatement}->{0}->{dhcpStatements} )
	{
		push @statements, $reply->{newStatement}->{0}->{dhcpStatements}.' '.$reply->{newStatement}->{0}->{value};
	}
	$this->{LDAP}->modify( $reply->{dn} , delete => { dhcpStatements => [] } );
	$this->{LDAP}->modify( $reply->{dn} , delete => { dhcpOption => [] } );
	$this->{LDAP}->modify( $reply->{dn} , add => { dhcpStatements => \@statements } ) if( scalar @statements );
	$this->{LDAP}->modify( $reply->{dn} , add => { dhcpOption => \@options } )        if( scalar @options );
	if( defined $reply->{dhcprange} )
	{
		$this->{LDAP}->modify( $reply->{dn} , replace => { dhcprange => $reply->{dhcprange} } );
	}
	$reply->{dn} =~ /cn=config1,cn=(.*),ou=DHCP/;
        my $server = ($1 eq 'schooladmin') ? undef : $1;
        $this->rc("dhcpd","restart",$server);
	$this->DHCP( { line => $reply->{dn} } );
}

sub realy_delete
{
	my $this 	= shift;
	my $reply	= shift;
	$reply->{realy_delete} = 1;
	$this->del_room($reply);
}

sub del_room
{
	my $this 	= shift;
	my $reply	= shift;
	my $dn          = $reply->{line} || $reply->{dn};
	my $description = $this->get_attribute($dn,'description');
	my $ws		= $this->get_workstations_of_room($dn);

	if( scalar(@{$ws}) && ! $reply->{realy_delete} )
	{
		return [
			{ notranslate_label => $description },
			{ label  => 'There are workstations in this room. These will be deleted too. Do you realy want to delete it?' },
			{ dn     => $dn },
			{ action => 'cancel' },
			{ name   => 'action' ,  value => 'realy_delete', attributes => [ label => 'delete'] }
		];
	}

	$this->delete_room( $dn );
	$this->default();
}

sub setRooms
{
	my $this 	= shift;
	my $reply	= shift;

	foreach my $dn (keys %{$reply->{rooms}})
	{
		if( $reply->{rooms}->{$dn}->{hwconfig} )
		{
			my @values = $this->get_attribute($dn,'configurationValue');
			if( ! scalar @values )
			{
				$this->{LDAP}->modify( $dn, add => { configurationValue => 'HW='.$reply->{rooms}->{$dn}->{hwconfig} } );
			}
			else
			{
				if( grep(/^HW=/,@values) )
				{
					grep {s/^HW=.*/HW=$reply->{rooms}->{$dn}->{hwconfig}/} @values;
				}
				else
				{
					push @values, 'HW='.$reply->{rooms}->{$dn}->{hwconfig};
				}
				$this->{LDAP}->modify( $dn, replace => { configurationValue => \@values });
			}
		}
	}
	$this->default;

}

sub room
{
	my $this 	= shift;
	my $reply	= shift;
	my $rdn	        = $reply->{line} || $reply->{rdn};
	my %hosts	= ();
	my @lines	= ('ws');
	my $description = $this->get_attribute($rdn,'description');

	foreach my $dn ( @{$this->get_workstations_of_room($rdn)} )
	{
		my $hostname = $this->get_attribute($dn,'cn');
		next if( $hostname =~ /-wlan$/);
		my $hwaddress= $this->get_attribute($dn,'dhcpHWAddress');
		my $ipaddr   = $this->get_attribute($dn,'dhcpStatements');
		$hwaddress =~ s/ethernet //i;
		$ipaddr =~ s/fixed-address //i;
		if( $hostname )
		{
		   $hosts{$hostname}->{hwaddress} = $hwaddress;
		   $hosts{$hostname}->{ipaddr}    = $ipaddr;
		   $hosts{$hostname}->{dn}        = $dn;
		}
	}
	foreach my $hostname (sort keys(%hosts))
        {
		my $hw       = $this->get_config_value($hosts{$hostname}->{dn},'HW') || '-';
		my @hwconf   = @{$this->get_HW_configurations(1)};
		push @hwconf,  [ '---DEFAULTS---' ], [ $hw ] ;
		my $master   = ( $this->get_config_value($hosts{$hostname}->{dn},'MASTER')     eq "yes" ) ? 1 : 0;
		if( $this->{RADIUS} )
		{
			my $wlan     = ( $this->get_config_value($hosts{$hostname}->{dn},'WLANACCESS') eq "yes" ) ? 1 : 0;
			push @lines, { line => [ $hosts{$hostname}->{dn}, 
						{ editPC      => $hostname },
						{ hwaddress   => $hosts{$hostname}->{hwaddress} }, 
						{ hwconfig    => \@hwconf }, 
						{ DHCP	      => 'DHCP' },
						{ master      => $master }, 
						{ wlanaccess  => $wlan },
						{ renamePC    => main::__('renamePC')},
						{ delete      => 0 }
				  ]};
		}
		else
		{
			push @lines, { line => [ $hosts{$hostname}->{dn}, 
						{ editPC      => $hostname }, 
						{ hwaddress   => $hosts{$hostname}->{hwaddress} }, 
						{ hwconfig    => \@hwconf }, 
						{ DHCP	      => 'DHCP' },
						{ master      => $master },
						{ renamePC    => main::__('renamePC')},
						{ delete      => 0 } 
				  ]};
		}
	}

	my @ret;
	push @ret, @{$reply->{msg}} if( exists($reply->{msg}) );
	push @ret, { subtitle => $description };
	push @ret, { table    =>  \@lines };
	push @ret, { dn       => $reply->{line} };
	push @ret, { NOTICE   => $reply->{warning} } if ( defined $reply->{warning} );
	push @ret, { action   => "cancel" };
	push @ret, { action   => "addNewPC" };
	push @ret, { action   => "roomType" };
	push @ret, { action   => "roomGeometry" };
	push @ret, { name => 'action' , value  => 'modifyRoom', attributes => [ label => 'apply' ]  };
	return \@ret;
}

sub editPC
{
	my $this   = shift;
	my $reply  = shift;
	my $dn 	   = $reply->{line} || $reply->{dn};
	my $hw     = $this->get_config_value($dn,'HW');
	my $cn     = get_name_of_dn($dn);
	my $wlanDN = $this->get_host($cn.'-wlan');
        my $wlanmac= $reply->{wlanmac} || '';
	   $wlanmac=~ s/-/:/g;
	my @ret    = ( { subtitle => get_name_of_dn($dn) } );
        if( defined $wlanDN )
	{
	    my $mac     = $this->get_attribute($wlanDN,'dhcpHWAddress');
	    $mac =~ s/ethernet //;
	    if( $wlanmac and ( $mac ne $wlanmac ) )
	    {
	        if( check_mac($wlanmac) )
		{#Additional MAC address was changed.
			$this->set_attribute($wlanDN,'dhcpHWAddress',"ethernet $wlanmac");
		}
		else
		{
			$wlanmac = "Mac address is invalid:".$wlanmac;
		}
	    }
	    else
	    {
	    	$wlanmac = $mac;
	    }
	}
	elsif( check_mac($wlanmac) )
	{#Additional MAC address was created.
		my ($name,$ip) = $this->get_next_free_pc(get_parent_dn($dn));
		if( !defined $ip )
		{
			push @ret, { WARNING => 'There is no more free IP-address in this room' };
		}
		else
		{
			$cn=$cn.'-wlan.'.$this->{SYSCONFIG}->{SCHOOL_DOMAIN};
			$this->add_host($cn,$ip,$wlanmac,'wlanclone',0,1);
        		$this->rc("named","restart");
        		$this->rc("dhcpd","restart");
		}
	}
        my %parts  = ();
	my %os     = ();
	my %join   = ();
	my $result = $this->get_attributes( 'configurationKey='.$hw.','.$this->{SYSCONFIG}->{COMPUTERS_BASE},
		                                            ['configurationvalue','description']);
        foreach ( @{$result->{'configurationvalue'}} )
        {
               if( /PART_(.*)_DESC=(.*)/)
               {
                  $parts{$1} = $2;
               }
               if( /PART_(.*)_OS=(.*)/)
               {
                  $os{$1} = $2;
               }
               if( /PART_(.*)_JOIN=(.*)/)
               {
                  $join{$1} = $2;
               }
        }
	$this->set_config_value($dn,'SERIALNUMBER',$reply->{serial})     if( defined $reply->{serial} );
	$this->set_config_value($dn,'INVENTARNUMBER',$reply->{inventar}) if( defined $reply->{inventar} );
	$this->set_config_value($dn,'LOCALITY',$reply->{locality})       if( defined $reply->{locality} );
	push @ret, { serial   => $this->get_config_value($dn,'SERIALNUMBER')   };
	push @ret, { inventar => $this->get_config_value($dn,'INVENTARNUMBER') };
	push @ret, { locality => $this->get_config_value($dn,'LOCALITY') };
	if( $this->get_config_value($dn,'MASTER') ne "yes" )
	{# Do not set separate values for master!
		foreach my $p ( sort keys %parts  )
		{
			next if ( $join{$p} ne "Domain" );
			$this->set_config_value($dn,'PART_'.$p.'_ProductID',$reply->{"regcode-$p"}) if( $reply->{"regcode-$p"} );
			push @ret, { name  => "regcode-$p", 
				     value => $this->get_config_value($dn,'PART_'.$p.'_ProductID'),
				     attributes => [ type => "string", label => $os{$p}.' '.$parts{$p}." ProductID" ] };
		}
	}
	push @ret, { wlanmac=> $wlanmac };
	push @ret, { rdn    => get_parent_dn($dn) };
	push @ret, { dn     => $dn };
	push @ret, { action => 'cancel' };
	push @ret, { name   => 'action', value => 'room',   attributes => [ label => 'back' ] };
	push @ret, { name   => 'action', value => 'editPC', attributes => [ label => 'apply' ] };
	if( -e "/etc/sysconfig/OSS_MDM" and $this->get_config_value($dn,'WLANACCESS') eq "yes" )
	{#Enrollment
	    push @ret, { action => 'addEnrollment' };
	}
	return \@ret;
}

sub addEnrollment
{
	my $this 	= shift;
	my $reply	= shift;
	my $dn		= $reply->{line} || $reply->{dn};
	my @ret		= ( { subtitle => main::__("Enrollment for: ").get_name_of_dn($dn) } );
        push    @INC,"/usr/share/lmd/helper/";
        require OSSMDM;
        my $mdm = new OSSMDM;


	if( defined $reply->{OS} )
	{
	    	my $cn = $this->get_attribute($dn,'cn');
		my $HW = uc($this->get_attribute($dn,'dhcpHWAddress'));
		$HW =~ s/ethernet //i;
	    	$mdm->add_enrollment(0,$cn,$reply->{policy},$reply->{OS},$reply->{ownership},$HW);
		$this->editPC({ dn => $dn });
	}


	my $pol		= $reply->{policy} || $this->get_computer_config_value('MDM_Policy',$reply->{hwconfig});
	$pol = 0 if(! defined $pol);
	my $OS		= $reply->{OS} || $this->get_computer_config_value('MDM_OS',$reply->{hwconfig});
	my $own		= $reply->{owndership} || $this->get_computer_config_value('MDM_Ownership',$reply->{hwconfig});
	push @ret, { OS        => [ 'IOS','ANDROID', '---DEFAULTS---',$OS ] };
	push @ret, { ownership => [ 'COD','BYOD','UNKNOWN', '---DEFAULTS---' ,$own] };
	push @ret, { name      => 'policy', value => $mdm->get_policies($pol), attributes => [ type  => 'popup' ] };
	push @ret, { rdn    => get_parent_dn($dn) };
	push @ret, { dn     => $dn };
	push @ret, { action => 'cancel' };
	push @ret, { name   => 'action', value => 'addEnrollment', attributes => [ label => 'apply' ] };
	return \@ret;
}

sub modifyRoom
{
	my $this 	= shift;
	my $reply	= shift;
	$reply->{line}  = $reply->{dn};
	my $ERROR	= undef;
	my $deleted	= 0;
	my %swinstall;

	foreach my $dn ( keys %{$reply->{ws}} )
	{
		if( $reply->{ws}->{$dn}->{delete} )
		{
			$deleted = 1;
			$this->delete_host($dn);
			next;
		}
		my $master = $reply->{ws}->{$dn}->{master}     ? 'yes' : 'no';
		if( $master eq "yes" )
		{
			my $masters = $this->get_masters_of_hwconf($reply->{ws}->{$dn}->{hwconfig},$dn);
			if( scalar @$masters )
			{
				$reply->{warning} .= main::__("There was other master defined for this hardware configuration: ");
				foreach ( @$masters )
				{
					$reply->{warning} .= get_name_of_dn($_);
					$this->set_config_value($_,'MASTER','no');
				}
				$reply->{warning} .= '<br>';
			}
		}
		$this->set_config_value($dn,'MASTER',$master);
		if( $this->{RADIUS} )
		{
			my $wlan   = $reply->{ws}->{$dn}->{wlanaccess} ? 'yes' : 'no';
			$this->set_config_value($dn,'WLANACCESS',$wlan);
		}

		my $old_hwconfig = $this->get_config_value(  $dn, 'HW');
		$this->set_config_value($dn,'HW',$reply->{ws}->{$dn}->{hwconfig});
		my $new_hw_dn = 'configurationKey='.$reply->{ws}->{$dn}->{hwconfig}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
		my $softwares = $this->get_config_values( $new_hw_dn, 'SWPackage', 'ARRAY' );
		if( (ref($softwares) eq 'ARRAY') and ($old_hwconfig ne $reply->{ws}->{$dn}->{hwconfig}) ){
			$swinstall{$dn}->{old_hw} = $old_hwconfig;
			$swinstall{$dn}->{new_hw} = $reply->{ws}->{$dn}->{hwconfig};
		}

		my $hw = $reply->{ws}->{$dn}->{hwaddress};
		$hw =~ s/-/:/g;
		if( check_mac( $hw ) )
		{
			my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
					   filter => "(&(!(cn=".get_name_of_dn($dn)."))(dhcpHWAddress=ethernet $hw))",
					   attrs  => ['cn']
					 );
			if($result->count() > 0)
			{
		    		my $cn = $result->entry(0)->get_value('cn');
				$ERROR .= main::__("The hardware address already exists.")."$cn => $hw<br>";
			}
			else
			{
				$this->set_attribute($dn,'dhcpHWAddress','ethernet '.$hw);
			}
		}
		else
		{
			$ERROR .= get_name_of_dn($dn).': '.main::__('The hardware address is invalid').': '.$hw.'<br>';
		}
		
	}
        $reply->{dn} =~ /cn=config1,cn=(.*),ou=DHCP/;
        my $server = ($1 eq 'schooladmin') ? undef : $1;
        if( $deleted )
        {
                $this->rc("named","restart",$server);
        	$this->rc("named","restart") if( defined $server );
        }
        $this->rc("dhcpd","restart",$server);
	if( $ERROR )
	{
           return {
                TYPE    => 'NOTICE',
                CODE    => 'ERROR_BY_MODIFYING_ROOM',
                NOTRANSLATEMESSAGE => $ERROR
           }
	}

	if( keys(%swinstall) ){
		$this->set_sofware(\%swinstall, $reply->{dn});
	}else{
		$this->room($reply);
	}
}

sub roomType
{
	my $this 	= shift;
	my $reply	= shift;
	my $roomtype    = $this->get_vendor_object($reply->{dn},'EXTIS','ROOMTYPE');
	my ( $t, $r, $c ) = ( 'A', '' ,'' );
	if( defined $roomtype->[0] )
	{
	    ( $t, $r, $c ) = split /:/, $roomtype->[0];
	}

	return
	[
		{ subtitle => 'Choose Room Type' },
		{ dn       => $reply->{dn} },
		#TODO We have to discuss if we need it
		#{ name     => 'type' ,  value  => [ 'A', 'B', 'C', '---DEFAULTS---', $t ] , attributes => [ type => 'popup' ] },
		{ name     => 'type' ,  value  => 'A', attributes => [ type => 'hidden' ] },
		{ Columns  => $c },
		{ Rows	   => $r },
		{ action   => "cancel" },
		{ name => 'action' , value  => 'setRoomType', attributes => [ label => 'apply' ]  }
	];
}

sub setRoomType
{
	my $this 	= shift;
	my $reply	= shift;
	$this->create_vendor_object($reply->{dn},'EXTIS','ROOMTYPE',$reply->{type}.':'.$reply->{Rows}.':'.$reply->{Columns});
	$reply->{line} = $reply->{dn};
	$this->room($reply);
}

sub roomGeometry
{
	my $this 	= shift;
	my $reply	= shift;
	my @lines	= ('ws');
	my $roomtype    = $this->get_vendor_object($reply->{dn},'EXTIS','ROOMTYPE');

        if( !defined $roomtype->[0] )
	{
		return
		[
			{ subtitle => 'Choose Room Type' },
			{ dn       => $reply->{dn} },
			#TODO We have to discuss if we need it
			#{ name     => 'type' ,  value  => [ 'A', 'B', 'C', '---DEFAULTS---', $t ] , attributes => [ type => 'popup' ] },
			{ name     => 'type' ,  value  => 'A', attributes => [ type => 'hidden' ] },
			{ rows	   => '' },
			{ columns  => '' },
	        	{ action   => "cancel" },
			{ name => 'action' , value  => 'setRoomType', attributes => [ label => 'apply' ]  }
		 ];
	}

	foreach my $dn ( keys %{$reply->{ws}} )
	{
		my $x = -1;
		my $y = -1 ;
		my $xy = $this->get_vendor_object($dn,'EXTIS','COORDINATES');
		if( defined $xy->[0] )
		{
			( $x,$y ) = split /,/ , $xy->[0];
		}
		push @lines, { line => [ $dn , { x => $x } , { y => $y } ] };
	}
	if( scalar(@lines) > 1 )
	{
		return
		[
			{ subtitle => 'roomGeometry' },
			{ table    =>  \@lines },
			{ dn       => $reply->{dn} },
			{ roomtype => $roomtype->[0] },
			{ action   => "cancel" },
			{ name => 'action' , value  => 'setRoomGeometry', attributes => [ label => 'apply' ]  }
		];	
	}
	else
	{
		return
		[
			{ subtitle => 'roomGeometry' },
			{ dn       => $reply->{dn} },
			{ roomtype => $roomtype->[0] },
			{ action   => "cancel" },
			{ name => 'action' , value  => 'setRoomGeometry', attributes => [ label => 'apply' ]  }
		];	
	}
}

sub setRoomGeometry
{
	my $this 	= shift;
	my $reply	= shift;
	$reply->{line}  = $reply->{dn};

	foreach my $dn ( keys %{$reply->{ws}} )
	{
		my $xy = $reply->{ws}->{$dn}->{x}.','.$reply->{ws}->{$dn}->{y};
		$this->create_vendor_object($dn,'EXTIS','COORDINATES',$xy);
	}
	$this->create_vendor_object($reply->{dn},'EXTIS','ROOMTYPE',$reply->{roomtype});
	$this->room($reply);
}

sub addNewRoom
{
	my $this 	= shift;
	my $reply	= shift;
	my $free	= $this->get_free_rooms();
	my $hwconf      = $this->get_HW_configurations(1);
	my %tmp		= ();
	my @freerooms   = ();

	foreach my $dn (keys %{$free})
	{
		$tmp{$free->{$dn}->{"dhcprange"}->[0].'/'.$free->{$dn}->{'dhcpnetmask'}->[0]} = $dn;
	}
	foreach my $key ( sort keys %tmp )
	{
	       push @freerooms, [ $tmp{$key}, $key ];
	}
	push @freerooms, '---DEFAULTS---', $tmp{( sort keys %tmp )[0]};
	return [ 
		{ subtitle  => 'Add New Room'}, 
		{ new_room  => '' }, 
		{ freerooms => \@freerooms }, 
		{ hwconfig  => $hwconf },
		{ action    => 'cancel' },
		{ action    => 'addRoom' }
	];
}

sub addRoom
{
	my $this 	= shift;
	my $reply	= shift;
	my $dn		= $reply->{freerooms};
	my $new_room	= $reply->{new_room};
	if( length($new_room) > 10 ) 
	{
           return {
                TYPE    => 'ERROR',
                CODE    => 'NAME_TOO_LONG',
                MESSAGE => 'Room Name too Long'
           }
	}
	if( $new_room =~ /[^a-zA-Z0-9-]+/  || length($new_room)<2 ) {
           return {
                TYPE    => 'ERROR',
                CODE    => 'INVALID_NAME',
                MESSAGE => 'Room Name contains invalid characters or is too short'
           }
	}
	my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
					    filter => "(description=$new_room)",
				            attrs  => ['cn']
				 );
	if($result->count() > 0)
	{
	    return { TYPE => 'ERROR' ,
		     CODE => 'ROOM_ALREADY_EXISTS',
		     MESSAGE => "This room already exists."
	           };
	}
	if( ! $this->add_room($dn,$new_room,$reply->{hwconfig}) )
	{
           return {
                TYPE    => 'ERROR',
                CODE    => $this->{ERROR}->{code},
                MESSAGE => $this->{ERROR}->{text}
           }
	}
	$this->default();
}

sub control
{
	my $this 	= shift;
	my $reply	= shift;
	my @teachers    = ();
	foreach my $i ( sort @{$this->get_school_users('teachers')} )
	{
		push @teachers, [ $i ,  $this->get_attribute($i,'uid')." ".$this->get_attribute($i,'cn')];  
	}
	my $description = $this->get_attribute($reply->{line},'description');
	my ( $control, $controller, $controllers )  = $this->get_room_control_state($reply->{line});
	my $cont = $this->get_attribute($controller,'uid')." ".$this->get_attribute($controller,'cn');
	push @teachers, '---DEFAULTS---', @{$controllers};
	return 
	[
	    { notranslate_subtitle      => $description }, 
	    { control_mode  => [ 'in_room_control' , 'no_control', 'all_teacher_control' ,'teacher_control', '---DEFAULTS---', $control ] },
	    { label         => 'Choose the teachers who can control this Room' },    
	    { teachers      => \@teachers },
	    { controller    => $cont },
	    { set_free      => 0 },
	    { dn            => $reply->{line} },
	    { name => 'action' , value => "cancel",     attributes => [ label => 'back' ] },
	    { name => 'action' , value => "setControl", attributes => [ label => 'apply' ]  }
	];
}

sub setControl
{
	my $this 	= shift;
	my $reply	= shift;
	my $Entry	= $this->get_entry($reply->{dn},1);
	my $controller	= undef;
	$reply->{line}  = $reply->{dn};

	#first we clean the corresponding configurationValues
	foreach my $cV ( $Entry->get_value('configurationValue'))
	{
	   if( $cV =~ /^NO_CONTROL|^MAY_CONTROL=/ )
	   {
	       $Entry->delete( configurationValue=> [ $cV ]);
	   }
	   elsif (  $cV =~ /^CONTROLLED_BY=.*/i )
	   {
	   	$controller = $cV;
	   }
	}
	if( $Entry->exists( 'writerdn' ) )
	{
		$Entry->delete( writerdn => [] );
	}
	# now we set the new controll status
	if( $reply->{control_mode} eq 'all_teacher_control' )
	{
	    $Entry->add( configurationValue=>'MAY_CONTROL=@teachers' );
	}
	elsif( $reply->{control_mode}  eq 'no_control' )
	{
	    $Entry->add( configurationValue=>'NO_CONTROL' );
	}
	elsif( $reply->{control_mode} eq 'teacher_control' )
	{
	    foreach my $dn ( split /\n/, $reply->{teachers} )
	    {
	        $Entry->add( configurationValue=>'MAY_CONTROL='.$dn );
		$Entry->add( writerdn=>$dn );
	    }
	}
	if( $controller && ( $reply->{control_mode}  =~ /^no_control|in_room_control$/ ||  $reply->{set_free}) )
	{
		$Entry->delete( configurationValue=> [ $controller ]);
	}
	$Entry->update($this->{LDAP});
	$this->control($reply);
}

sub addNewPC
{
	my $this 	= shift;
	my $reply	= shift;
	my $room	= $reply->{line} || $reply->{dn};
        if( $room !~ /^cn=Room/ )
	{
		$room = $this->get_room_by_name($room);
	}
	my $ip		= main::GetSessionValue('ip');
	my $block       = new Net::Netmask($this->{SYSCONFIG}->{SCHOOL_SERVER_NET});
	my $new_ip      = '';
	my $hostname    = '';
	my $dhcpHWAddress = '';

	if(  ! $block->match($ip) ) {
	    my $tmp = `/sbin/arp -a $ip`;
	    $tmp =~ /(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)/;
	    $dhcpHWAddress = $1;
	}

	#Get the room
	my @hosts      = $this->get_free_pcs_of_room($room);
        if ( ! scalar @hosts )
        {
                return {
                        TYPE => 'ERROR' ,
                        CODE => 'NO_MORE_FREE_ADDRESS_IN_ROOM',
                        MESSAGE => 'There are no more free addresses in this room.'
                };
        }
        my   $hw       = $this->get_config_value($room,'HW') || '-';
	my   @hwconf   = @{$this->get_HW_configurations(1)};
	push @hwconf,  [ '---DEFAULTS---' ], [ $hw ];
	push @hosts, '---DEFAULTS---', $hosts[0];
	if( $this->{RADIUS} )
	{
		return [ 
			{ subtitle     => 'Add New PC'}, 
			{ workstations => \@hosts   },
			{ hwaddresses  => $dhcpHWAddress },
			{ hwconfig     => \@hwconf },
			{ master       => 0 },
			{ wlanaccess   => 0 },
			{ other_name   => '' },
			{ dn           => $room },
			{ action       => 'cancel' },
			{ action       => 'addPC' }
		];
	}
	else
	{
		return [ 
			{ subtitle     => 'Add New PC'}, 
			{ workstations => \@hosts   },
			{ hwaddresses  => $dhcpHWAddress },
			{ hwconfig     => \@hwconf },
			{ master       => 0 },
			{ other_name   => '' },
			{ dn           => $room },
			{ action       => 'cancel' },
			{ action       => 'addPC' }
		];
	}
}

sub addPC
{
	my $this 	= shift;
	my $reply	= shift;
	my @HWS         = split /\n/, $reply->{hwaddresses};
	my @hosts       = @{thaw(decode_base64(main::GetSessionDatas('hosts')))};
	my $result	= '';
	my $host	= shift @hosts;
	my $HOSTDN	= undef;
	my @HOSTDNs	= ();
	my $domain	= $this->{SYSCONFIG}->{SCHOOL_DOMAIN};

	if( scalar( @HWS ) > 1 && $reply->{other_name} ne '' )
	{
	    return { TYPE    => 'ERROR' ,
	    	     CODE    => 'TO_MANY_MAC_ADDRESS',
		     MESSAGE => "If registering a computer with alternete name, you may only use one hardware address."
	    };
	}
	# check the alternate name
	if( $reply->{other_name} ne '' )
	{
		if( $reply->{other_name} =~ /[^a-zA-Z0-9-]+/ ||
		    $reply->{other_name} !~ /^[a-zA-Z]/      ||
		    $reply->{other_name} =~ /-$/             ||
		    $reply->{other_name} =~ /-wlan$/         ||
		    length($reply->{other_name})<2           ||
		    length($reply->{other_name}) > 15  )
		{
		    return { TYPE    => 'ERROR' ,
			     CODE    => 'INVALID_HOST_NAME',
			     MESSAGE => "The alternate host name is invalid.<br>This may contains only ASCII-7 letters numbers and '-'.<br>The alternate name must not and with '-wlan' or '-'.<br>The alternate name must start with a letter."
	                   };
		}
		$result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DNS_BASE},
				   filter => 'relativeDomainName='.$reply->{other_name},
				   attrs  => ['aRecord']
				 );
		if($result->count() > 0)
		{
		    return { TYPE => 'ERROR' ,
			     CODE => 'HOST_ALREADY_EXISTS',
			     MESSAGE => "The alternate host name already exists.",
			     NOTRANSLATEMESSAGE1 => "IP: ".$result->entry(0)->get_value('aRecord')
	                   };
		}
                if(!$this->is_unique($reply->{other_name},'uid'))
                {
                    return { TYPE => 'ERROR' ,
                             CODE => 'NAME_ALREADY_EXISTS',
                             MESSAGE => "The alternate host name will be used allready as userid."
                           };
                }

	}

	#seeking $hosts to the choosen host
	if($reply->{workstations} ne '')
	{
	   while( $reply->{workstations} ne $host && $host ne '' )
	   {
	      $host = shift @hosts;
	   }
	}

	#If the selected hw config is MDM then wlanaccess must be on too
	if($this->get_computer_config_value('WSType',$reply->{hwconfig}) eq 'MobileDevice' ) {
		$reply->{mdm}        = 1;
		$reply->{wlanaccess} = 1;
	}

	#Now we do our work
	foreach my $hw (@HWS)
	{
		my ( $mac, $inventar, $serial ) = split /;/,$hw;
		$hw = uc($mac);
		$hw =~ s/-/:/g;
		if( !check_mac($hw) )
		{
		    return { TYPE => 'ERROR' ,
			     CODE => 'HW_ADDRESS_INVALID',
			     MESSAGE => "The hardware address is invalid",
			     MESSAGE1 => $hw,
	                   };
		}
		my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
				   filter => "(dhcpHWAddress=ethernet $hw)",
				   attrs  => ['cn']
				 );
		if($result->count() > 0)
		{
		    my $cn = $result->entry(0)->get_value('cn');
		    return { TYPE => 'ERROR' ,
			     CODE => 'HW_ALREADY_EXISTS',
			     MESSAGE  => "The hardware address already exists.",
			     NOTRANSLATE_MESSAGE1 => "$cn => $hw"
	                   };
		}
		my ( $name,$ip ) = split /:/, $host;
		if( $reply->{other_name} ne '' )
		{
			$name = $reply->{other_name};
		}
		$name = lc($name);
                if( $reply->{master} )
                {
                        my $masters = $this->get_masters_of_hwconf($reply->{hwconfig});
                        if( scalar @$masters )
                        {
                                $reply->{warning} .= main::__("There is other master defined for this hardware configuration: ");
                                foreach ( @$masters )
                                {
                                        $reply->{warning} .= get_name_of_dn($_);
                                }
				$reply->{master} = 0;
				$reply->{warning} .= '<br>';
                        }
                }

		my @dns = $this->add_host($name.'.'.$domain,$ip,$hw,$reply->{hwconfig},$reply->{master},$reply->{wlanaccess});
		$HOSTDN = $dns[$#dns];
		push @HOSTDNs, $HOSTDN;
		if( ! $this->add( {
			     uid          	   => $name,
			     sn			   => $name.' Workstation-User',
			     role         	   => 'workstations',
			     userpassword 	   => $name,
			     sambauserworkstations => $name
			   } ))
		{
			print STDERR $this->{ERROR}->{text}."\n";
		}
		if( ! $this->add( {
			     uid        	   => $name.'$',
			     sn			   => 'Machine account '.$name ,
			     description	   => 'Machine account '.$name ,
			     role         	   => 'machine',
			     userpassword 	   => '{crypt}*'
			   } ) )
		{
			print STDERR $this->{ERROR}->{text}."\n";
		}
                $this->set_config_value($HOSTDN,'SERIALNUMBER',  $serial)   if( defined $serial );
                $this->set_config_value($HOSTDN,'INVENTARNUMBER',$inventar) if( defined $inventar );
		$host = shift @hosts;
	}
        $reply->{dn} =~ /cn=config1,cn=(.*),ou=DHCP/;
        my $server = ($1 eq 'schooladmin') ? undef : $1;
        $this->rc("named","restart",$server);
        $this->rc("named","restart") if( defined $server );
        $this->rc("dhcpd","restart",$server);
        $reply->{line} = $reply->{dn};
	if(exists($reply->{flag}))
	{
		return $HOSTDN;
	}
	else
	{
		if( $reply->{wlanaccess} )
		{
			my $freeze = encode_base64(freeze(\@HOSTDNs),"");
			main::AddSessionDatas($freeze,'HOSTDNs');
			$this->selectWlanUser($reply);
		}
		else
		{
			$this->room($reply);
		}
	}
}

sub scanPCs
{
	my $this   = shift;
	my $reply  = shift;
	my @rooms  = $this->get_rooms('all');
	my %tmp    = ();
	my @hwconf = @{$this->get_HW_configurations(1)};
	my $hw     = $reply->{hwconfig} || "default";
	if( defined $reply->{rooms} ) {
		push @rooms, [ '---DEFAULTS---'], [ $reply->{rooms} ]; 
	}
	if( !$reply->{rooms} || !defined $reply->{continue} )
	{

		return [
				{ subtitle  => 'Scan New PCs'}, 
				{ label     => 'Please select the room and datas to collect' },
				{ name      => 'rooms',     value => \@rooms,   attributes => [ type  => 'popup', focus=>1 ] },
				{ name      => 'bserial',   value => 1,         attributes => [ type  => 'boolean' ] },
				{ name      => 'binventar', value => 1,         attributes => [ type  => 'boolean' ] },
				{ name      => 'bposition', value => 0,         attributes => [ type  => 'boolean' ] },
				{ name      => 'bimaging',  value => 1,         attributes => [ type  => 'boolean', label => 'Start Imaginig' ] },
				{ name      => 'continue',  value => 1,         attributes => [ type  => 'hidden' ] },
				{ name      => 'action',    value => 'scanPCs', attributes => [ label => 'start' ] },
				{ action    => 'cancel' }
		];
	}
	if( defined $reply->{hwconfig} && $reply->{hwconfig} eq 'default' ) {
		$hw = $this->get_config_value($reply->{rooms},'HW')
	}
	push @hwconf,  [ 'default','Room Default' ], [ '---DEFAULTS---' ], [ $hw ];
	my @ret = ();
	my $focus = 0;
	push @ret, { subtitle  => 'Scan New PC'};
	push @ret, { rooms     => \@rooms }; 
	push @ret, { hwconfig  => \@hwconf };
	if( $reply->{hwaddresses} eq '' )
	{
		$focus = 'hwaddresses';
	}
	if( $reply->{bserial} ) {
		if( $reply->{serial} eq '' && !$focus )
		{
			$focus = 'serial';
		}
	}
	if( $reply->{binventar} ) {
		if( $reply->{inventar} eq '' && !$focus )
		{
			$focus = 'inventar';
		}
	}
	if( $reply->{bposition} ) {
		if( $reply->{row} eq '' && !$focus )
		{
			$focus = 'row';
		}
		if( $reply->{column} eq '' && !$focus )
		{
			$focus = 'column';
		}
	}
	if( !$focus )
	{ # We have all the datas
		$reply->{flag} = 1;
		$reply->{dn}   = $reply->{rooms};
		my @hosts      = $this->get_free_pcs_of_room($reply->{rooms});
		$reply->{hwaddresses} =~ /([0-9a-f]{2})[-:]?([0-9a-f]{2})[-:]?([0-9a-f]{2})[-:]?([0-9a-f]{2})[-:]?([0-9a-f]{2})[-:]?([0-9a-f]{2})/i;
		$reply->{hwaddresses} = "$1:$2:$3:$4:$5:$6";
		my $dn         = $this->addPC($reply);
		if( ref $dn eq 'HASH')
		{
			return $dn;
		}
		$this->set_config_value($dn,'SERIALNUMBER',$reply->{serial})     if( defined $reply->{serial} );
		$this->set_config_value($dn,'INVENTARNUMBER',$reply->{inventar}) if( defined $reply->{inventar} );
		$this->create_vendor_object($dn,'EXTIS','COORDINATES', $reply->{row}.','.$reply->{column}) if( $reply->{bposition} );
		if( $reply->{bimaging} )
		{
			system("echo 'workstation $dn\npartitions all\n' | /usr/sbin/oss_restore_workstations.pl");
		}
		$reply->{hwaddresses} = '';
		$focus = 'hwaddresses';
		$reply->{serial}      = '';
		$reply->{inventar}    = '';
		$reply->{row}         = '';
		$reply->{column}      = '';
	}
	if( 'hwaddresses' eq $focus )
	{
		push @ret, { name => 'hwaddresses', value => '', attributes => [ type  => 'string', focus => 1 ] };
	}
	else
	{	
		push @ret, { name => 'hwaddresses', value => $reply->{hwaddresses} || '' , attributes => [ type  => 'string' ] };
	}
	if( $reply->{bserial} ) {
		if( $focus eq 'serial' )
		{
			push @ret, { name => 'serial', value => '', attributes => [ type  => 'string', focus => 1 ] };
		}
		else
		{
			push @ret, { serial => $reply->{serial} || '' };
		}
	}
	if( $reply->{binventar} ) {
		if( $focus eq 'inventar' )
		{
			push @ret, { name => 'inventar', value => '', attributes => [ type  => 'string', focus => 1 ] };
		}
		else
		{
			push @ret, { inventar  => $reply->{inventar} || '' };
		}
	}
	if( $reply->{bposition} ) {
		if( $focus eq 'row' )
		{
			push @ret, { name => 'row', value => '', attributes => [ type  => 'string', focus => 1 ] };
		}
		else
		{
			push @ret, { row       => $reply->{row} || '' };
		}
		if( $focus eq 'column' )
		{
			push @ret, { name => 'column', value => '', attributes => [ type  => 'string', focus => 1 ] };
		}
		else
		{
			push @ret, { column       => $reply->{column} || '' };
		}
	}
	push @ret, { name      => 'bserial',   value => $reply->{bserial},   attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'binventar', value => $reply->{binventar}, attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'bposition', value => $reply->{bposition}, attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'bimaging',  value => $reply->{bimaging},  attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'continue',  value => 1,         attributes => [ type  => 'hidden' ] };
	push @ret, { name      => 'action',    value => 'scanPCs', attributes => [ label => 'continue' ] };
	push @ret, { action    => 'cancel' };
	return \@ret;
}

sub selectWlanUser
{
	my $this  = shift;
	my $reply = shift;
	my $OS    = $reply->{OS} || $this->get_computer_config_value('MDM_OS',$reply->{hwconfig});
	my $own   = $reply->{owndership} || $this->get_computer_config_value('MDM_Ownership',$reply->{hwconfig});
	my $pol   = $reply->{policy} || $this->get_computer_config_value('MDM_Policy',$reply->{hwconfig});
	   $pol   = 0 if(! defined $pol);
	if( $reply->{FILTERED} )
	{
		my $name  = $reply->{cn} || '*';
		my @role  = split /\n/, $reply->{role}  || ();
		my @group = split /\n/, $reply->{workgroup} || ();
		my @class = split /\n/, $reply->{class} || ();
		my $user        = $this->search_users($name,\@class,\@group,\@role);
		my @users	= ();
		foreach my $dn ( sort keys %{$user} )
        	{
                	push @users , [ $dn, $user->{$dn}->{uid}->[0].' '.$user->{$dn}->{cn}->[0].' ('.$user->{$dn}->{description}->[0].')' ];
        	}
		my @ret = ({ label => 'Select the User for this WLAN Device!' } );
		push @ret, { name  => "users", value => \@users, attributes => [ type  => 'list',size=>"10", multiple=>"true" ] };
		#TODO SELECT IT FROM SCHOOLCONFIG
		if( -e "/etc/sysconfig/OSS_MDM" && -e "/usr/share/lmd/helper/OSSMDM.pm" )
		{
		   push    @INC,"/usr/share/lmd/helper/";
		   require OSSMDM;
		   my $mdm = new OSSMDM;
		   push @ret, { label => "Set MDM Parameter" };
		   push @ret, { mdm => $reply->{mdm} || 0 };
		   push @ret, { OS         => [ 'IOS','ANDROID', '---DEFAULTS---',$OS ] };
		   push @ret, { ownership  => [ 'COD','BYOD','UNKNOWN', '---DEFAULTS---' ,$own] };
		   push @ret, { name => 'policy', value => $mdm->get_policies($pol), attributes => [ type  => 'popup' ] };
		}
		push @ret, { name => 'rightaction', value => "selectWlanUser",   attributes => [ label => 'searchAgain' ]  };
		push @ret, { name => 'rightaction', value => "setWlanUser",      attributes => [ label => 'apply' ]  };
		push @ret, { name => 'rightaction', value => "room",             attributes => [ label => 'cancel' ]  };
		return \@ret;
	}
	else
	{
		my ( $roles, $classes, $workgroups ) = $this->get_school_groups_to_search();
		my @ret = ({ label    => 'Search User' } );
		push @ret, { cn          => '*' };
		push @ret, { role        => $roles};
		push @ret, { class       => $classes };
		push @ret, { workgroup   => $workgroups };
		#TODO SELECT IT FROM SCHOOLCONFIG
		if( -e "/etc/sysconfig/OSS_MDM" && -e "/usr/share/lmd/helper/OSSMDM.pm" )
		{
		   push    @INC,"/usr/share/lmd/helper/";
		   require OSSMDM;
		   my $mdm = new OSSMDM;
		   push @ret, { label => "Set MDM Parameter" };
		   push @ret, { mdm => $reply->{mdm} || 0 };
		   push @ret, { OS         => [ 'IOS','ANDROID', '---DEFAULTS---',$OS ] };
		   push @ret, { ownership  => [ 'COD','BYOD','UNKNOWN', '---DEFAULTS---' ,$own] };
		   push @ret, { name => 'policy', value => $mdm->get_policies($pol), attributes => [ type  => 'popup' ] };
		}
		push @ret, { name => 'rightaction', value => "selectWlanUser",   attributes => [ label => 'search' ]  };
		push @ret, { name => 'rightaction', value => "setWlanUser",      attributes => [ label => 'apply' ]  };
		push @ret, { name => 'rightaction', value => "room",             attributes => [ label => 'cancel' ]  };
		push @ret, { name => 'FILTERED',    value => 1,                  attributes => [ type  => 'hidden' ] };
		return \@ret;

	}
}

sub setWlanUser
{
	my $this  = shift;
	my $reply = shift;
	my @users = split /\n/, $reply->{users} || ();
	my $HOSTDN = '';
	foreach my $udn ( @users ) {
		$this->{LDAP}->modify($udn, delete => { rasAccess => 'no' } );
		$this->{LDAP}->modify($udn, delete => { rasAccess => 'all' } );
	        foreach my $hdn ( @{thaw(decode_base64(main::GetSessionDatas('HOSTDNs')))} ) {
			my $HW    = uc($this->get_attribute($hdn,'dhcpHWAddress'));
			$HOSTDN = $hdn;
			$HW =~ s/ethernet //i;
        		$HW =~ s/:/-/g;
			$this->{LDAP}->modify($udn, add    => { rasAccess => $HW } );
		}
	}
	if( $reply->{mdm} )
	{
	    push    @INC,"/usr/share/lmd/helper/";
	    require OSSMDM;
	    my $mdm = new OSSMDM;
	    #TODO IF ownership is BYOD the user can make the installation.
	    foreach my $hdn ( @{thaw(decode_base64(main::GetSessionDatas('HOSTDNs')))} ) {
	    	my $cn = $this->get_attribute($hdn,'cn');
		my $HW = uc($this->get_attribute($hdn,'dhcpHWAddress'));
		$HW =~ s/ethernet //i;
	    	$mdm->add_enrollment(0,$cn,$reply->{policy},$reply->{OS},$reply->{ownership},$HW);
		$HOSTDN = $hdn;
	    }
	}
	$reply->{rdn} = get_parent_dn($HOSTDN);
	$this->room($reply);
}

sub host_exists
{
        my $this = shift;
        my $host = shift;
        my $res = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DNS_BASE},
                                         scope  => 'sub',
                                         filter => "relativeDomainName=$host",
                                         attrs  => [] );
        return $res->count if( !$res->code );
        return 0;

}

sub ip_exists
{
	my $this = shift;
	my $ip   = shift;
	return 1 if($this->get_workstation($ip));
        my $res = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DNS_BASE},
                                         scope  => 'sub',
                                         filter => "ARecord=$ip",
                                         attrs  => [] );
        return $res->count if( !$res->code );
	return 0;

}

sub renamePC
{
	my $this      = shift;
	my $reply     = shift;
	my $dn        = $reply->{line};
	my @room_list = ();

	my $hwaddress = $this->get_attribute($dn,'dhcpHWAddress');
        $hwaddress =~ s/ethernet //i;

#print Dumper($reply)." a change room reply-e\n";
	my $hostname = $this->get_attribute($dn,'cn');
	my $message = sprintf( main::__('To move the workstation "%s"/"%s" into an other room, please select a room from the list below and press the button'), $hostname, $hwaddress ).
			     '<br>'.
			     main::__('If you want to rename the workstation fill the field other name.');
	my @rooms = $this->get_rooms('all');

	push @rooms, [ '---DEFAULTS---' ], [ get_parent_dn($dn) ];

	return [
		{ subtitle   => "$hostname"},
		{ NOTICE     => "$message"},
		{ rooms      => \@rooms },
		{ other_name => '' },
		{ action     => 'cancel'},
		{ name       => 'action', value => 'applyRenamePC', attributes => [ label => 'apply' ] },
		{ dn         => $dn }
	];
}

sub applyRenamePC
{
	my $this  = shift;
	my $reply = shift;
	my $new_host = {};

	#get old_pc informations
	my $old_pc          = $this->get_entry($reply->{dn});
        my $old_pc_bootconf = $this->get_vendor_object($reply->{dn},'EXTIS','BootConfiguration');
	my $hwaddress       = $old_pc->{dhcphwaddress}->[0];
	$hwaddress          =~ s/ethernet //i;
	my $old_hostname    = $old_pc->{cn}->[0];
        my @hosts      = $this->get_free_pcs_of_room($reply->{rooms});
        # Test if there is a free place in room.
	# TODO this is not a problem if new room is old room.
        # In this case the hosts list must contains only the actual host.
        if( !scalar(@hosts) ) {
                return {
                        TYPE    => 'ERROR',
                        CODE => 'NO_MORE_FREE_ADDRESS_IN_ROOM',
                        MESSAGE => 'There are no more free addresses in this room.'
                };
        }
        my $freeze = encode_base64(freeze(\@hosts),"");
        main::AddSessionDatas($freeze,'hosts');
	#delete the old host
	$this->delete_host($reply->{dn});
	$new_host->{flag}        = 1;
	$new_host->{hwaddresses} = $hwaddress;
	$new_host->{dn}          = $reply->{rooms};
	$new_host->{other_name}  = $reply->{other_name};
	my $new_pc_dn  = $this->addPC($new_host);
	if( ref $new_pc_dn eq 'HASH')
	{
		return $new_pc_dn;
	}

	#set new pc BootConfiguration
        if($old_pc_bootconf->[0] ne ''){
                $this->create_vendor_object( $new_pc_dn, 'EXTIS','BootConfiguration', $old_pc_bootconf->[0]);
        }
	$this->{LDAP}->modify( $new_pc_dn , delete => { configurationValue => [] } );
	$this->{LDAP}->modify( $new_pc_dn , add    => { configurationValue => $old_pc->{configurationvalue} } );
	my $new_hostname = $this->get_attribute($new_pc_dn,'cn');

	#set pc_name in the OSSInv_PC and OSSInv_PC_Info tables
	my $sth = $this->{DBH}->prepare("SELECT Id FROM OSSInv_PC WHERE PC_Name=\"$old_hostname\" and MacAddress=\"$hwaddress\"");   $sth->execute;
	my $result = $sth->fetchrow_hashref();
	my $pc_id = $result->{Id};
	$sth = $this->{DBH}->prepare("UPDATE OSSInv_PC SET PC_Name=\'$new_hostname\' WHERE Id=\"$pc_id\";");   $sth->execute;

	$sth = $this->{DBH}->prepare("SELECT Id, PC_Name, Info_Category_Id, Value FROM OSSInv_PC_Info WHERE PC_Name=\'$old_hostname\'");   $sth->execute;
	my $pc_info = $sth -> fetchall_hashref( 'Id' );
	foreach my $info_id (keys %{$pc_info}){
		$sth = $this->{DBH}->prepare("UPDATE OSSInv_PC_Info SET PC_Name=\'$new_hostname\' WHERE Id=\"$info_id\";");   $sth->execute;
	}

	$reply->{line} = $reply->{rooms};
	$this->room($reply);
	
}

sub ANON_DHCP
{
	my $this  = shift;
	my $reply = shift;

	#get annon_dhcp workstations
	my $file_content = `cat /var/lib/dhcp/db/dhcpd.leases`;
	my @sections = split("lease ", $file_content);
	my %hash = ('anon_PCs');
	foreach my $section (@sections){
		next if($section !~ /^[0-9](.*)/);
		my @lines = split("\n", $section);
		$section =~/(.*)hardware ethernet (.*);\n(.*)/;
		my $mac_address = $2;

		foreach my $line (@lines){
			$line =~ s/^\s+//;
			if( $line =~/^([0-9](.*)) \{/ ){
				$hash{anon_PCs}->{$mac_address}->{ip_address} = "$1";
			}
			if( $line =~/^client-hostname "(.*)";/ ){
				$hash{anon_PCs}->{$mac_address}->{client_hostname} = "$1";
			}
		}
	}

	#get free hosts
	my @hosts = ();
	foreach my $room ( $this->get_rooms() ){
		my $room_dn   = $room->[0];
		my $roomnet   = $this->get_attribute($room_dn,'dhcpRange').'/'.$this->get_attribute($room_dn,'dhcpNetMask');
		next if( $roomnet !~ /\d+\.\d+\.\d+\.\d+\/\d+/ );
		my $roompref  = $this->get_attribute($room_dn,'description');
		my $block = new Net::Netmask($roomnet);
		my $base       = $block->base();
		my $broadcast  = $block->broadcast();
		my $counter    = -1;
		foreach my $i ($block->enumerate()) {
			if(  $i ne $base && $i ne $broadcast ) {
				$counter ++;
				next if ( $this->ip_exists($i) );
				next if ( $roompref =~ /^SERVER_NET/ && $counter < 10 );
				my $hostname = lc(sprintf("$roompref-pc%02d",$counter));
				$hostname =~ s/_/-/;
				next if ( $this->host_exists($hostname) );
				push @hosts, $hostname.':'.$i;
			}
		}
	}
	my $freeze = encode_base64(freeze(\@hosts),"");
	main::AddSessionDatas($freeze,'hosts');

	#create table content
	my @lines = ('anon_DHCP');
	push @lines, { head => [ 'rooms', 'other_name', 'hwaddresses', 'hwconfig', 'master' ] };
	foreach my $mac ( keys %{$hash{anon_PCs}}){
		my $netcard_vendor = $this->get_vendor_netcard("$mac");
		my $result = $this->{LDAP}->search( base   => $this->{SYSCONFIG}->{DHCP_BASE},
                                   filter => "(dhcpHWAddress=ethernet $mac)",
                                   attrs  => ['cn']
                                 );
		next if($result->count() > 0);
		my   @hwconf   = @{$this->get_HW_configurations(1)};
		push @hwconf,  [ '---DEFAULTS---' ], [ '-' ];
		if( $this->{RADIUS} ){
			push @lines, { line => [ $mac,
						{ name => 'workstations', value => \@hosts, attributes => [ type => 'popup'] },
						{ other_name   => "$hash{anon_PCs}->{$mac}->{client_hostname}" },
						{ name => 'hwaddresses', value => $mac, attributes => [ type => 'label', help => "$netcard_vendor"] },
						{ hwconfig     => \@hwconf },
						{ master       => 0 },
						{ wlanaccess   => 0 },
				]};
		}else{
			push @lines, { line => [ $mac,
						{ name => 'workstations', value => \@hosts, attributes => [ type => 'popup'] },
						{ other_name   => "$hash{anon_PCs}->{$mac}->{client_hostname}" },
						{ name => 'hwaddresses', value => $mac, attributes => [ type => 'label', help => "$netcard_vendor"] },
						{ hwconfig     => \@hwconf },
						{ master       => 0 },
				]};
		}
	}

	#return page
	my @ret;
	if( scalar(@lines) < 3){
		push @ret, { subtitle => 'ANON_DHCP' };
		push @ret, { NOTICE   => main::__('Does not have workstations in the "ANON_DHCP" room!') };
		push @ret, { action   => "cancel" };
	}else{
		if( exists($reply->{warning}) ){
			push @ret, { NOTICE => $reply->{warning} };
		}
		push @ret, { subtitle => 'ANON_DHCP' };
		push @ret, { table    =>  \@lines };
		push @ret, { action   => "cancel" };
		push @ret, { name => 'action' , value  => 'insert_in_to_room', attributes => [ label => 'apply' ] };
	}
	return \@ret;
}

sub insert_in_to_room
{
	my $this  = shift;
	my $reply = shift;

	my $flag = 0;
	my @duplicate_ip_address;
	foreach my $workstation (keys %{$reply->{anon_DHCP}}){
		print $workstation."\n";
		my ( $tmp, $ip ) = split(":", $reply->{anon_DHCP}->{$workstation}->{workstations} );
		if( $this->ip_exists($ip) ){
			push @duplicate_ip_address, $workstation;
			next;
		}
		if( $reply->{anon_DHCP}->{$workstation}->{workstations} ){
			my $hash;
			$hash->{workstations} = $reply->{anon_DHCP}->{$workstation}->{workstations};
			$hash->{hwaddresses} = $workstation;
			$hash->{hwconfig} = $reply->{anon_DHCP}->{$workstation}->{hwconfig};
			$hash->{master} = $reply->{anon_DHCP}->{$workstation}->{master};
			if( exists($this->{anon_DHCP}->{$workstation}->{wlanaccess}) ){
				$hash->{wlanaccess} = $this->{anon_DHCP}->{$workstation}->{wlanaccess};
			}
			$hash->{other_name} = $reply->{anon_DHCP}->{$workstation}->{other_name};
			my ( $room_name, @tmp) = split("-", $hash->{workstations});
			my $room_dn = $this->get_room_by_name("$room_name");
			$hash->{dn} = $room_dn;
			$hash->{flag} = '1';
			$this->addPC($hash);
			$flag = 1;
		}
	}

	if( !$flag ){
                $reply->{warning} =  main::__('Please choose a workstation and choose which room you want to add this workstation!');
	}

	if( scalar(@duplicate_ip_address) ){
		my $workstations = join ", ",@duplicate_ip_address;
		$reply->{warning} = sprintf( main::__('Please choose another workstation name (workstationname:ipaddress), in order to add it to the following workstations : "%s"'),  $workstations );
	}
	return $this->ANON_DHCP($reply);
}

sub get_vendor_netcard
{
	my $this = shift;
	my $mac  = shift;
	my $vendor_netcard = '';

	$mac = uc($mac);
	$mac =~ /([0-9A-Z]{2}):([0-9A-Z]{2}):([0-9A-Z]{2})(.*)/;
	$mac = "$1-$2-$3";

	#first get
	if( !(-e "/tmp/mac_info") ){
		cmd_pipe("wget -O /tmp/mac_info http://standards.ieee.org/develop/regauth/oui/oui.txt");
	}
	$vendor_netcard = cmd_pipe("cat /tmp/mac_info | grep $mac | awk '{ print \$3\" \"\$4\" \"\$5\" \"\$6\" \"\$7}'");
	if( !$vendor_netcard ){
		cmd_pipe("wget -O /tmp/mac_info http://standards.ieee.org/develop/regauth/oui/oui.txt");
		$vendor_netcard = cmd_pipe("cat /tmp/mac_info | grep $mac | awk '{ print \$3\" \"\$4\" \"\$5\" \"\$6\" \"\$7}'");
	}

	#second get
	if( !$vendor_netcard ){
		cmd_pipe("wget -O /tmp/mac_info_2 http://www.coffer.com/mac_find/?string=$mac");
		my $mac_info = cmd_pipe("cat /tmp/mac_info_2 | grep '<td class=\"table2\"><a href='");
		my @arr_inf = split("<", $mac_info);
		$arr_inf[2] =~ /(.*)>(.*)/;
		$vendor_netcard = $2;
	}

	return $vendor_netcard;
}

sub get_free_pcs_of_room 
{
	my $this = shift;
	my $room = shift;
	my @hosts= ();
	my $roomnet    = $this->get_attribute($room,'dhcpRange').'/'.$this->get_attribute($room,'dhcpNetMask');
        if( $roomnet !~ /\d+\.\d+\.\d+\.\d+\/\d+/ ) {
                return @hosts;
        }
	my $roompref   = $this->get_attribute($room,'description');
	my $block      = new Net::Netmask($roomnet);
	my %lhosts     = ();
	my $schoolnet  = $this->get_school_config('SCHOOL_NETWORK').'/'.$this->get_school_config('SCHOOL_NETMASK');
	my $sblock     = new Net::Netmask($schoolnet);
	my $base       = $sblock->base();
	my $broadcast  = $sblock->broadcast();
	my $counter    = -1;
	foreach my $i ( $block->enumerate() )
	{
		if(  $i ne $base && $i ne $broadcast )
		{
			$counter ++;
			next if ( $this->ip_exists($i) );
			next if ( $roompref =~ /^SERVER_NET/ && $counter < 10 );
			my $hostname = lc(sprintf("$roompref-pc%02d",$counter));
			$hostname =~ s/_/-/g;
			next if ( $this->host_exists($hostname) );
			push @hosts, $hostname.':'.$i;
		}
	}
	my $freeze = encode_base64(freeze(\@hosts),"");
	main::AddSessionDatas($freeze,'hosts');
	return @hosts;
}

sub get_next_free_pc 
{
        my $this = shift;
        my $room = shift;
        my @hosts= ();
        my $roomnet    = $this->get_attribute($room,'dhcpRange').'/'.$this->get_attribute($room,'dhcpNetMask');
        if( $roomnet !~ /\d+\.\d+\.\d+\.\d+\/\d+/ ) {
                return @hosts;
        }
        my $roompref   = $this->get_attribute($room,'description');
        my $block      = new Net::Netmask($roomnet);
        my %lhosts     = ();
        my $schoolnet  = $this->get_school_config('SCHOOL_NETWORK').'/'.$this->get_school_config('SCHOOL_NETMASK');
        my $sblock     = new Net::Netmask($schoolnet);
        my $base       = $sblock->base();
        my $broadcast  = $sblock->broadcast();
        my $counter    = -1;
        foreach my $i ( $block->enumerate() )
        {
                if(  $i ne $base && $i ne $broadcast )
                {
                        $counter ++;
                        next if ( $this->ip_exists($i) );
                        next if ( $roompref =~ /^SERVER_NET/ && $counter < 10 );
                        my $hostname = lc(sprintf("$roompref-pc%02d",$counter));
                        $hostname =~ s/_/-/;
                        next if ( $this->host_exists($hostname) );
                        return ( $hostname, $i );
                }
        }
        return ();
}

sub set_sofware
{
	my $this      = shift;
	my $swinstall = shift;
	my $room_dn   = shift;

        my @ws = ( 'workstations' );
        push @ws, { head => [ 'pc_name', 'installed_sw', 'new_sw', 'install_new_sw' ] };
	foreach my $dn_ws (sort keys %{$swinstall} ){
		my $hostname = $this->get_attribute($dn_ws,'cn');
                my $user_dn = $this->get_user_dn($hostname);

                my $oldsw = '';
                foreach my $i (sort @{$this->search_vendor_object_for_vendor( 'osssoftware', $user_dn)}){
                        my $sw_name = get_name_of_dn($i);
                        my $status  = $this->get_config_value($i, 'pkgStatus');
			$oldsw .= $sw_name."<BR>" if( $status eq 'installed');
		}

		my $newsw = '';
		my $new_hw_dn = 'configurationKey='.$swinstall->{$dn_ws}->{new_hw}.','.$this->{SYSCONFIG}->{COMPUTERS_BASE};
		foreach my $i ( @{ $this->get_config_values($new_hw_dn,'SWPackage','ARRAY') } ){
			$newsw .= get_name_of_dn($i)."<BR>";
		}

		push @ws, { line => [ $dn_ws,
					{ name => 'pcname',      value => $hostname,    attributes => [type => 'label'] },
					{ name => 'oldsw',       value => $oldsw,       attributes => [type => 'label'] },
					{ name => 'newsw',       value => $newsw,       attributes => [type => 'label'] },
					{ name => 'workstation', value => '1',          attributes => [type => 'boolean'] },
					{ name => 'hw_dn',       value => "$new_hw_dn", attributes => [type => 'hidden'] }
				]};
	}

	my @ret;
	push @ret, { action => 'cancel' };
	if( scalar(@ws) > 2 ){
		push @ret, { NOTICE =>  main::__('For the PCs below there was changed the hw configuration, software packages belonging to the current hw are available for installation.')."<BR>".
					main::__('Please, leave selected the PCs where do you wish to install the new softwares.') };
	        push @ret, { table  => \@ws };
		push @ret, { name => 'sw_installing_now', value => "", attributes => [label => '', type => 'boolean', backlabel => 'Run now the install/deinstall command on these selected workstations'] };
		push @ret, { name => 'action', value => 'install_software', attributes => [label => 'apply' ] };
	}
        push @ret, { dn => $room_dn };
        return \@ret;
}

sub install_software
{
	my $this   = shift;
	my $reply  = shift;
	$reply->{line}  = $reply->{dn};

	my $result;
	foreach ( keys %{$reply->{workstations}} ){
		next if( !$reply->{workstations}->{$_}->{workstation} );
		my @ws_dns;
		my $hostname = $this->get_attribute($_,'cn');
		push @ws_dns, $this->get_user_dn($hostname);

		my $hw_dn  = $reply->{workstations}->{$_}->{hw_dn};
		my $softwares = $this->get_config_values( $hw_dn, 'SWPackage', 'ARRAY' );
		my @sw_name_list;
		@sw_name_list = @{$softwares} if( ref($softwares) eq 'ARRAY');
		my $tmp;
		if(ref($softwares) eq 'ARRAY' ){
			$tmp = $this->makeInstallDeinstallCmd('install',\@ws_dns, \@sw_name_list);
			makeInstallationNow(\@ws_dns) if ($reply->{sw_installing_now});
		}
		print Dumper($tmp);
		foreach my $type ( sort keys %{$tmp} ){
			next if( ref($tmp->{$type}) ne 'HASH' );
			foreach my $sw_name ( keys %{$tmp->{$type}->{$hostname}} ){
				$result->{$type}->{$hostname}->{$sw_name} = $tmp->{$type}->{$hostname}->{$sw_name};
			}
		}
	}
	#print Dumper($result);

	my $msg = $this->createSwInstallationStatusTable($result);
	print Dumper($msg);

	$reply->{msg} = $msg;
	$this->room($reply);
}

sub createSwInstallationStatusTable
{
        my $this   = shift;
        my $result = shift;
        my @ret;

        # Selected pc's and softwares
#        push @ret, { NOTICE => main::__('selected_computer: ')." ".$result->{selected_computer}."<BR>".main::__('selected_software: ')." ".$result->{selected_software} };

        # Missing sw requiremente
        push @ret, { ERROR  => main::__('The following requirement packages are missing:')." <B>".$result->{missing_sw_list}."</B>" } if($result->{missing_sw_list});

        # Install cmd 
        my $inst_ok  = '';
        my $inst_nok = '';
        foreach my $pc (sort keys %{$result->{installation_scheduled}} ){
                foreach my $sw (sort keys %{$result->{installation_scheduled}->{$pc}} ){
                        if( $result->{installation_scheduled}->{$pc} ){
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
                        if( $result->{deinstallation_scheduled}->{$pc} ){
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
