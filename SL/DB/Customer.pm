package SL::DB::Customer;

use strict;

use SL::DB::MetaSetup::Customer;
use SL::DB::Manager::Customer;
use SL::DB::Helper::TransNumberGenerator;
use SL::DB::Helper::CustomVariables (
  module      => 'CT',
  cvars_alias => 1,
);

use SL::DB::VC;

__PACKAGE__->meta->add_relationship(
  shipto => {
    type         => 'one to many',
    class        => 'SL::DB::Shipto',
    column_map   => { id      => 'trans_id' },
    manager_args => { sort_by => 'lower(shipto.shiptoname)' },
    query_args   => [ module   => 'CT' ],
  },
  contacts => {
    type         => 'one to many',
    class        => 'SL::DB::Contact',
    column_map   => { id      => 'cp_cv_id' },
    manager_args => { sort_by => 'lower(contacts.cp_name)' },
  },
  business => {
    type         => 'one to one',
    class        => 'SL::DB::Business',
    column_map   => { business_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_set_customernumber');

sub _before_save_set_customernumber {
  my ($self) = @_;

  $self->create_trans_number if $self->customernumber eq '';
  return 1;
}

sub short_address {
  my ($self) = @_;

  return join ', ', grep { $_ } $self->street, $self->zipcode, $self->city;
}

1;
