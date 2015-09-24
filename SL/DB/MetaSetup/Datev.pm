# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Datev;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('datev');

__PACKAGE__->meta->columns(
  abrechnungsnr  => { type => 'varchar', length => 6 },
  beratername    => { type => 'varchar', length => 9 },
  beraternr      => { type => 'varchar', length => 7 },
  datentraegernr => { type => 'varchar', length => 3 },
  dfvkz          => { type => 'varchar', length => 2 },
  id             => { type => 'serial', not_null => 1 },
  itime          => { type => 'timestamp', default => 'now()' },
  mandantennr    => { type => 'varchar', length => 5 },
  mtime          => { type => 'timestamp' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
