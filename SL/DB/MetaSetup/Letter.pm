# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Letter;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('letter');

__PACKAGE__->meta->columns(
  id                => { type => 'integer', not_null => 1, sequence => 'id' },
  vc_id             => { type => 'integer', not_null => 1 },
  rcv_name          => { type => 'text' },
  rcv_contact       => { type => 'text' },
  rcv_address       => { type => 'text' },
  rcv_countrycode   => { type => 'text' },
  rcv_zipcode       => { type => 'text' },
  rcv_city          => { type => 'text' },
  letternumber      => { type => 'text' },
  jobnumber         => { type => 'text' },
  text_created_for  => { type => 'text' },
  date              => { type => 'text' },
  subject           => { type => 'text' },
  greeting          => { type => 'text' },
  body              => { type => 'text' },
  close             => { type => 'text' },
  company_name      => { type => 'text' },
  employee_id       => { type => 'integer' },
  employee_position => { type => 'text' },
  salesman_id       => { type => 'integer' },
  salesman_position => { type => 'text' },
  itime             => { type => 'timestamp', default => 'now()' },
  mtime             => { type => 'timestamp' },
  rcv_country       => { type => 'text' },
  page_created_for  => { type => 'text' },
  cp_id             => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  salesman => {
    class       => 'SL::DB::Employee',
    key_columns => { salesman_id => 'id' },
  },
);

# __PACKAGE__->meta->initialize;

1;
;
