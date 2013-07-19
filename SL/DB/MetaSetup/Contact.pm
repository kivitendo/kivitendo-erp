# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Contact;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('contacts');

__PACKAGE__->meta->columns(
  cp_abteilung   => { type => 'text' },
  cp_birthday    => { type => 'date' },
  cp_city        => { type => 'text' },
  cp_cv_id       => { type => 'integer' },
  cp_email       => { type => 'text' },
  cp_fax         => { type => 'text' },
  cp_gender      => { type => 'character', length => 1 },
  cp_givenname   => { type => 'varchar', length => 75 },
  cp_id          => { type => 'integer', not_null => 1, sequence => 'id' },
  cp_mobile1     => { type => 'text' },
  cp_mobile2     => { type => 'text' },
  cp_name        => { type => 'varchar', length => 75 },
  cp_phone1      => { type => 'varchar', length => 75 },
  cp_phone2      => { type => 'varchar', length => 75 },
  cp_position    => { type => 'varchar', length => 75 },
  cp_privatemail => { type => 'text' },
  cp_privatphone => { type => 'text' },
  cp_project     => { type => 'text' },
  cp_satfax      => { type => 'text' },
  cp_satphone    => { type => 'text' },
  cp_street      => { type => 'text' },
  cp_title       => { type => 'varchar', length => 75 },
  cp_zipcode     => { type => 'text' },
  itime          => { type => 'timestamp', default => 'now()' },
  mtime          => { type => 'timestamp' },
);

__PACKAGE__->meta->primary_key_columns([ 'cp_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
