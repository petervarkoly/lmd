# LMD Module to manage Application Rights
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ApplicationRights;

use strict;
use oss_base;
use oss_LDAPAttributes;
use oss_utils;
use Storable qw(thaw freeze);
use MIME::Base64;
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
		"toggle",
		"filetree_dir_open",
		"toggleall"
	];

}

sub getCapabilities
{
	return [
		{ title        => 'Manage Application Rights' },
		{ type         => 'command' },
		{ allowedRole  => 'root' },
		{ allowedRole  => 'sysadmins' },
		{ category     => 'Settings' },
                { order        => 30 },
		{ variable     =>  [ "apps",   [ type => "filetree", label=>"Applications", can_choose_dir => "true" ] ]  }
	];
}

sub filetree_dir_open
{
	my $this   = shift;
	my $reply  = shift;
	$this->default($reply);
}

sub default
{
	my $this   = shift;
	my $reply  = shift;
	my @modules= ();
	my $path   = $reply->{apps} || "roles";
	my $MENU   = thaw(decode_base64(main::GetSessionDatas('MODULES','BASE')));
	my $apps   = '<dir label="'.main::__("Roles").'" path="roles">'."\n";

	foreach my $role ( sort keys %{$MENU} )
	{
		my $tmp = substr( $path,0,length("roles/$role"));
		if( "roles/$role" ne $tmp && "roles/$role/" ne "$tmp/" )
		{
			$apps   .= '  <dir label="'.main::__($role)."\" path=\"roles/$role\"/>\n";
			next;
		}
		$apps   .= '  <dir label="'.main::__($role)."\" path=\"roles/$role\">\n";
		foreach my $cat ( keys %{$MENU->{$role}} )
		{
			if( main::isDenied("r","$role","C:$cat") )
			{
				$apps   .= '    <dir label="('.main::__($cat).")\" path=\"roles/$role/$cat\"/>\n";
				next;
			}
			else
			{
				$tmp = substr( $path,0,length("roles/$role/$cat"));
				if( "roles/$role/$cat" ne $tmp )
				{
					$apps   .= '    <dir label="'.main::__($cat)."\" path=\"roles/$role/$cat\"/>\n";
					next;
				}
				$apps   .= '    <dir label="'.main::__($cat)."\" path=\"roles/$role/$cat\">\n";
				foreach my $mod ( keys %{$MENU->{$role}->{$cat}} )
				{
					if( main::isDenied("r","$role","$mod") )
					{
						$apps   .= '      <dir label="('.main::__($mod).")\" path=\"roles/$role/$cat/$mod\"/>\n";
						next;
					}
					else
					{
						$apps   .= '      <dir label="'.main::__($mod)."\" path=\"roles/$role/$cat/$mod\">\n";
					}
					$apps   .= "      </dir>\n";
				}
			}
			$apps   .= "    </dir>\n";
		}
		$apps   .= "  </dir>\n";
	}
	$apps .= '</dir>';
	my @ret = ( { apps      => $apps } );
	if( $path =~ /roles\/.*\// )
	{
		push @ret, { rightaction    => 'toggle' };
	}
	return \@ret;
}


sub toggle
{
	my $this   = shift;
	my $reply  = shift;
	my ( $nix, $role , $cat, $mod, $func ) = split( /\//,$reply->{apps} );
	my $dest   = "C:$cat";

	if( defined $func )
	{
		$dest=$func;
	}
	elsif( defined $mod )
	{
		$dest=$mod;
	}

	if( main::isDenied("r","$role","$dest") == 2 && $role ne '*' )
	{
		main::addRight("r","$role","$dest","y");
	}
	elsif( main::isDenied("r","$role","$dest") == 1 )
	{
		main::delRight("r","$role","$dest");
	}
	else
	{
		main::addRight("r","$role","$dest","n");
	}
	$this->default($reply);
}

1;
