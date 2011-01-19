package SL::LxOfficeConf;

use strict;

use Config::Std;
use Encode;

sub read {
  my $file = -f 'config/lx_office.conf' ? 'config/lx_office.conf' : 'config/lx_office.conf.default';
  read_config $file => %::lx_office_conf;
  _decode_recursively(\%::lx_office_conf);
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

1;
