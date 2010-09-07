# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Contact;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'contacts',

  columns => [
    cp_id          => { type => 'integer', not_null => 1, sequence => 'id' },
    cp_cv_id       => { type => 'integer' },
    cp_title       => { type => 'varchar', length => 75 },
    cp_givenname   => { type => 'varchar', length => 75 },
    cp_name        => { type => 'varchar', length => 75 },
    cp_email       => { type => 'text' },
    cp_phone1      => { type => 'varchar', length => 75 },
    cp_phone2      => { type => 'varchar', length => 75 },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
    cp_fax         => { type => 'text' },
    cp_mobile1     => { type => 'text' },
    cp_mobile2     => { type => 'text' },
    cp_satphone    => { type => 'text' },
    cp_satfax      => { type => 'text' },
    cp_project     => { type => 'text' },
    cp_privatphone => { type => 'text' },
    cp_privatemail => { type => 'text' },
    cp_birthday    => { type => 'text' },
    cp_abteilung   => { type => 'text' },
    cp_gender      => { type => 'character', length => 1 },
  ],

  primary_key_columns => [ 'cp_id' ],

  allow_inline_column_values => 1,
);

1;
;
