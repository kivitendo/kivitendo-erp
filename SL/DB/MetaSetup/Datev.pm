# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Datev;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'datev',

  columns => [
    beraternr      => { type => 'varchar', length => 7 },
    beratername    => { type => 'varchar', length => 9 },
    mandantennr    => { type => 'varchar', length => 5 },
    dfvkz          => { type => 'varchar', length => 2 },
    datentraegernr => { type => 'varchar', length => 3 },
    abrechnungsnr  => { type => 'varchar', length => 6 },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
    id             => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
