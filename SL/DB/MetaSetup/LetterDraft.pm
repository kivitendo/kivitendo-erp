# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::LetterDraft;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('letter_draft');

__PACKAGE__->meta->columns(
  body              => { type => 'text' },
  close             => { type => 'text' },
  company_name      => { type => 'text' },
  cp_id             => { type => 'integer' },
  date              => { type => 'date' },
  employee_id       => { type => 'integer' },
  employee_position => { type => 'text' },
  greeting          => { type => 'text' },
  id                => { type => 'integer', not_null => 1, sequence => 'id' },
  intnotes          => { type => 'text' },
  itime             => { type => 'timestamp', default => 'now()' },
  jobnumber         => { type => 'text' },
  letternumber      => { type => 'text' },
  mtime             => { type => 'timestamp' },
  page_created_for  => { type => 'text' },
  rcv_address       => { type => 'text' },
  rcv_city          => { type => 'text' },
  rcv_contact       => { type => 'text' },
  rcv_country       => { type => 'text' },
  rcv_countrycode   => { type => 'text' },
  rcv_name          => { type => 'text' },
  rcv_zipcode       => { type => 'text' },
  reference         => { type => 'text' },
  salesman_id       => { type => 'integer' },
  salesman_position => { type => 'text' },
  subject           => { type => 'text' },
  text_created_for  => { type => 'text' },
  vc_id             => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  contact => {
    class       => 'SL::DB::Contact',
    key_columns => { cp_id => 'cp_id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  salesman => {
    class       => 'SL::DB::Employee',
    key_columns => { salesman_id => 'id' },
  },
);

1;
;
