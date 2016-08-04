package SL::DB::Customer;

use strict;

use Rose::DB::Object::Helpers qw(as_tree);

use SL::DB::MetaSetup::Customer;
use SL::DB::Manager::Customer;
use SL::DB::Helper::IBANValidation;
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
);

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_set_customernumber');

sub _before_save_set_customernumber {
  my ($self) = @_;

  $self->create_trans_number if !defined $self->customernumber || $self->customernumber eq '';
  return 1;
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The customer name is missing.') if !$self->name;
  push @errors, $self->validate_ibans;

  return @errors;
}

sub short_address {
  my ($self) = @_;

  return join ', ', grep { $_ } $self->street, $self->zipcode, $self->city;
}

sub displayable_name {
  my $self = shift;

  return join ' ', grep $_, $self->customernumber, $self->name;
}

sub is_customer { 1 };
sub is_vendor   { 0 };
sub payment_terms { goto &payment }
sub number { goto &customernumber }

1;
