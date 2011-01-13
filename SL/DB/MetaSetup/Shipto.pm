# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Shipto;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'shipto',

  columns => [
    trans_id           => { type => 'integer' },
    shiptoname         => { type => 'varchar', length => 75 },
    shiptodepartment_1 => { type => 'varchar', length => 75 },
    shiptodepartment_2 => { type => 'varchar', length => 75 },
    shiptostreet       => { type => 'varchar', length => 75 },
    shiptozipcode      => { type => 'varchar', length => 75 },
    shiptocity         => { type => 'varchar', length => 75 },
    shiptocountry      => { type => 'varchar', length => 75 },
    shiptocontact      => { type => 'varchar', length => 75 },
    shiptophone        => { type => 'varchar', length => 30 },
    shiptofax          => { type => 'varchar', length => 30 },
    shiptoemail        => { type => 'text' },
    itime              => { type => 'timestamp', default => 'now()' },
    mtime              => { type => 'timestamp' },
    module             => { type => 'text' },
    shipto_id          => { type => 'integer', not_null => 1, sequence => 'id' },
    shiptocp_gender    => { type => 'text' },
  ],

  primary_key_columns => [ 'shipto_id' ],

  allow_inline_column_values => 1,
);

1;
;
