package SL::LxOfficeConf;

use strict;

use Config::Std;
use Encode;

sub read {
  read_config 'config/lx_office.conf.default' => %::lx_office_conf;
  _decode_recursively(\%::lx_office_conf);

  if (-f 'config/lx_office.conf') {
    read_config 'config/lx_office.conf' => my %local_conf;
    _decode_recursively(\%local_conf);
    _flat_merge(\%::lx_office_conf, \%local_conf);
  }
}

sub _decode_recursively {
  my ($obj) = @_;

  while (my ($key, $value) = each %{ $obj }) {
    if (ref($value) eq 'HASH') {
      _decode_recursively($value);
    } else {
      $obj->{$key} = decode('UTF-8', $value);
    }
  }
}

sub _flat_merge {
  my ($dst, $src) = @_;

  while (my ($key, $value) = each %{ $src }) {
    if (!exists $dst->{$key}) {
      $dst->{$key} = $value;

    } else {
      map { $dst->{$key}->{$_} = $value->{$_} } keys %{ $value };
    }
  }
}

1;
