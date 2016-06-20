# LMD GlobalConfiguration modul
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
BEGIN{ push @INC,"/usr/share/oss/lib/"; }

package GlobalConfiguration;

use strict;
use Data::Dumper;
use MIME::Base64;
use Storable qw(thaw freeze);
use oss_utils;
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
    my $self    = undef;
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
		"edit",
		"editReadOnly",
		"clean",
		"set",
		"read"
	];

}

sub getCapabilities
{
	return [
		 { title        => 'Global Configuration' },
		 { type         => 'command' },
		 { allowedRole  => 'root' },
		 { allowedRole  => 'sysadmins' },
		 { category     => 'System' },
		 { order        => 20 },
		 { variable     => [ "name",        [ type => "label", style => 'width:150px;'] ] },
		 { variable     => [ "push",        [ type => "boolean" ] ] },
		 { variable     => [ "types",       [ type => "list", size => '9', label=>"School Type" ] ] },
		 { variable     => [ "schools",     [ type => "list", size => '20', multiple=>"true", label=>"School" ] ] },
		 { variable     => [ "description", [ type => "label",  label=>"description", style => 'width:300px;' ] ] },
		 { variable     => [ "rvalue",      [ type => "label",  label=>"value" ] ] },
		 { variable     => [ "svalue",      [ type => "string", label=>"value" ] ] },
		 { variable     => [ "pvalue",      [ type => "translatedpopup",  label=>"value" ] ] },
		 { variable     => [ "section",     [ type => "hidden" ] ] },
		 { variable     => [ "edit",        [ type => "action" ] ] }
	];
}

sub default
{
        my $this   = shift;
	my @lines = ('globalconf');

        my $mesg      = $this->{LDAP}->search( base   => $this->{SYSCONFIG_BASE},
                              filter => "(objectClass=SchoolConfiguration)",
                              scope   => 'one'
                            );

        my $sections = {};
        my @ret      = ();
	foreach my $entry ( $mesg->entries )
        {
            my @path    = split /\//, $entry->get_value('configurationPath');
            my $sec     = $path[2];
            my $key     = $entry->get_value('configurationKey');

            my $tmp = $key;
 
	    $tmp =~ s/^SCHOOL_|OSS_//;
            $sections->{$sec}->{$key}->{name}          = $tmp;
        }

	my   @lines = ('cat', { head => [ '' ] } );

	foreach my $sec ( sort keys %$sections )
        {
		next if ($sec eq 'Portal' || $sec eq '' );
		push @lines, { line=> [ $sec, { edit => main::__($sec) }] };
	}
	push @ret, { table => \@lines };

        return \@ret;

}

sub editReadOnly
{
        my $this = shift;
        my $reply = shift;
        $reply->{rw} = 1;
        $reply->{line} = $reply->{section};
        $this->edit($reply);
}

