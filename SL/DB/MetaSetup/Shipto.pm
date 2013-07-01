# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Shipto;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('shipto');

__PACKAGE__->meta->columns(
  itime              => { type => 'timestamp', default => 'now()' },
  module             => { type => 'text' },
  mtime              => { type => 'timestamp' },
  shipto_id          => { type => 'integer', not_null => 1, sequence => 'id' },
  shiptocity         => { type => 'varchar', length => 75 },
  shiptocontact      => { type => 'varchar', length => 75 },
  shiptocountry      => { type => 'varchar', length => 75 },
  shiptocp_gender    => { type => 'text' },
  shiptodepartment_1 => { type => 'varchar', length => 75 },
  shiptodepartment_2 => { type => 'varchar', length => 75 },
  shiptoemail        => { type => 'text' },
  shiptofax          => { type => 'varchar', length => 30 },
  shiptoname         => { type => 'varchar', length => 75 },
  shiptophone        => { type => 'varchar', length => 30 },
  shiptostreet       => { type => 'varchar', length => 75 },
  shiptozipcode      => { type => 'varchar', length => 75 },
  trans_id           => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'shipto_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
