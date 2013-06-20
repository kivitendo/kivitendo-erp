package Support::CanonialGlobals;

my @globals = qw(
  $::lxdebug
  $::auth
  %::myconfig
  $::form
  %::lx_office_conf
  $::locale
  $::dispatcher
  $::instance_conf
  %::request
);

sub import {
  eval "$_" for @globals;
}
