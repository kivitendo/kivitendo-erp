package SL::Controller::Part;

use strict;
use parent qw(SL::Controller::Base);

use Clone qw(clone);
use SL::DB::Part;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Filtered;
use SL::Controller::Helper::Sorted;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Filtered;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(parts) ],
);

# safety
__PACKAGE__->run_before(sub { $::auth->assert('part_service_assembly_edit') });

__PACKAGE__->make_filtered(
  ONLY          => [ qw(part_picker_search part_picker_result) ],
  LAUNDER_TO    => 'filter',
);
__PACKAGE__->make_paginated(
  ONLY          => [ qw(part_picker_search part_picker_result) ],
);

__PACKAGE__->make_sorted(
  ONLY              => [ qw(part_picker_search part_picker_result) ],

  DEFAULT_BY        => 'partnumber',
  DEFAULT_DIR       => 1,

  partnumber        => t8('Partnumber'),
);

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

  $self->render('part/ajax_autocomplete', { layout => 0, type => 'json' });
}

sub action_test_page {
  $::request->{layout}->add_javascripts('autocomplete_part.js');

  $_[0]->render('part/test_page');
}

sub action_part_picker_search {
  $_[0]->render('part/part_picker_search', { layout => 0 }, parts => $_[0]->parts);
}

sub action_part_picker_result {
  $_[0]->render('part/_part_picker_result', { layout => 0 });
}

sub init_parts {
  $_[0]->get_models;
}

1;
