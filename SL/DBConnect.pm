package SL::DBConnect;

use strict;

use DBI;

sub connect {
  shift;

  return DBI->connect(@_) unless $::lx_office_conf{debug} && $::lx_office_conf{debug}->{dbix_log4perl};

  require Log::Log4perl;
  require DBIx::Log4perl;

  my $filename =  $LXDebug::file_name;
  my $config   =  $::lx_office_conf{debug}->{dbix_log4perl_config};
  $config      =~ s/LXDEBUGFILE/${filename}/g;

  Log::Log4perl->init(\$config);
  return DBIx::Log4perl->connect(@_);
}

1;
