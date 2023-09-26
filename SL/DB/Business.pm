package SL::DB::Business;

use strict;

use SL::DB::MetaSetup::Business;
use SL::DB::Manager::Business;

__PACKAGE__->meta->add_relationship(
  customers      => {
    type         => 'one to many',
    class        => 'SL::DB::Customer',
    column_map   => { id => 'business_id' },
    query_args   => [ \' id IN ( SELECT id FROM customer ) ' ],
  },
  vendors      => {
    type         => 'one to many',
    class        => 'SL::DB::Vendor',
    column_map   => { id => 'business_id' },
    query_args   => [ \' id IN ( SELECT id FROM vendor ) ' ],
  },
);

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')          if !$self->description;
  push @errors, $::locale->text('The discount must not be negative.')   if $self->discount <  0;
  push @errors, $::locale->text('The discount must be less than 100%.') if $self->discount >= 1;

  return @errors;
}

sub displayable_name {
  my $self = shift;

  return join ' ', grep $_, $self->id, $self->description;
}

sub orphaned {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  return 1 unless $self->id;

  my @relations = qw(
    SL::DB::Customer
    SL::DB::Vendor
    SL::DB::BusinessModel
  );

  for my $class (@relations) {
    eval "require $class";
    return 0 if $class->_get_manager_class->get_all_count(query => [ business_id => $self->id ]);
  }

  eval "require SL::DB::PriceRuleItem";
  return 0 if SL::DB::Manager::PriceRuleItem->get_all_count(query => [ type => 'business', value_int => $self->id ]);

  return 1;
}

1;
