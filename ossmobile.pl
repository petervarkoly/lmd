#!/usr/bin/perl
#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# ossmobile.pl
#

BEGIN{ push @INC,"/usr/share/lmd/"; }

$| = 1; # do not buffer stdout

use strict;
use ossmobile;

use CGI -utf8;
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use subs qw(exit);
# Select the correct exit function
*exit = $ENV{MOD_PERL} ? \&Apache::exit : sub { CORE::exit };
my $cgi=new CGI;

my $menu = new ossmobile($cgi);
$menu->display();

