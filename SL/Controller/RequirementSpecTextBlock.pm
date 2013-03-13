package SL::Controller::RequirementSpecTextBlock;

use strict;

use parent qw(SL::Controller::Base);

use Time::HiRes ();

use SL::ClientJS;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecPredefinedText;
use SL::DB::RequirementSpecTextBlock;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(requirement_spec text_block) ],
  'scalar --get_set_init' => [ qw(predefined_texts) ],
);

__PACKAGE__->run_before('load_requirement_spec_text_block', only => [qw(ajax_edit ajax_update ajax_delete ajax_flag dragged_and_dropped)]);

#
# actions
#

sub action_ajax_list {
  my ($self) = @_;

  my $result        = { };
  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type});
  my $new_where;

  if ($::form->{clicked_type} =~ m/^text-blocks-(front|back)/) {
    $new_where = $1 eq 'front' ? 0 : 1;

  } else {
    $new_where = $self->output_position_from_id($::form->{clicked_id});
  }

  # $::lxdebug->message(0, "cur $current_where new $new_where");

  my $js = SL::ClientJS->new;

  if (!defined($current_where) || ($new_where != $current_where)) {
    my $text_blocks = SL::DB::Manager::RequirementSpecTextBlock->get_all_sorted(where => [ output_position => $new_where, requirement_spec_id => $::form->{requirement_spec_id} ]);
    my $html        = $self->render('requirement_spec_text_block/ajax_list', { output => 0 }, TEXT_BLOCKS => $text_blocks, output_position => $new_where);

    $js->html('#column-content', $html)
       ->val('#current_content_type', 'text-blocks-' . (0 == $new_where ? 'front' : 'back'))
       ->val('#current_content_id',   $::form->{clicked_id});
  }

  $self->render($js);
}

sub action_ajax_add {
  my ($self) = @_;

  my $js            = SL::ClientJS->new;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type}) // -1;
  my $new_where     = $self->output_position_from_id($::form->{id})                                                  // $::form->{output_position};

  if ($new_where != $current_where) {
    my $text_blocks = SL::DB::Manager::RequirementSpecTextBlock->get_all_sorted(where => [ output_position => $new_where, requirement_spec_id => $::form->{requirement_spec_id} ]);
    my $html        = $self->render('requirement_spec_text_block/ajax_list', { output => 0 }, TEXT_BLOCKS => $text_blocks, output_position => $new_where);

    $js->html('#column-content', $html);
  }

  $self->text_block(SL::DB::RequirementSpecTextBlock->new(
    requirement_spec_id => $::form->{requirement_spec_id},
    output_position     => $::form->{output_position},
  ));

  my $id_base = join('_', 'new_text_block', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $html    = $self->render('requirement_spec_text_block/_form', { output => 0 }, id_base => $id_base, insert_after => $::form->{id});

  $js->action($::form->{id} ? 'insertAfter' : 'appendTo', $html, '#text-block-' . ($::form->{id} || 'list'))
     ->focus('#' . $id_base . '_title')
     ->render($self);
}

sub action_ajax_edit {
  my ($self) = @_;

  my $js = SL::ClientJS->new;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type}) // -1;
  if ($self->text_block->output_position != $current_where) {
    my $text_blocks = $self->text_block->get_full_list;
    my $html        = $self->render('requirement_spec_text_block/ajax_list', { output => 0 }, TEXT_BLOCKS => $text_blocks, output_position => $self->text_block->output_position);

    $js->html('#column-content', $html)
       ->val('#current_content_type', 'text-block')
       ->val('#current_content_id',   $self->text_block->id);
  }

  my $html = $self->render('requirement_spec_text_block/_form', { output => 0 });

  $js->hide('#text-block-' . $self->text_block->id)
     ->remove('#edit_text_block_' . $self->text_block->id . '_form')
     ->insertAfter($html, '#text-block-' . $self->text_block->id)
     ->jstree->select_node('#tree', '#tb-' . $self->text_block->id)
     ->focus('#edit_text_block_' . $self->text_block->id . '_title')
     ->render($self);
}

sub action_ajax_create {
  my ($self, %params) = @_;

  my $attributes   = $::form->{ $::form->{form_prefix} } || die "Missing attributes";
  my $insert_after = delete $attributes->{insert_after};

  my @errors = $self->text_block(SL::DB::RequirementSpecTextBlock->new(%{ $attributes }))->validate;
  return SL::ClientJS->new->error(@errors)->render($self) if @errors;

  $self->text_block->save;
  $self->text_block->add_to_list(position => 'after', reference => $insert_after) if $insert_after;

  my $html = $self->render('requirement_spec_text_block/_text_block', { output => 0 }, text_block => $self->text_block);
  my $node = $self->presenter->requirement_spec_text_block_jstree_data($self->text_block);

  SL::ClientJS->new
    ->replaceWith('#' . $::form->{form_prefix} . '_form', $html)
    ->jstree->create_node('#tree', $insert_after ? ('#tb-' . $insert_after, 'after') : ('#tb-' . ($attributes->{output_position} == 0 ? 'front' : 'back'), 'last'), $node)
    ->render($self);
}

