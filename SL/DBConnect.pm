package SL::DBConnect;

use strict;

use DBI;

sub connect {
  shift;

  # print STDERR "Starting full caller dump:\n";
  # my $level = 0;
  # while (my ($dummy, $filename, $line, $subroutine) = caller $level) {
  #   print STDERR "  ${subroutine} from ${filename}:${line}\n";
  #   $level++;
  # }

  return DBI->connect(@_) unless $::lx_office_conf{debug} && $::lx_office_conf{debug}->{dbix_log4perl};

  require Log::Log4perl;
  require DBIx::Log4perl;

  my $filename =  $::lxdebug->file;
  my $config   =  $::lx_office_conf{debug}->{dbix_log4perl_config};
  $config      =~ s/LXDEBUGFILE/${filename}/g;

  Log::Log4perl->init(\$config);
  return DBIx::Log4perl->connect(@_);
}

sub get_options {
  my $self    = shift;
  my $options = {
    pg_enable_utf8 => $::locale->is_utf8,
    @_
  };

  return $options;
}

1;
