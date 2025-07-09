package SL::DB::PeriodicInvoice;

use strict;

use SL::DB::MetaSetup::PeriodicInvoice;
use SL::DB::Manager::PeriodicInvoice;

__PACKAGE__->meta->add_relationships(
  invoice      => {
    type       => 'many to one',
    class      => 'SL::DB::Invoice',
    column_map => { ar_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

1;