sub edit
{
	my $this = shift;
	my $reply = shift;
	my $sec = $reply->{line};

	my $mesg      = $this->{LDAP}->search( base   => $this->{SYSCONFIG_BASE},
                              filter => "(objectClass=SchoolConfiguration)",
                              scope   => 'one'
                            );

        my $sections = {};
        my @ret      = ();
        my $arrays   = {};
        foreach my $entry ( $mesg->entries )
        {
            my @path    = split /\//, $entry->get_value('configurationPath');
            my $sec     = $path[2];
            my $key     = $entry->get_value('configurationKey');
            my @aval    = $entry->get_value('configurationAvailableValue');
            foreach(@aval)
            {
               push @{$sections->{$sec}->{$key}->{avalue}}, $_;
            }
            $sections->{$sec}->{$key}->{value}         = $entry->get_value('configurationValue');
            $sections->{$sec}->{$key}->{type}          = $entry->get_value('configurationValueType');
            $sections->{$sec}->{$key}->{description}   = $entry->get_value('description') || '';
            $sections->{$sec}->{$key}->{ro}            = $entry->get_value('configurationValueRO');
            $sections->{$sec}->{$key}->{default}       = $entry->get_value('configurationDefaultValue') || '';
            my $tmp = $key; $tmp =~ s/^SCHOOL_|OSS_//;
            $sections->{$sec}->{$key}->{name}          = $tmp;
        
        }
        my $freeze = encode_base64(freeze($sections),"");
        main::AddSessionDatas($freeze,'GlobalConfiguration');

	push @{$arrays->{$sec}} , $sec;
        foreach my $key ( sort keys %{$sections->{$sec}} )
        {
		my @line = ();
		$sections->{$sec}->{$key}->{description} = main::__("$sections->{$sec}->{$key}->{description}");
		$sections->{$sec}->{$key}->{description} =~ s/"/ /g;
		if( $sections->{$sec}->{$key}->{ro} eq 'yes' && !defined $reply->{rw} )
                {
                	@line = ( $key , { name =>'name' ,value=> $sections->{$sec}->{$key}->{name}, attributes => [ type=>'label', help    => "$sections->{$sec}->{$key}->{description}"]} , 
					 { rvalue => $sections->{$sec}->{$key}->{value} } );
		}
                elsif( defined $sections->{$sec}->{$key}->{avalue} )
                {
                	push @{$sections->{$sec}->{$key}->{avalue}} , '---DEFAULTS---', $sections->{$sec}->{$key}->{value};
                	@line = ( $key , { name =>'name' ,value=> $sections->{$sec}->{$key}->{name}, attributes => [ type=>'label', help    => "$sections->{$sec}->{$key}->{description}"]} ,
				         { pvalue => $sections->{$sec}->{$key}->{avalue} } );
                }
                elsif( $sections->{$sec}->{$key}->{type} eq 'yesno' )
                {
                	push @{$sections->{$sec}->{$key}->{avalue}} ,'yes','no', '---DEFAULTS---', $sections->{$sec}->{$key}->{value};
                	@line = ( $key , { name =>'name' ,value=> $sections->{$sec}->{$key}->{name}, attributes => [ type=>'label', help    => "$sections->{$sec}->{$key}->{description}"]} ,
					 { pvalue => $sections->{$sec}->{$key}->{avalue} } );
                }
                else
                {
                	@line = ( $key , { name =>'name' ,value=> "$sections->{$sec}->{$key}->{name}", attributes => [ type=>'label', help    => "$sections->{$sec}->{$key}->{description}"]} , 
					 { svalue => $sections->{$sec}->{$key}->{value} } );
                }
    		if( -e "/usr/share/oss/lib/oss_schools.pm" )
		{
			push @line, { push => 0 };	
		}
		push @{$arrays->{$sec}}, { line => \@line };
        }
	push @ret, { subtitle    => "$sec"};
	push @ret, { table       =>  $arrays->{$sec} };
	push @ret, { section     =>  $sec };
        push @ret, { rightaction => "cancel" };
	push @ret, { rightaction => "editReadOnly" };
        push @ret, { rightaction => "set" };

        return \@ret;

}

