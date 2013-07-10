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
use SL::JSON;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(parts) ],
);

# safety
__PACKAGE__->run_before(sub { $::auth->assert('part_service_assembly_edit') });

__PACKAGE__->make_filtered(
  ONLY          => [ qw(part_picker_search part_picker_result ajax_autocomplete) ],
  LAUNDER_TO    => 'filter',
);
__PACKAGE__->make_paginated(
  ONLY          => [ qw(part_picker_search part_picker_result ajax_autocomplete) ],
);

__PACKAGE__->make_sorted(
  ONLY              => [ qw(part_picker_search part_picker_result ajax_autocomplete) ],

  DEFAULT_BY        => 'partnumber',
  DEFAULT_DIR       => 1,

  partnumber        => t8('Partnumber'),
);

sub action_ajax_autocomplete {
  my ($self, %params) = @_;

  my $value = $::form->{column} || 'description';

  # if someone types something, and hits enter, assume he entered the full name.
  # if something matches, treat that as sole match
  if ($::form->{prefer_exact}) {
    # TODO!
  }

  my @hashes = map {
   +{
     value       => $_->$value,
     label       => $_->long_description,
     id          => $_->id,
     partnumber  => $_->partnumber,
     description => $_->description,
     type        => $_->type,
    }
  } @{ $self->parts };

  $self->render(\ SL::JSON::to_json(\@hashes), { layout => 0, type => 'json', process => 0 });
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
