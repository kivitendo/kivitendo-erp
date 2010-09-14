# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::LicenseInvoice;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'licenseinvoice',

  columns => [
    trans_id   => { type => 'integer' },
    license_id => { type => 'integer' },
    id         => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
