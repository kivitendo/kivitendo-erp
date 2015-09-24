# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PriceRuleItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('price_rule_items');

__PACKAGE__->meta->columns(
  custom_variable_configs_id => { type => 'integer' },
  id                         => { type => 'serial', not_null => 1 },
  itime                      => { type => 'timestamp' },
  mtime                      => { type => 'timestamp' },
  op                         => { type => 'text' },
  price_rules_id             => { type => 'integer', not_null => 1 },
  type                       => { type => 'text' },
  value_date                 => { type => 'date' },
  value_int                  => { type => 'integer' },
  value_num                  => { type => 'numeric', precision => 15, scale => 5 },
  value_text                 => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  custom_variable_configs => {
    class       => 'SL::DB::CustomVariableConfig',
    key_columns => { custom_variable_configs_id => 'id' },
  },

  price_rules => {
    class       => 'SL::DB::PriceRule',
    key_columns => { price_rules_id => 'id' },
  },
);

1;
;
