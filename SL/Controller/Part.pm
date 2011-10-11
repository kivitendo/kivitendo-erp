package SL::Controller::Part;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Part;

# safety
__PACKAGE__->run_before(sub { $::auth->assert('part_service_assembly_edit') });

sub action_ajax_autocomplete {
  my ($self, %params) = @_;

  my $limit  = $::form->{limit}  || 20;
  my $type   = $::form->{type} || {};
  my $query  = { ilike => "%$::form->{term}%" };
  my @filter;
  push @filter, SL::DB::Manager::Part->type_filter($type);
  push @filter, ($::form->{column})
    ? ($::form->{column} => $query)
    : (or => [ partnumber => $query, description => $query ]);

  $self->{parts} = SL::DB::Manager::Part->get_all(query => [ @filter ], limit => $limit);
  $self->{value} = $::form->{column} || 'description';

  $self->render('part/ajax_autocomplete', { no_layout => 1 });
}


1;
