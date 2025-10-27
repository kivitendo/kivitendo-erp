# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomerContact;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('customer_contacts');

__PACKAGE__->meta->columns(
  contact_id  => { type => 'integer', not_null => 1 },
  customer_id => { type => 'integer', not_null => 1 },
  id          => { type => 'serial', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'customer_id', 'contact_id' ]);

__PACKAGE__->meta->foreign_keys(
  contact => {
    class       => 'SL::DB::Contact',
    key_columns => { contact_id => 'cp_id' },
  },

  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },
);

1;
;
