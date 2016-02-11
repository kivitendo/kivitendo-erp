# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Shipto;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('shipto');

__PACKAGE__->meta->columns(
  itime              => { type => 'timestamp', default => 'now()' },
  module             => { type => 'text' },
  mtime              => { type => 'timestamp' },
  shipto_id          => { type => 'integer', not_null => 1, sequence => 'id' },
  shiptocity         => { type => 'text' },
  shiptocontact      => { type => 'text' },
  shiptocountry      => { type => 'text' },
  shiptocp_gender    => { type => 'text' },
  shiptodepartment_1 => { type => 'text' },
  shiptodepartment_2 => { type => 'text' },
  shiptoemail        => { type => 'text' },
  shiptofax          => { type => 'text' },
  shiptogln          => { type => 'text' },
  shiptoname         => { type => 'text' },
  shiptophone        => { type => 'text' },
  shiptostreet       => { type => 'text' },
  shiptozipcode      => { type => 'text' },
  trans_id           => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'shipto_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
