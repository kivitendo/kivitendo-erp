# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('requirement_spec_items');

__PACKAGE__->meta->columns(
  acceptance_status_id => { type => 'integer' },
  acceptance_text      => { type => 'text' },
  complexity_id        => { type => 'integer' },
  description          => { type => 'text' },
  fb_number            => { type => 'text', not_null => 1 },
  id                   => { type => 'serial', not_null => 1 },
  is_flagged           => { type => 'boolean', default => 'false', not_null => 1 },
  item_type            => { type => 'text', not_null => 1 },
  itime                => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime                => { type => 'timestamp' },
  order_part_id        => { type => 'integer' },
  parent_id            => { type => 'integer' },
  position             => { type => 'integer', not_null => 1 },
  requirement_spec_id  => { type => 'integer', not_null => 1 },
  risk_id              => { type => 'integer' },
  sellprice_factor     => { type => 'numeric', default => 1, precision => 10, scale => 5 },
  time_estimation      => { type => 'numeric', default => '0', not_null => 1, precision => 12, scale => 2 },
  title                => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  acceptance_status => {
    class       => 'SL::DB::RequirementSpecAcceptanceStatus',
    key_columns => { acceptance_status_id => 'id' },
  },

  complexity => {
    class       => 'SL::DB::RequirementSpecComplexity',
    key_columns => { complexity_id => 'id' },
  },

  order_part => {
    class       => 'SL::DB::Part',
    key_columns => { order_part_id => 'id' },
  },

  parent => {
    class       => 'SL::DB::RequirementSpecItem',
    key_columns => { parent_id => 'id' },
  },

  requirement_spec => {
    class       => 'SL::DB::RequirementSpec',
    key_columns => { requirement_spec_id => 'id' },
  },

  risk => {
    class       => 'SL::DB::RequirementSpecRisk',
    key_columns => { risk_id => 'id' },
  },
);

1;
;
