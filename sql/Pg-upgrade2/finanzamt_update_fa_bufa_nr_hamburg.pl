# @tag: finanzamt_update_fa_bufa_nr_hamburg
# @description: Aktualisiert die fa_bufa_nr für Hamburg
# @depends: release_2_7_0
# @charset: utf-8
package finanzamt_update_fa_bufa_nr_hamburg;
use utf8;
use strict;

if ( !$::form ) {
  die('This script cannot be run from the command line.');
}

sub query {
  my ($query) = @_;

  if ( !$dbh->do($query) ) {
    die($dbup_locale->text('Database update error:') .'<br>'. $query .'<br>'. $DBI::errstr);
  }
}

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
  query('
    UPDATE finanzamt
    SET
      fa_bufa_nr = \'22'. $entry->[1] .'\'
    WHERE
          fa_land_nr = \'2\'
      AND fa_bufa_nr = \'22'. $entry->[0] .'\';');
}

return 1;
