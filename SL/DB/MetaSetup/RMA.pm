# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RMA;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'rma',

  columns => [
    id                   => { type => 'integer', not_null => 1, sequence => 'id' },
    rmanumber            => { type => 'text', not_null => 1 },
    transdate            => { type => 'date', default => 'now' },
    vendor_id            => { type => 'integer' },
    customer_id          => { type => 'integer' },
    amount               => { type => 'numeric', precision => 5, scale => 15 },
    netamount            => { type => 'numeric', precision => 5, scale => 15 },
    reqdate              => { type => 'date' },
    taxincluded          => { type => 'boolean' },
    shippingpoint        => { type => 'text' },
    notes                => { type => 'text' },
    curr                 => { type => 'character', length => 3 },
    employee_id          => { type => 'integer' },
    closed               => { type => 'boolean', default => 'false' },
    quotation            => { type => 'boolean', default => 'false' },
    quonumber            => { type => 'text' },
    cusrmanumber         => { type => 'text' },
    intnotes             => { type => 'text' },
    delivery_customer_id => { type => 'integer' },
    delivery_vendor_id   => { type => 'integer' },
    language_id          => { type => 'integer' },
    payment_id           => { type => 'integer' },
    department_id        => { type => 'integer', default => '0' },
    itime                => { type => 'timestamp', default => 'now()' },
    mtime                => { type => 'timestamp' },
    shipvia              => { type => 'text' },
    cp_id                => { type => 'integer' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
