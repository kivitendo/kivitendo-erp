package SL::Controller::RequirementSpecTextBlock;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecTextBlock;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec text_block) ],
);

# __PACKAGE__->run_before('load_requirement_spec');
__PACKAGE__->run_before('load_requirement_spec_text_block', only => [qw(dragged_and_dropped)]);

#
# actions
#

sub action_dragged_and_dropped {
  my ($self)       = @_;

  $::lxdebug->dump(0, "form", $::form);

  my $position           = $::form->{position} =~ m/^ (?: before | after | last ) $/x ? $::form->{position}                                                      : die "Unknown 'position' parameter";
  my $dropped_text_block = $position           =~ m/^ (?: before | after ) $/x        ? SL::DB::RequirementSpecTextBlock->new(id => $::form->{dropped_id})->load : undef;

  my $dropped_type       = $position ne 'last' ? undef : $::form->{dropped_type} =~ m/^ textblocks- (?:front|back) $/x ? $::form->{dropped_type} : die "Unknown 'dropped_type' parameter";

  $self->text_block->db->do_transaction(sub {
    1;
    $self->text_block->remove_from_list;
    $self->text_block->output_position($position =~ m/before|after/ ? $dropped_text_block->output_position : $::form->{dropped_type} eq 'textblocks-front' ? 0 : 1);
    $self->text_block->add_to_list(position => $position, reference => $dropped_text_block ? $dropped_text_block->id : undef);
  });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub load_requirement_spec {
  my ($self) = @_;
  $self->requirement_spec(SL::DB::RequirementSpec->new(id => $::form->{requirement_spec_id})->load || die "No such requirement spec");
}

sub load_requirement_spec_text_block {
  my ($self) = @_;
  $self->text_block(SL::DB::RequirementSpecTextBlock->new(id => $::form->{id})->load || die "No such requirement spec text block");
}

#
# helpers
#

1;