sub action_ajax_update {
  my ($self, %params) = @_;

  my $prefix     = $::form->{form_prefix} || 'text_block';
  my $attributes = $::form->{$prefix}     || {};

  foreach (qw(requirement_spec_id output_position position)) {
    delete $attributes->{$_} if !defined $attributes->{$_};
  }

  my @errors = $self->text_block->assign_attributes(%{ $attributes })->validate;
  return SL::ClientJS->new->error(@errors)->render($self) if @errors;

  $self->text_block->save;

  my $html = $self->render('requirement_spec_text_block/_text_block', { output => 0 }, text_block => $self->text_block);

  SL::ClientJS->new
    ->remove('#' . $prefix . '_form')
    ->replaceWith('#text-block-' . $self->text_block->id, $html)
    ->jstree->rename_node('#tree', '#tb-' . $self->text_block->id, $self->text_block->title)
    ->render($self);
}

sub action_ajax_delete {
  my ($self) = @_;

  my $js = SL::ClientJS->new;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type}) // -1;
  if ($self->text_block->output_position == $current_where) {
    $js->remove('#edit_text_block_' . $self->text_block->id . '_form')
       ->remove('#text-block-' . $self->text_block->id);

    $js->show('#text-block-list-empty') if 1 == scalar @{ $self->text_block->get_full_list };
  }

  $self->text_block->delete;

  $js->jstree->delete_node('#tree', '#tb-' . $self->text_block->id)
     ->render($self);
}

sub action_ajax_flag {
  my ($self) = @_;

  $self->text_block->update_attributes(is_flagged => !$self->text_block->is_flagged);

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type});

  SL::ClientJS->new
   ->action_if($current_where == $self->text_block->output_position, 'toggleClass', '#text-block-' . $self->text_block->id, 'flagged')
   ->toggleClass('#tb-' . $self->text_block->id, 'flagged')
   ->render($self);
}

sub action_dragged_and_dropped {
  my ($self)       = @_;

  my $position           = $::form->{position} =~ m/^ (?: before | after | last ) $/x ? $::form->{position}                                                      : die "Unknown 'position' parameter";
  my $dropped_text_block = $position           =~ m/^ (?: before | after ) $/x        ? SL::DB::RequirementSpecTextBlock->new(id => $::form->{dropped_id})->load : undef;

  my $dropped_type       = $position ne 'last' ? undef : $::form->{dropped_type} =~ m/^ text-blocks- (?:front|back) $/x ? $::form->{dropped_type} : die "Unknown 'dropped_type' parameter";
  my $old_where          = $self->text_block->output_position;

  $self->text_block->db->do_transaction(sub {
    1;
    $self->text_block->remove_from_list;
    $self->text_block->output_position($position =~ m/before|after/ ? $dropped_text_block->output_position : $::form->{dropped_type} eq 'text-blocks-front' ? 0 : 1);
    $self->text_block->add_to_list(position => $position, reference => $dropped_text_block ? $dropped_text_block->id : undef);
  });

  # $::lxdebug->dump(0, "form", $::form);

  return $self->render(\'', { type => 'json' }) if $::form->{current_content_type} !~ m/^text-block/;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type}) // -1;
  my $new_where     = $self->text_block->output_position;
  my $id            = $self->text_block->id;
  my $js            = SL::ClientJS->new;

  # $::lxdebug->message(0, "old $old_where current $current_where new $new_where current_CID " . $::form->{current_content_id} . ' selfid ' . $self->text_block->id);
  if (($old_where != $new_where) && ($::form->{current_content_id} == $self->text_block->id)) {
    # The currently selected text block is dragged to the opposite
    # text block location. Re-render the whole content column.
    my $text_blocks = SL::DB::Manager::RequirementSpecTextBlock->get_all_sorted(where => [ output_position => $new_where ]);
    my $html        = $self->render('requirement_spec_text_block/ajax_list', { output => 0 }, TEXT_BLOCKS => $text_blocks, output_position => $new_where);

    $js->val('#current_content_type', 'text-blocks-' . ($new_where == 0 ? 'front' : 'back'))
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
        $js->prependTo($html, '#text-block-list');
      }
    }
  }

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

  if ($type) {
    return $1 eq 'front' ? 0 : 1 if $type =~ m/-(front|back)$/;
    return undef                 if $type !~ m/text-block/;
  }

  my $text_block = $id ? SL::DB::Manager::RequirementSpecTextBlock->find_by(id => $id) : undef;

  return $text_block ? $text_block->output_position : undef;
}

sub init_predefined_texts {
  return SL::DB::Manager::RequirementSpecPredefinedText->get_all_sorted;
}

1;
