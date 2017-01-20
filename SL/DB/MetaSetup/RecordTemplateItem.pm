# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RecordTemplateItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('record_template_items');

__PACKAGE__->meta->columns(
  amount1            => { type => 'numeric', not_null => 1, precision => 15, scale => 5 },
  amount2            => { type => 'numeric', precision => 15, scale => 5 },
  chart_id           => { type => 'integer', not_null => 1 },
  id                 => { type => 'serial', not_null => 1 },
  memo               => { type => 'text' },
  project_id         => { type => 'integer' },
  record_template_id => { type => 'integer', not_null => 1 },
  source             => { type => 'text' },
  tax_id             => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  chart => {
    class       => 'SL::DB::Chart',
    key_columns => { chart_id => 'id' },
  },

  project => {
    class       => 'SL::DB::Project',
    key_columns => { project_id => 'id' },
  },

  record_template => {
    class       => 'SL::DB::RecordTemplate',
    key_columns => { record_template_id => 'id' },
  },

  tax => {
    class       => 'SL::DB::Tax',
    key_columns => { tax_id => 'id' },
  },
);

1;
;
