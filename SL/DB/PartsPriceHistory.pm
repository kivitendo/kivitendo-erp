package SL::DB::PartsPriceHistory;

use strict;

use SL::DB::MetaSetup::PartsPriceHistory;
use SL::DB::Manager::PartsPriceHistory;

__PACKAGE__->meta->add_relationships(
  part_label_prints => {
    type         => 'many to one',
    class        => 'SL::DB::PartLabelPrint',
    column_map   => { id => 'price_history_id' },
  },
);

__PACKAGE__->meta->initialize;

1;
