package SL::Controller::RequirementSpecPart;

use strict;

use parent qw(SL::Controller::Base);

use Carp;
use List::MoreUtils qw(any);

use SL::ClientJS;
use SL::DB::Customer;
use SL::DB::Project;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecPart;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(requirement_spec js) ],
);

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_show {
  my ($self, %params) = @_;

  $self->render('requirement_spec_part/show', { layout => 0 });
}

sub action_ajax_edit {
  my ($self, %params) = @_;

  my $html = $self->render('requirement_spec_part/_edit', { output => 0 });

  $self->js
   ->hide('#additional_parts_list_container')
   ->after('#additional_parts_list_container', $html)
   ->on('#edit_additional_parts_form INPUT[type=text]', 'keydown', 'kivi.requirement_spec.additional_parts_input_key_down')
   ->focus('#additional_parts_add_part_id_name')
   ->run('kivi.requirement_spec.prepare_edit_additional_parts_form')
   ->reinit_widgets
   ->render;
}

sub action_ajax_add {
  my ($self)  = @_;

  my $part      = SL::DB::Part->new(id => $::form->{part_id})->load(with => [ qw(unit_obj) ]);
  my $rs_part   = SL::DB::RequirementSpecPart->new(
    part        => $part,
    qty         => 1,
    unit        => $part->unit_obj,
    description => $part->description,
  );
  my $row       = $self->render('requirement_spec_part/_part', { output => 0 }, part => $rs_part);

  $self->js
   ->val(  '#additional_parts_add_part_id',      '')
   ->val(  '#additional_parts_add_part_id_name', '')
   ->focus('#additional_parts_add_part_id_name')
   ->append('#edit_additional_parts_list tbody', $row)
   ->hide('#edit_additional_parts_list_empty')
   ->show('#edit_additional_parts_list')
   ->render;
}

sub action_ajax_save {
  my ($self) = @_;

  my $db = $self->requirement_spec->db;
  $db->with_transaction(sub {
    # Make Emacs happy
    1;
    my $parts    = $::form->{additional_parts} || [];
    my $position = 1;
    $_->{position} = $position++ for @{ $parts };

    $self->requirement_spec->update_attributes(parts => $parts)->load;
  }) or do {
    return $self->js->error(t8('Saving failed. Error message from the database: #1', $db->error))->render;
  };

  my $html = $self->render('requirement_spec_part/show', { output => 0 }, initially_hidden => !!$::form->{keep_open});

  $self->js
    ->replaceWith('#additional_parts_list_container', $html)
    ->action_if(!$::form->{keep_open}, 'remove', '#additional_parts_form_container')
    ->render;
}

#
# filters
#

sub check_auth {
  my ($self, %params) = @_;
  $::auth->assert('requirement_spec_edit');
}

#
# helpers
#

sub init_js { SL::ClientJS->new(controller => $_[0]) }

sub init_requirement_spec {
  SL::DB::RequirementSpec->new(id => $::form->{requirement_spec_id})->load(
    with_objects => [ qw(parts parts.part parts.unit) ],
  );
}

1;