sub set
{
	my $this   = shift;
	my $reply  = shift;
	my $freeze = decode_base64(main::GetSessionDatas('GlobalConfiguration'));
        my %sections  = %{thaw($freeze )} if( defined $freeze );
	my $to_push = 0;

        if( -e "/usr/share/oss/lib/oss_schools.pm" )
        {
		if( defined $reply->{filter} )
		{
		   my $SCHOOLS = $this->searchSchools(1,$reply->{types},$reply->{filter});
		   return [
		   	{ schools => $SCHOOLS },
			{ name        => "rightaction", value => "set", attributes => [ label => 'apply' ] },
			{ rightaction => "cancel" }
		   ]
		}
		if( defined $reply->{schools} )
		{
			my $freeze = decode_base64(main::GetSessionDatas('GlobalConfigurationReply'));
			my $orig  = thaw($freeze ) if( defined $freeze );
			foreach my $school ( split /\n/, $reply->{schools} )
			{
				my $secret = $this->get_vendor_object($school,'CEPHALIX','SECRET' );
				my $host   = @{ $this->get_vendor_object($school,'CEPHALIX','LMD_ADRESS') }[0] ||  get_name_of_dn($school);
				my ($ldap, $sdn) = $this->connectSchool($school);
				my $suboss = oss_base->new( { LDAP_SERVER => $host, LDAP_BASE => $sdn, aDN=>'uid=cephalix,ou=people,'.$sdn, aPW=> $secret->[0]} );
				foreach my $sec (keys %{$orig})
				{
					next if( ref($orig->{$sec}) ne 'HASH' );
					foreach my $key (keys %{$orig->{$sec}})
					{
						next if( ! $orig->{$sec}->{$key}->{push} );
						if( defined $orig->{$sec}->{$key}->{pvalue} )
						{
							my $global_config_value = $suboss->get_school_config("$key");
							if( $orig->{$sec}->{$key}->{pvalue} ne "$global_config_value"){
								$suboss->set_school_config($key,$orig->{$sec}->{$key}->{pvalue});
								#TODO$suboss->triggering("$key");
							}
						}
						elsif( defined $orig->{$sec}->{$key}->{svalue} )
						{
							my $global_config_value = $suboss->get_school_config("$key");
							if( $orig->{$sec}->{$key}->{svalue} ne "$global_config_value"){
								$suboss->set_school_config($key,$orig->{$sec}->{$key}->{svalue});
								#TODO$suboss->triggering("$key");
							}
						}
					}
				}
				$suboss->destroy();
				$ldap->unbind();
				system("ssh $host /usr/sbin/oss_ldap_to_sysconfig.pl");
			}
			return $this->default();
		}
		foreach my $sec (keys %{$reply})
		{
			next if( ref($reply->{$sec}) ne 'HASH' );
			foreach my $key (keys %{$reply->{$sec}})
			{
				if( $reply->{$sec}->{$key}->{push} )
				{
					$to_push =1;
					last;
				}
			}
			last if( $to_push );
		}
		if( $to_push )
		{
			my $freeze = encode_base64(freeze($reply),"");
			main::AddSessionDatas($freeze,'GlobalConfigurationReply');
		}
        }

	foreach my $sec (keys %{$reply})
	{
		next if( ref($reply->{$sec}) ne 'HASH' );
		foreach my $key (keys %{$reply->{$sec}})
		{
			if( defined $reply->{$sec}->{$key}->{pvalue} )
			{
				my $global_config_value = $this->get_school_config("$key");
				if( $reply->{$sec}->{$key}->{pvalue} ne "$global_config_value"){
					$this->set_school_config($key,$reply->{$sec}->{$key}->{pvalue});
					$this->triggering("$key");
				}
			}
			elsif( defined $reply->{$sec}->{$key}->{svalue} )
			{
				my $global_config_value = $this->get_school_config("$key");
				if( $reply->{$sec}->{$key}->{svalue} ne "$global_config_value"){
					$this->set_school_config($key,$reply->{$sec}->{$key}->{svalue});
					$this->triggering("$key");
				}
			}
		}
	}
	system("/usr/sbin/oss_ldap_to_sysconfig.pl");
        if( $to_push )
	{
		return [
		        { filter      => $this->{reply} || '*' },
		        { types       => $this->schoolTypes() },
		        { name        => "rightaction", value => "set", attributes => [ label => 'search' ] },
		        { rightaction => 'cancel' }
        	];

	}
	$this->default();

}

sub triggering
{
	my $this     = shift;
	my $conf_key = shift;
	my $act_conf_value  = $this->get_school_config("$conf_key");
	my $trigger_scripts = $this->get_vendor_object( "configurationKey=$conf_key,$this->{SYSCONFIG_BASE}", 'EXTIS','TriggerScript');
	return if( scalar(@$trigger_scripts) == 0 );

	foreach my $trigger_script ( @$trigger_scripts ){
		system("$trigger_script --$act_conf_value");
	}

}

1;
