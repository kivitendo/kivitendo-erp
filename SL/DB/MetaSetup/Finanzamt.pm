# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Finanzamt;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('finanzamt');

__PACKAGE__->meta->columns(
  fa_bankbezeichnung_1 => { type => 'text' },
  fa_bankbezeichnung_2 => { type => 'text' },
  fa_blz_1             => { type => 'text' },
  fa_blz_2             => { type => 'text' },
  fa_bufa_nr           => { type => 'text' },
  fa_email             => { type => 'text' },
  fa_fax               => { type => 'text' },
  fa_internet          => { type => 'text' },
  fa_kontonummer_1     => { type => 'text' },
  fa_kontonummer_2     => { type => 'text' },
  fa_land_nr           => { type => 'text' },
  fa_name              => { type => 'text' },
  fa_oeffnungszeiten   => { type => 'text' },
  fa_ort               => { type => 'text' },
  fa_plz               => { type => 'text' },
  fa_plz_grosskunden   => { type => 'text' },
  fa_plz_postfach      => { type => 'text' },
  fa_postfach          => { type => 'text' },
  fa_strasse           => { type => 'text' },
  fa_telefon           => { type => 'text' },
  id                   => { type => 'serial', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
