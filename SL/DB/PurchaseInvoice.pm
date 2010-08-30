package SL::DB::PurchaseInvoice;

use strict;

use SL::DB::MetaSetup::PurchaseInvoice;
use SL::DB::Manager::PurchaseInvoice;

for my $field (qw(transdate gldate datepaid duedate orddate quodate)) {
  __PACKAGE__->attr_date($field);
}

__PACKAGE__->meta->add_relationship(invoiceitems => { type         => 'one to many',
                                                      class        => 'SL::DB::InvoiceItem',
                                                      column_map   => { id => 'trans_id' },
                                                      manager_args => { with_objects => [ 'part' ] }
                                                    },
                                   );

__PACKAGE__->meta->initialize;

1;
