package SL::Controller::Customer;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Customer;

# safety
__PACKAGE__->run_before(sub { $::auth->assert('customer_vendor_edit') });

sub action_ajax_autocomplete {
  my ($self, %params) = @_;

  my $limit  = $::form->{limit}  || 20;
  my $type   = $::form->{type} || {};
  my $query  = { ilike => "%$::form->{term}%" };
  my @filter;
  push @filter, ($::form->{column})
    ? ($::form->{column} => $query)
    : (or => [ customernumber => $query, name => $query ]);

  $self->{customers} = SL::DB::Manager::Customer->get_all(query => [ @filter ], limit => $limit);
  $self->{value} = $::form->{column} || 'name';

  $self->render('ct/ajax_autocomplete2', { no_layout => 1 });
}

