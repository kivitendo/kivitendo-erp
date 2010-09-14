# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TranslationPaymentTerm;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'translation_payment_terms',

  columns => [
    payment_terms_id => { type => 'integer', not_null => 1 },
    language_id      => { type => 'integer', not_null => 1 },
    description_long => { type => 'text' },
    id               => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    language => {
      class       => 'SL::DB::Language',
      key_columns => { language_id => 'id' },
    },

    payment_terms => {
      class       => 'SL::DB::PaymentTerm',
      key_columns => { payment_terms_id => 'id' },
    },
  ],
);

1;
;
