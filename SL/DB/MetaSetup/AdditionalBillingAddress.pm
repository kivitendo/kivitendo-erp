# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AdditionalBillingAddress;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('additional_billing_addresses');

__PACKAGE__->meta->columns(
  city            => { type => 'text' },
  contact         => { type => 'text' },
  country         => { type => 'text' },
  customer_id     => { type => 'integer' },
  default_address => { type => 'boolean', default => 'false', not_null => 1 },
  department_1    => { type => 'text' },
  department_2    => { type => 'text' },
  email           => { type => 'text' },
  fax             => { type => 'text' },
  gln             => { type => 'text' },
  id              => { type => 'serial', not_null => 1 },
  itime           => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime           => { type => 'timestamp', default => 'now()', not_null => 1 },
  name            => { type => 'text' },
  phone           => { type => 'text' },
  street          => { type => 'text' },
  zipcode         => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },
);

1;
;
