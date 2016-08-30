# LMD Template modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package SendMessage;

use strict;
use oss_base;
use oss_utils;
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
                "send"
        ];

}

sub getCapabilities
{
        return [
                 { title        => 'Send Message' },
                 { type         => 'command' },
                 { allowedRole  => 'root' },
                 { allowedRole  => 'sysadmins' },
                 { category     => 'Security' },
                 { order        => 50 },
                 { variable     => [ "rooms",   [ type => "list", size => 10, multiple => 1, label=>"Rooms" ] ] },
                 { variable     => [ "pcs",     [ type => "list", size => 10, multiple => 1, label=>"Workstations" ] ] },
		 { variable     => [ "message", [ type => "text" ] ] }
        ];
}

sub default
{
        my $this   = shift;
        my $reply  = shift;
	my @ret    = ();

        my $pcs    = `oss_get_workstations.sh | gawk '{ print \$1 }'`;
        my @ALL    = ( "all" );
        push @ALL, split /\n/,$pcs;
	my @rooms  = $this->get_rooms();

	push @ret, { NOTICE   => $reply->{error} } if (defined $reply->{error} );
        push @ret, { rooms    => \@rooms };
        push @ret, { pcs      => \@ALL };
	push @ret, { message  => $reply->{message} };
        push @ret, { action   => "cancel" };
        push @ret, { action   => "send" };
	return \@ret;
}

sub send
{
        my $this   = shift;
        my $reply  = shift;
	my $mess   = $reply->{message};
        my @pcs    = split /\n/, $reply->{pcs};
        my @rooms  = split /\n/, $reply->{rooms};
	if( !scalar(@pcs) and !scalar(@rooms))
	{
	    $reply->{error} = main::__('Select a room or a workstation!');
	    return $this->default($reply);
	}
        my @WS     = ();
        if( contains('all',\@pcs) )
        {
		my $workstations = $this->get_workstations();
		foreach my $dn ( keys %{$workstations} )
		{
			push @WS, get_name_of_dn($dn);
		}
        }
	else
	{
		foreach my $pc ( @pcs )
		{
			push @WS, $pc;
		}
		foreach my $rdn ( split /\n/, $reply->{rooms} )
		{
			foreach my $dn ( @{$this->get_workstations_of_room($rdn)} )
			{
				push @WS, get_name_of_dn($dn);
			}
		}
	}
	#Adapt message!
	$mess = join(" ",split(/\n/, $mess));
	$mess =~ s/'/\\'/g;
	foreach my $workstation ( @WS )
	{
		my $cmd  = '/usr/sbin/oss_control_client.pl --client="'.$workstation.'" ';
		   $cmd .= '--cmd=ExecuteCommandCmd --execfilename=cmd.exe --execworkdir="C:\Windows\System32" ';
		   $cmd .= "--execarg='/c msg * $mess'";
print $cmd."\n";
		system("$cmd &");
	}
	$this->default();
}

1;

