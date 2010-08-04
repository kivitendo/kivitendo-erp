#====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#====================================================================

package SL::Template;

use strict;

use SL::Template::Simple;
use SL::Template::Excel;
use SL::Template::HTML;
use SL::Template::LaTeX;
use SL::Template::OpenDocument;
use SL::Template::PlainText;
use SL::Template::XML;

sub create {
  my %params  = @_;
  my $package = "SL::Template::" . $params{type};

  $package->new($params{file_name}, $params{form}, $params{myconfig} || \%::myconfig, $params{userspath} || $::userspath);
}

1;
