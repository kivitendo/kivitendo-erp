# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CountryLanguage;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('countries_language');

__PACKAGE__->meta->columns(
  country_id  => { type => 'integer', not_null => 1 },
  id          => { type => 'serial', not_null => 1 },
  language_id => { type => 'integer', not_null => 1 },
  localized   => { type => 'text', default => '', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'country_id', 'language_id' ]);

__PACKAGE__->meta->foreign_keys(
  country => {
    class       => 'SL::DB::Country',
    key_columns => { country_id => 'id' },
  },

  language => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },
);

1;

