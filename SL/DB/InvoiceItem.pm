package SL::DB::InvoiceItem;

use strict;

use SL::DB::MetaSetup::InvoiceItem;
use SL::DB::Manager::InvoiceItem;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::RecordItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'invoice',
  cvars_alias => 1,
  overloads   => {
    parts_id => {
     class => 'SL::DB::Part',
     module => 'IC',
    },
  },
);
use Rose::DB::Object::Helpers qw(as_tree strip);

__PACKAGE__->configure_acts_as_list(group_by => [qw(trans_id)]);

__PACKAGE__->meta->add_relationships(
  invoice          => {
    type           => 'one to one',
    class          => 'SL::DB::Invoice',
    column_map     => { trans_id => 'id' },
  },

  purchase_invoice => {
    type           => 'one to one',
    class          => 'SL::DB::PurchaseInvoice',
    column_map     => { trans_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('longdescription');

sub record {
  my ($self) = @_;

  return $self->invoice          if $self->invoice;
  return $self->purchase_invoice if $self->purchase_invoice;
  return;
};

1;
