package SL::DB::RecordTemplate;

use strict;

use SL::DB::MetaSetup::RecordTemplate;
use SL::DB::Manager::RecordTemplate;

__PACKAGE__->meta->add_relationship(
  record_template_items => {
    type       => 'one to many',
    class      => 'SL::DB::RecordTemplateItem',
    column_map => { id => 'record_template_id' },
  },
);

__PACKAGE__->meta->initialize;

sub items { goto &record_template_items; }

1;
