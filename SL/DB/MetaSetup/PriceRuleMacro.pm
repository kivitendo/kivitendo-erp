# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PriceRuleMacro;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('price_rule_macros');

__PACKAGE__->meta->columns(
  id              => { type => 'serial', not_null => 1 },
  itime           => { type => 'timestamp' },
  json_definition => { type => 'scalar', not_null => 1 },
  mtime           => { type => 'timestamp' },
  name            => { type => 'text', not_null => 1 },
  obsolete        => { type => 'boolean', default => 'false', not_null => 1 },
  priority        => { type => 'integer', default => 3, not_null => 1 },
  type            => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
