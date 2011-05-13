#!/usr/bin/perl

use strict;
use DateTime;

sub run {
  my $session_result = shift;

  %::myconfig = $::auth->read_user($::form->{login})  if $::form->{login};
  $::locale   = Locale->new($::myconfig{countrycode}) if $::myconfig{countrycode};

  $::form->header;
  print $::form->parse_html_template('menu/header', {
    now        => DateTime->now,
    show_debug => $::lx_office_conf{debug}{show_debug_menu},
    lxdebug    => $::lxdebug,
    is_links   => ($ENV{HTTP_USER_AGENT} =~ /links/i),
  });
}

1;

#
