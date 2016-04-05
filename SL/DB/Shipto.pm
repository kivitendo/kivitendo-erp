package SL::DB::Shipto;

use strict;

use SL::DB::MetaSetup::Shipto;
use SL::DB::Manager::Shipto;
use SL::DB::Helper::CustomVariables (
  module      => 'ShipTo',
  cvars_alias => 1,
);

our @SHIPTO_VARIABLES = qw(shiptoname shiptostreet shiptozipcode shiptocity shiptocountry shiptogln shiptocontact
                           shiptophone shiptofax shiptoemail shiptodepartment_1 shiptodepartment_2);

__PACKAGE__->meta->initialize;

sub displayable_id {
  my $self = shift;
  my $text = join('; ', grep { $_ } (map({ $self->$_ } qw(shiptoname shiptostreet)),
                                     join(' ', grep { $_ }
                                               map  { $self->$_ }
                                               qw(shiptozipcode shiptocity))));

  return $text;
}

sub used {
  my ($self) = @_;

  return unless $self->shipto_id;

  require SL::DB::Order;
  require SL::DB::Invoice;
  require SL::DB::DeliveryOrder;

  return SL::DB::Manager::Order->get_all_count(query => [ shipto_id => $self->shipto_id ])
      || SL::DB::Manager::Invoice->get_all_count(query => [ shipto_id => $self->shipto_id ])
      || SL::DB::Manager::DeliveryOrder->get_all_count(query => [ shipto_id => $self->shipto_id ]);
}

sub detach {
  $_[0]->trans_id(undef);
  $_[0];
}

1;
