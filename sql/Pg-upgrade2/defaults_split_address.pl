# @tag: defaults_split_address
# @description: Adress-Feld in Mandantenkonfiguration in einzelne Bestandteile aufteilen
# @depends: release_3_5_4
package SL::DBUpgrade2::defaults_split_address;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my ($address) = $self->dbh->selectrow_array("SELECT address FROM defaults");

  my (@street, $zipcode, $city, $country);
  my @lines = grep { $_ } split m{\r*\n+}, $address // '';

  foreach my $line (@lines) {
    if ($line =~ m{^(?:[a-z]+[ -])?(\d+) +(.+)}i) {
      ($zipcode, $city) = ($1, $2);

    } elsif ($zipcode) {
      $country = $line;

    } else {
      push @street, $line;
    }
  }

  $self->db_query(<<SQL);
    ALTER TABLE defaults
    ADD COLUMN  address_street1 TEXT,
    ADD COLUMN  address_street2 TEXT,
    ADD COLUMN  address_zipcode TEXT,
    ADD COLUMN  address_city    TEXT,
    ADD COLUMN  address_country TEXT,
    DROP COLUMN address
SQL

  $self->db_query(<<SQL, bind => [ map { $_ // '' } ($street[0], $street[1], $zipcode, $city, $country) ]);
    UPDATE defaults
    SET address_street1 = ?,
        address_street2 = ?,
        address_zipcode = ?,
        address_city    = ?,
        address_country = ?
SQL

  return 1;
}

1;
