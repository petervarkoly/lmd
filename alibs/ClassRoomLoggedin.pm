# LMD ClassRoomLoggedin  modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ClassRoomLoggedin;

use strict;
use oss_base;
use oss_pedagogic;
use vars qw(@ISA);
use Data::Dumper;
@ISA = qw(oss_pedagogic);

sub new
{
    my $this    = shift;
    my $connect = shift || undef;
    my $self    = oss_pedagogic->new($connect);
    return bless $self, $this;
}

sub interface
{
	return [
		"getCapabilities",
		"default",
		"refresh",
	];
}

sub getCapabilities
{
	return [
		{ title        => 'ClassRoomLoggedin' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ allowedRole  => 'teachers' },
		{ allowedRole  => 'teachers,sysadmins' },
		{ category     => 'Students' },
		{ order        => 50 },
		{ variable     => [ "rooms",                           [ type => "popup", label => 'Please choose a room:' ]]},
		{ variable     => [ "pc_name",                         [ type => "label" ]]},
		{ variable     => [ "user",                            [ type => "label" ]]},
		{ variable     => [ "user_name",                       [ type => "label" ]]},
	];
}

sub default
{
        my $this   = shift;
        my $reply  = shift;
	my $room   = shift;
        my $role   = main::GetSessionValue('role');
	
        if( $role =~ /^teachers/ )
        {
                $this->showRoomLoggedin($reply,"teachers");
        }
        elsif( $role =~ /^root|sysadmins$/ )
        {
                $this->showRoomLoggedin($reply,"sysadmins_root", "$room");
        }
}

sub showRoomLoggedin
{
	my $this   = shift;
	my $reply  = shift;
	my $type   = shift;
	my $myroom = shift || $this->get_room_by_name(main::GetSessionValue('room'));
	my @lines  = ('logon_user');
	my @ret;

	my $room_name = $this->get_attribute($myroom,'description');
	if( $type eq "sysadmins_root"){
		my @rooms = $this->get_rooms();
		if( ! @rooms  || !scalar(@rooms))
		{
			return { TYPE     => 'NOTICE',
				 MESSAGE  => 'no_rooms_defined',
				 MESSAGE1 => 'Please create rooms!'
				};
		}
		push @rooms, '---DEFAULTS---', $myroom;
		if($myroom){
			push @ret, { subtitle => "$room_name"};
			push @ret, { NOTICE => main::__("You can see in the displayed list all currently logged in users. Press \"refresh\" to check again.") };
		}
		push @ret, { rooms => \@rooms },
	}
	elsif ( ($type eq "teachers") and (!$myroom) )
	{
		push @ret, { NOTICE => main::__("This page can only be accessed from one room only!")};
	}
	else
	{
		
		push @ret, { subtitle => "$room_name"};
		push @ret, { NOTICE => main::__("You can see in the displayed list all currently logged in users. Press \"refresh\" to check again.")};
	}

	system("/usr/share/oss/tools/clean-up-sambaUserWorkstations.pl");
	if($myroom or ($type eq "sysadmins_root"))
	{
		my $lu = {};
		foreach my $logged_user (@{ $this->get_logged_users("$myroom") } )
                {
			$lu{$logged_user->{user_cn}}->{user_dn}   = $logged_user->{user_dn}; 
			$lu{$logged_user->{user_cn}}->{user_name} = $logged_user->{user_name}; 
			$lu{$logged_user->{user_cn}}->{host_name} = $logged_user->{host_name}; 
		}
		foreach my $cn (sort keys %$lu)
		{
			push @lines, { line => [ $lu{$cn}->{user_dn}, 
						{ pc_name   => $lu->{$cn}->{host_name} },
						{ user      => $lu->{$cn}->{user_name} },
						{ user_name => $cn }
					]};
		}
		push @ret, { table       => \@lines };
		push @ret, { action      => 'refresh' };
	}
	return \@ret;
}

sub refresh
{
	my $this   = shift;
	my $reply  = shift;

	if( exists($reply->{rooms}) )
	{
		$this->default($reply, "$reply->{rooms}");
	}
	else
	{
		$this->default($reply);
	}
}

1;
