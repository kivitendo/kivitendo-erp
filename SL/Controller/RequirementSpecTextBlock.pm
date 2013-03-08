package SL::Controller::RequirementSpecTextBlock;

use strict;

use parent qw(SL::Controller::Base);

use SL::ClientJS;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecTextBlock;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(requirement_spec text_block) ],
);

__PACKAGE__->run_before('load_requirement_spec_text_block', only => [qw(dragged_and_dropped)]);

#
# actions
#

sub action_ajax_list {
  my ($self) = @_;

  my $result        = { };
  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type});
  my $new_where;

  if ($::form->{clicked_type} =~ m/^textblocks-(front|back)/) {
    $new_where = $1 eq 'front' ? 0 : 1;

  } else {
    $new_where = $self->output_position_from_id($::form->{clicked_id});
  }

  # $::lxdebug->message(0, "cur $current_where new $new_where");

  my $js = SL::ClientJS->new;

  if (!defined($current_where) || ($new_where != $current_where)) {
    my $text_blocks = SL::DB::Manager::RequirementSpecTextBlock->get_all_sorted(where => [ output_position => $new_where ]);
    my $html        = $self->render('requirement_spec_text_block/ajax_list', { output => 0 }, TEXT_BLOCKS => $text_blocks, output_position => $new_where, nownow => DateTime->now_local);

    $js->html('#column-content', $html)
  }

  $self->render($js);
}

sub action_dragged_and_dropped {
  my ($self)       = @_;

  my $position           = $::form->{position} =~ m/^ (?: before | after | last ) $/x ? $::form->{position}                                                      : die "Unknown 'position' parameter";
  my $dropped_text_block = $position           =~ m/^ (?: before | after ) $/x        ? SL::DB::RequirementSpecTextBlock->new(id => $::form->{dropped_id})->load : undef;

  my $dropped_type       = $position ne 'last' ? undef : $::form->{dropped_type} =~ m/^ textblocks- (?:front|back) $/x ? $::form->{dropped_type} : die "Unknown 'dropped_type' parameter";
  my $old_where          = $self->text_block->output_position;

  $self->text_block->db->do_transaction(sub {
    1;
    $self->text_block->remove_from_list;
    $self->text_block->output_position($position =~ m/before|after/ ? $dropped_text_block->output_position : $::form->{dropped_type} eq 'textblocks-front' ? 0 : 1);
    $self->text_block->add_to_list(position => $position, reference => $dropped_text_block ? $dropped_text_block->id : undef);
  });

  return $self->render(\'', { type => 'json' }) if $::form->{current_content_type} !~ m/^textblock/;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type});
  my $new_where     = $self->text_block->output_position;
  my $id            = $self->text_block->id;
  my $js            = SL::ClientJS->new;

  # $::lxdebug->message(0, "old $old_where current $current_where new $new_where current_CID " . $::form->{current_content_id} . ' selfid ' . $self->text_block->id);
  if (($old_where != $new_where) && ($::form->{current_content_id} == $self->text_block->id)) {
    # The currently selected text block is dragged to the opposite
    # text block location. Re-render the whole content column.
    my $text_blocks = SL::DB::Manager::RequirementSpecTextBlock->get_all_sorted(where => [ output_position => $new_where ]);
    my $html        = $self->render('requirement_spec_text_block/ajax_list', { output => 0 }, TEXT_BLOCKS => $text_blocks, output_position => $new_where);

    $js->val('#current_content_type', 'textblocks-' . ($new_where == 0 ? 'front' : 'back'))
       ->html('#column-content', $html);

  } else {
    if ($old_where == $current_where) {
      $js->remove('#text-block-' . $self->text_block->id);

      if (0 == scalar(@{ SL::DB::Manager::RequirementSpecTextBlock->get_all(where => [ requirement_spec_id => $self->text_block->requirement_spec_id, output_position => $current_where ]) })) {
        $js->show('#text-block-list-empty');
      }
    }

    if ($new_where == $current_where) {
      $js->hide('#text-block-list-empty');

      my $html             = "" . $self->render('requirement_spec_text_block/_text_block', { output => 0 }, text_block => $self->text_block);
      $html                =~ s/^\s+//;
      my $prior_text_block = $self->text_block->get_previous_in_list;

      if ($prior_text_block) {
        $js->insertAfter($html, '#text-block-' . $prior_text_block->id);
      } else {
        $js->appendTo($html, '#text-block-list');
      }
    }
  }

  $::lxdebug->message(0, "old $old_where current $current_where new $new_where");

  $::lxdebug->dump(0, "actions", $js);

  $self->render($js);
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

sub output_position_from_id {
  my ($self, $id, $type, %params) = @_;

  if (!$id) {
    return $params{default} unless $type =~ m/-(front|back)/;
    return $1 eq 'front' ? 0 : 1;
  }

  my $text_block = SL::DB::Manager::RequirementSpecTextBlock->find_by(id => $id);

  return $params{default}             unless $text_block;
  return $text_block->output_position unless $params{as} eq 'text';
  return 1 == $text_block->output_position ? 'front' : 'back';
}

1;
