# DYN-DNS modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ExportHosts;

use strict;
use oss_base;
use oss_utils;
use MIME::Base64;
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
		"exportHosts",
        ];

}

sub getCapabilities
{
        return [
                { title        => 'ExportHosts' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { category     => 'Network' },
                { order        => 90 },
		{ variable     => [ "export_all",      [ type => "boolean" ] ] },
		{ variable     => [ "Rembo",           [ type => "boolean" ] ] },
		{ variable     => [ "export_rooms",    [ type => "list", size=>"8", multiple=>"true" ] ] }
        ];
}

sub default
{
	my $this  = shift;
	my $reply = shift;
	my @ret;
	my @rooms = $this->get_rooms('client');

	if($reply->{warning}){
		push @ret, {NOTICE => "$reply->{warning}"};
	}


	push @ret, { label => "A. If you wish to export all the Rooms PC s then check it here:" };
	push @ret, { export_all => '' };
	push @ret, { label => "B. If you wish to export only a few PC s then select check those:" };
	push @ret, { export_rooms => \@rooms };
	push @ret, { label => "B. If you wish to export the host for Rembo check this box:" };
	push @ret, { Rembo       => 0 };
	push @ret, { rightaction => 'exportHosts'};
	push @ret, { rightaction => 'cancel'};

	return \@ret;
}

sub exportHosts
{
	my $this  = shift;
	my $reply = shift;
	my $hostlist = '';
	my %hash;
	my @rooms = ();

	#get school netmask
	my $school_netmask = $this->get_school_config("SCHOOL_NETMASK");

	if(!$reply->{Rembo})
	{
		$hostlist = "Room;PC Name;HW Configuration;MAC-Address;IP-Address;Inventory Number;Serial Number;Position\n";
	}

	if($reply->{export_all} and $reply->{export_rooms})
	{
		$reply->{warning} = main::__('Please select only A. to select everything or B chose the classrooms !');
		return $this->default($reply);
	}
	elsif($reply->{export_all})
	{
		@rooms = $this->get_rooms('all');
	}
	elsif($reply->{export_rooms})
	{
		foreach my $dn (split('\n', $reply->{export_rooms}))
		{
			push @rooms, [ $dn , $this->get_attribute($dn,'description') ];
		}
	}
	else
	{
		$reply->{warning} = main::__('Please check from A. everything or from B. select the rooms !');
		return $this->default($reply);
	}

	foreach my $room ( @rooms )
	{
		#get room name
		next if ( $room->[1] eq 'ANON_DHCP' );
		my $roomdn    = $room->[0];
		my $room_name = $room->[1];
		foreach my $dn ( @{$this->get_workstations_of_room($roomdn)} )
		{
			#get pc name
			my $pc_name = $this->get_attribute($dn,'cn');
			#get pc hardware configuration
			my $pc_hw_config = $this->get_config_value($dn,'HW');
			my @hwconf       = @{$this->get_HW_configurations(1)};
			my $pc_hw_config_description;
			foreach my $hwconfig (@hwconf)
			{
				if( $hwconfig->[0] eq $pc_hw_config )
				{
					$pc_hw_config_description = $hwconfig->[1];
					last;
				}
			}

			#get pc hardware address
			my $pc_hwaddress = $this->get_attribute($dn,'dhcpHWAddress');
			$pc_hwaddress =~ s/ethernet //i;

			#get pc ip address
			my $pc_ipaddress = $this->get_attribute($dn,'dhcpStatements');
			$pc_ipaddress =~ s/fixed-address //i;

			if($reply->{Rembo})
			{
				$hash{$room_name}->{$pc_name} = "$pc_hw_config_description;$pc_hwaddress;$pc_ipaddress;$school_netmask;1;1;1;1;22;noprotpart\n";
			}
			else
			{
				my $inventary = $this->get_config_value($dn,'INVENTARNUMBER') ||'';
				my $serial    = $this->get_config_value($dn,'SERIALNUMBER') ||'';
				my $position  = @{$this->get_vendor_object($dn,'EXTIS','COORDINATES')}[0] ||'';
				$hash{$room_name}->{$pc_name} = "$pc_hw_config_description;$pc_hwaddress;$pc_ipaddress;$inventary;$serial;$position\n";
			}
		}
	}

	foreach my $room_name (sort keys %hash )
	{
		foreach my $host_name (sort keys %{$hash{$room_name}} )
		{
			$hostlist .= "$room_name;$host_name;$hash{$room_name}->{$host_name}";
		}
	}


	my( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst )   = localtime(time);
	my $file_name = "hostlist-".sprintf('%4d-%02d-%02d-%02d-%02d', $year+1900, $mon+1, $mday, $hour, $min).".txt";

	return [
		{name => 'download', value=>encode_base64($hostlist), attributes => [ type => 'download', filename=> "$file_name", mimetype=>'text/plain']}
	];

}

1;
