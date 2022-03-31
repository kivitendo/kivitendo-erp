# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Language;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('language');

__PACKAGE__->meta->columns(
  article_code        => { type => 'text' },
  description         => { type => 'text' },
  id                  => { type => 'integer', not_null => 1, sequence => 'id' },
  itime               => { type => 'timestamp', default => 'now()' },
  mtime               => { type => 'timestamp' },
  obsolete            => { type => 'boolean', default => 'false' },
  output_dateformat   => { type => 'text' },
  output_longdates    => { type => 'boolean' },
  output_numberformat => { type => 'text' },
  template_code       => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
