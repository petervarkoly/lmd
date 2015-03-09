# LMD ClassRoomLoggedin  modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package MobileSite;
use strict;

use oss_base;
use oss_pedagogic;
use oss_utils;
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
		"logout_user"
        ];
}

sub getCapabilities
{
        return [
                { title        => 'MobileSite' },
                { type         => 'command' },
                { allowedRole  => 'root' },
                { allowedRole  => 'sysadmins' },
                { allowedRole  => 'students' },
                { allowedRole  => 'teachers' },
                { allowedRole  => 'teachers,sysadmins' },
                { category     => 'MOBILEAPPS' },
                { order        => 50 },
                { variable     => [ "rooms",                           [ type => "popup", label => 'Please choose a room:' ]]},
                { variable     => [ "pc_name",                         [ type => "label" ]]},
                { variable     => [ "notice",                          [ type => "label" ]]},
                { variable     => [ "user",                            [ type => "label" ]]}
        ];
}

sub default
{
        my $this   = shift;
        my $reply  = shift;
        my $room   = shift;
        my $role   = main::GetSessionValue('role');

        if( $role =~ /^students/ )
        {
                $this->showWSLoggedin($reply);
        }
        elsif( $role =~ /^root|sysadmins$/ )
        {
                $this->showRoomLoggedin($reply,"sysadmins_root", "$room");
        }
        elsif( $role =~ /^teachers/ )
        {
                $this->showRoomLoggedin($reply,"teachers");
        }
}

sub showWSLoggedin
{
        my $this   = shift;
        my $reply  = shift;
        my $role   = main::GetSessionValue('role');
        my $dn     = main::GetSessionValue('dn');
        my $ip     = main::GetSessionValue('ip');
	my $ws     = get_name_of_dn($this->get_workstation($ip));
	my $cn     = $this->get_attribute($dn,'cn');

	my @other  = ();
	my @ret    = { NOTICE => sprintf( main::__('Hallo %s! Welcome on "%s"!'),$cn, $ws ) };
	my $mesg = $this->{LDAP}->search( base    => $this->{SYSCONFIG}->{USER_BASE},
                                          scope   => 'sub',
                                          attrs   => ['uid','cn'],
                                          filter  => "(configurationValue=LOGGED_ON=$ip)"
	);
	foreach my $e ( $mesg->entries )
	{
		next if( $dn eq $e->dn() );
		push @other, { line => [ $e->dn , { uid => $e->get_value('uid') }, { cn => $e->get_value('cn') } ] };
	}
	if( scalar @other )
	{
	        my @tmp = ('others');
		push @tmp, @other;
		push @ret, { NOTICE => "You are not the only one, logged on on this workstation.<br>Notice this your teacher!" };
		push @ret, { table => \@tmp };
	}
	return \@ret;
}

sub showRoomLoggedin
{
        my $this   = shift;
        my $reply  = shift;
        my $type   = shift;
        my $role   = main::GetSessionValue('role');
        my $myroom = shift || $this->get_room_by_name(main::GetSessionValue('room'));
        my @lines  = ('logon_user');
        my @ret    = ();

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
                        push @ret, { NOTICE => main::__("You can see in the displayed list all currently logged in users.<br>Press \"refresh\" to check again.") };
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

        if($myroom or ($type eq "sysadmins_root"))
        {
                foreach my $logged_user (@{ $this->get_logged_users("$myroom") } )
                {
			if( $role =~ /^root|sysadmins$/  && $this->is_teacher($logged_user->{user_dn}) )
			{
                        	push @lines, { line => [ $logged_user->{user_dn},
                                                { pc_name   => $logged_user->{host_name} },
                                                { user      => $logged_user->{user_name}.'('.main::__('teachers').')' },
                                                { user_name => $logged_user->{user_cn} },
						{ name      => "action", value =>  "logout_user",  attributes => [ label => "logout" ] }
                                        ]};
			}
			elsif( $this->is_teacher($logged_user->{user_dn}) )
			{
                        	push @lines, { line => [ $logged_user->{user_dn},
                                                { pc_name   => $logged_user->{host_name} },
                                                { user      => $logged_user->{user_name}.'('.main::__('teachers').')' },
                                                { user_name => $logged_user->{user_cn} },
						{ notice    => "You can not logout this account." }
                                        ]};
			}
			else
			{
                        	push @lines, { line => [ $logged_user->{user_dn},
                                                { pc_name   => $logged_user->{host_name} },
                                                { user      => $logged_user->{user_name}.'('.main::__('students').')'  },
                                                { user_name => $logged_user->{user_cn} },
						{ name      => "action", value =>  "logout_user",  attributes => [ label => "logout" ] }
                                        ]};
			}
                }
                push @ret, { table       => \@lines };
		push @ret, { name      => "action", value =>  "logout_user",  attributes => [ label => "logout all" ] };
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
                $this->default($reply, $reply->{rooms});
        }
        else
        {
                $this->default($reply);
        }
}

sub logout_user
{
        my $this   = shift;
        my $reply  = shift;
	my $dn     = $reply->{line} || undef;
	my $mydn   = main::GetSessionValue('dn');
	if( defined $dn )
	{
	   $this->clean_up_user_attributes($dn);
	}
	else
	{
	   foreach my $dn ( keys %{$reply->{logon_user}} )
	   {
	      next if( $dn eq $mydn ); 
	      $this->clean_up_user_attributes($dn);
	   }
	}
	$this->default();
}


sub clean_up_user_attributes
{
        my $this = shift;
        my $dn   = shift;
	my @confs  = ();
	my $mesg = $this->{LDAP}->search( base => $dn,
                                scope => "base",
                                filter=> "objectClass=SchoolAccount",
                                attrs=> [ 'configurationValue' ] );

	if( $mesg->count )
	{
		@confs    = $mesg->entry(0)->get_value('configurationValue');
	}
	my @newconfs = ();
	foreach my $v (@confs)
	{
	   if( $v !~ /^LOGGED_ON=.*/ )
	   {
	      push @newconfs, $v;
	   }
	}
	if( $#confs > -1 )
	{
	   $this->{LDAP}->modify( $dn ,  delete => [ 'configurationValue' ] );
	}
	if( $#newconfs > -1 )
	{
	   $this->{LDAP}->modify( $dn ,  add    => { configurationValue => \@newconfs } );
	}
}
