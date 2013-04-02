# LMD Firewall modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package ClientRemoteAccess;

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
		"add",
		"apply"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Client Remote Access Configuration' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'Network' },
		 { order        => 30 },
		 { variable     => [ "add",         [ type => "action", label => "" ] ] },
		 { variable     => [ "ws",          [ type => "label", label => "workstation" ] ] },
		 { variable     => [ "wsip",        [ type => "string", label => "IP-address", readonly => undef  ] ] },
		 { variable     => [ "workstation", [ type => "popup"   ] ] },
		 { variable     => [ "activ",       [ type => "boolean" ] ] },
		 { variable     => [ "delete",      [ type => "boolean" ] ] }
	];
}

sub default
{
	my $this   = shift;
	my @newaccess = ( 'newaccess' );
	my @oldaccess = ( 'oldaccess' );
	my %ws        = ();
	my @lws       = ();
	if( ! $this->{MAILSERVER_LOCAL} ) {
		$ws{$this->get_school_config("SCHOOL_MAILSERVER")}  = "schoolserver";
		push @lws , [ $this->get_school_config("SCHOOL_MAILSERVER"),  "schoolserver" ];
	}

	if( ! $this->{PRINTSERVER_LOCAL} ) {
		$ws{$this->get_school_config("SCHOOL_PRINTSERVER")} = "printserver";
		push @lws , [ $this->get_school_config("SCHOOL_PRINTSERVER"), "printserver" ];
	}
	if( ! $this->{PROXYSERVER_LOCAL} ) {
		$ws{$this->get_school_config("SCHOOL_PROXY")} = "proxy";
		push @lws , [ $this->get_school_config("SCHOOL_PROXY"), "proxy" ];
	}
	foreach( split /\n/, `oss_get_workstations.sh` )
	{
		my ($a,$b) = split / /,$_;
		$ws{$b}    = $a;
		push @lws , [ $b, $a ];
	}
	my $fw = get_file('/etc/sysconfig/SuSEfirewall2');
        $fw =~ /^FW_FORWARD_MASQ="(.*)"$/m;
        foreach my $access ( split /\s+/, $1 )
        {
		my ( $from,$dest,$prot,$sp,$dp ) = split( /,/, $access);
		next if( ! $from );
		$sp = $dp if ( !defined $sp );
		push @oldaccess, { line => [ "$sp", { extport => $sp } , { ws => $ws{$dest} } , { wsip => $dest }, { port => $dp }, { delete => 0 } ] };
	}
	push @newaccess, { line => [ '1', { extport => '' } , { workstation => \@lws } , { port => '' }, { add => main::__('add') } ] };
	
	return [
		{ table    => \@newaccess },
		{ label	   => 'Configured Client Remote Control Accesses' },
		{ table    => \@oldaccess },
		{ action   => "cancel" },
		{ action   => "apply" }
	];
}

sub apply
{
	my $this   = shift;
	my $reply  = shift;
	my @FWR    = (); #firewall regel

	foreach my $k ( sort {$a <=> $b} keys %{$reply->{oldaccess}} )
	{
		next if( $reply->{oldaccess}->{$k}->{delete} );
		push @FWR, '0/0,'.$reply->{oldaccess}->{$k}->{wsip}.',tcp,'.$reply->{oldaccess}->{$k}->{extport}.','.$reply->{oldaccess}->{$k}->{port};
	}
	my $ACCESS = join " ", @FWR;
	system("perl -pi -e 's#^FW_FORWARD_MASQ=.*\$#FW_FORWARD_MASQ=\"$ACCESS\"#'        /etc/sysconfig/SuSEfirewall2");
	system("/sbin/SuSEfirewall2 start");
	$this->default;
}

sub add
{
	my $this   = shift;
	my $reply  = shift;
	my @ports  = (); 
	my $fw     = get_file('/etc/sysconfig/SuSEfirewall2');
	$fw =~ /^FW_FORWARD_MASQ="(.*)"$/m;
	my $ACCESS = $1;
        foreach my $access ( split /\s+/, $1 )
        {
		my ( $from,$dest,$prot,$dp,$sp ) = split( /,/, $access);
		$sp = $dp if ( !defined $sp );
		push @ports, $sp;
	}

	if( $reply->{newaccess}->{1}->{extport} !~ /^\d+$/ || $reply->{newaccess}->{1}->{port} !~ /^\d+$/ )
	{
		return {
			TYPE => 'ERROR',
			CODE => 'INVALID_PORT',
			MESSAGE => 'You have to define a numeric external and a numeric internal port.'
		};
	}
	#ext port must be uniqe
	if( contains( $reply->{newaccess}->{1}->{extport}, \@ports ) )
	{
		return {
			TYPE => 'ERROR',
			CODE => 'PORT_USED_MORE_TIMES',
			MESSAGE => 'External prots must not be used more times.'
		};
	}

	$ACCESS .= ' 0/0,'.$reply->{newaccess}->{1}->{workstation}.',tcp,'.$reply->{newaccess}->{1}->{extport}.','.$reply->{newaccess}->{1}->{port}; 
	system("perl -pi -e 's#^FW_FORWARD_MASQ=.*\$#FW_FORWARD_MASQ=\"$ACCESS\"#'        /etc/sysconfig/SuSEfirewall2");
	system("perl -pi -e 's#^FW_MASQUERADE=.*\$#FW_MASQUERADE=\"yes\"#' /etc/sysconfig/SuSEfirewall2");
	system('perl -pi -e \'s#FW_MASQ_NETS="0/0"#FW_MASQ_NETS=""#\'      /etc/sysconfig/SuSEfirewall2');
	system("/sbin/SuSEfirewall2 start");

	$this->default;
}

1;
