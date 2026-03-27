# @tag: countries_phase_1
# @description: Setzt Länder-Auswahlmenü als Pflichtfeld für Kunden und Lieferanten sowie als optionales Feld für abweichende Liefer- und Rechnungsadressen
# @depends: release_4_0_0 countries_phase_0
package SL::DBUpgrade2::countries_phase_1;

use strict;
use utf8;

use SL::DBUtils;
use SL::Helper::ISO3166;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my @errors = ();
  my %missing = ();
  $missing{$_->{name}} = $_->{id} for @{$::form->{missing} // []};

  my ($query, $sth);

  $query = 'INSERT INTO countries (iso2, description_en, description_de) VALUES (?, ?, ?) ON CONFLICT (iso2) DO NOTHING';
  $sth = $self->dbh->prepare($query);
  my $countries = SL::Helper::ISO3166::get_alpha_2_mappings;
  for my $c (@$countries) {
    $sth->execute($c->[0], $c->[2], $c->[3]) || $self->db_error($query);
  }

  $query = "
UPDATE countries SET sortorder = 1 WHERE iso2 = 'DE';
UPDATE countries SET sortorder = 2 WHERE iso2 = 'CH';
UPDATE countries SET sortorder = 3 WHERE iso2 = 'AT';

UPDATE countries c SET sortorder = 4+i
  FROM (SELECT ROW_NUMBER() OVER (ORDER BY description_de) AS i, id FROM countries WHERE sortorder IS NULL ) ord
  WHERE c.id = ord.id;";
  $sth = $self->dbh->prepare($query);
  $sth->execute || $self->db_error($query);

  return 1;
}

1;
