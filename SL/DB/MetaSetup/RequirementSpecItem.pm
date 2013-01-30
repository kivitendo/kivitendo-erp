# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecItem;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'requirement_spec_items',

  columns => [
    id                   => { type => 'serial', not_null => 1 },
    requirement_spec_id  => { type => 'integer', not_null => 1 },
    parent_id            => { type => 'integer' },
    position             => { type => 'integer', not_null => 1 },
    fb_number            => { type => 'text', not_null => 1 },
    title                => { type => 'text' },
    description          => { type => 'text' },
    complexity_id        => { type => 'integer' },
    risk_id              => { type => 'integer' },
    time_estimation      => { type => 'numeric', default => '0', not_null => 1, precision => 2, scale => 12 },
    net_sum              => { type => 'numeric', default => '0', not_null => 1, precision => 2, scale => 12 },
    is_flagged           => { type => 'boolean', default => 'false', not_null => 1 },
    acceptance_status_id => { type => 'integer' },
    acceptance_text      => { type => 'text' },
    itime                => { type => 'timestamp', default => 'now()', not_null => 1 },
    mtime                => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    acceptance_status => {
      class       => 'SL::DB::RequirementSpecAcceptanceStatus',
      key_columns => { acceptance_status_id => 'id' },
    },

    complexity => {
      class       => 'SL::DB::RequirementSpecComplexity',
      key_columns => { complexity_id => 'id' },
    },

    parent => {
      class       => 'SL::DB::RequirementSpecItem',
      key_columns => { parent_id => 'id' },
    },
  ],

  relationships => [
    depended_items => {
      map_class => 'SL::DB::RequirementSpecDependency',
      map_from  => 'depending_item',
      map_to    => 'depended_item',
      type      => 'many to many',
    },

    depending_items => {
      map_class => 'SL::DB::RequirementSpecDependency',
      map_from  => 'depended_item',
      map_to    => 'depending_item',
      type      => 'many to many',
    },
  ],
);

1;
;
