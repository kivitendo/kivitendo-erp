package SL::DB::Pricegroup;

use strict;

use SL::DB::MetaSetup::Pricegroup;
use SL::DB::Manager::Pricegroup;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;
__PACKAGE__->before_save('_before_save_remove_customer_pricegroup');

sub displayable_name {
  my $self = shift;

  return join ' ', grep $_, $self->id, $self->pricegroup;
}

sub _before_save_remove_customer_pricegroup {
  my ($self) = @_;

  return 1 unless $::form->{SELF}{remove_customer_pricegroup};

  my %attributes          = (pricegroup_id => undef);
  require SL::DB::Customer;
  SL::DB::Manager::Customer->update_all(
    set   => \%attributes,
    where => [
      'pricegroup_id' => $self->id,
    ],
  );

  return 1;
}

sub validate {
  my ($self) = @_;
  require SL::DB::Customer;

  my @errors;
  if (!$::form->{SELF}{remove_customer_pricegroup}                                    &&
      $self->obsolete                                                                 &&
      SL::DB::Manager::Customer->get_all_count(query => [ pricegroup_id => $self->id ]) ) {
      push @errors, $::locale->text('The pricegroup is being used by customers.');
  }

  return @errors;
}

sub orphaned {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  return 1 unless $self->id;

  my @relations = qw(
    SL::DB::Customer
    SL::DB::Price
  );

  # check if pricegroup is the default pricegroup for any customers and has any
  # prices assigned.

  for my $class (@relations) {
    eval "require $class";
    return 0 if $class->_get_manager_class->get_all_count(query => [ pricegroup_id => $self->id ]);
  }

  # check if pricegroup was used in any pricesource
  my @item_relations = qw(
    SL::DB::OrderItem
    SL::DB::DeliveryOrderItem
    SL::DB::InvoiceItem
  );

  for my $class (@item_relations) {
    eval "require $class";
    return 0 if $class->_get_manager_class->get_all_count(query => [ active_price_source => 'pricegroup/' . $self->id ]);
  }

  eval "require SL::DB::PriceRuleItem";
  return 0 if SL::DB::Manager::PriceRuleItem->get_all_count(query => [ type => 'pricegroup', value_int => $self->id ]);

  return 1;
}

1;
