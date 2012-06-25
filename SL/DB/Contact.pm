# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Contact;

use strict;

use SL::DB::MetaSetup::Contact;
use SL::DB::Helper::CustomVariables (
  module      => 'Contacts',
  cvars_alias => 1,
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

sub used {
  my ($self) = @_;

  return unless $self->cp_id;

  require SL::DB::Order;
  require SL::DB::Invoice;
  require SL::DB::PurchaseInvoice;
  require SL::DB::DeliveryOrder;

  return SL::DB::Manager::Order->get_all_count(query => [ cp_id => $self->cp_id ])
       + SL::DB::Manager::Invoice->get_all_count(query => [ cp_id => $self->cp_id ])
       + SL::DB::Manager::PurchaseInvoice->get_all_count(query => [ cp_id => $self->cp_id ])
       + SL::DB::Manager::DeliveryOrder->get_all_count(query => [ cp_id => $self->cp_id ]);
}

sub detach {
  $_[0]->cp_cv_id(undef);
  $_[0];
}

sub full_name {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;
  join ', ', grep $_, $self->cp_name, $self->cp_givenname;
}

sub full_name_dep {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;
  $self->full_name
    . join '', map { " ($_)" } grep $_, $self->cp_abteilung;
}

1;
