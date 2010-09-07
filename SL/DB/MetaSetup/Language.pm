# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Language;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'language',

  columns => [
    id                  => { type => 'integer', not_null => 1, sequence => 'id' },
    description         => { type => 'text' },
    template_code       => { type => 'text' },
    article_code        => { type => 'text' },
    itime               => { type => 'timestamp', default => 'now()' },
    mtime               => { type => 'timestamp' },
    output_numberformat => { type => 'text' },
    output_dateformat   => { type => 'text' },
    output_longdates    => { type => 'boolean' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
