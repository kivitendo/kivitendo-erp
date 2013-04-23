# @tag: finanzamt_update_fa_bufa_nr_hamburg
# @description: Aktualisiert die fa_bufa_nr für Hamburg
# @depends: release_2_7_0
package SL::DBUpgrade2::finanzamt_update_fa_bufa_nr_hamburg;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my @data = (
    ['02', '41'],
    ['57', '42'],
    ['71', '43'],
    ['15', '43'],
    ['03', '44'],
    ['54', '45'],
    ['22', '46'],
    ['06', '47'],
    ['74', '48'],
    ['26', '49'],
    ['09', '50'],
    ['08', '51'],
  );

  foreach my $entry (@data) {
    $self->db_query('
    UPDATE finanzamt
    SET
      fa_bufa_nr = \'22'. $entry->[1] .'\'
    WHERE
          fa_land_nr = \'2\'
      AND fa_bufa_nr = \'22'. $entry->[0] .'\'');
  }

  return 1;
}

1;
