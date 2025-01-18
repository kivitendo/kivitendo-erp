# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::TransferType;

use strict;

use SL::DB::MetaSetup::TransferType;
use SL::DB::Manager::TransferType;

__PACKAGE__->meta->initialize;

# methods

sub description_t8 {
  return $::locale->text(shift()->description);
}

sub direction_symbol {
  my $direction = shift()->direction;
  return    $direction eq 'in'       ? '+'
          : $direction eq 'out'      ? '-'
          : $direction eq 'transfer' ? '='
          : die "Invalid direction entry";
}

1;
