package SL::Controller::RequirementSpecTextBlock;

use strict;

use parent qw(SL::Controller::Base);

use Carp;
use Params::Validate ();
use Time::HiRes ();

use SL::Clipboard;
use SL::Controller::Helper::RequirementSpec;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecPicture;
use SL::DB::RequirementSpecPredefinedText;
use SL::DB::RequirementSpecTextBlock;
use SL::Helper::Flash;
use SL::Locale::String;

use constant SORTABLE_PICTURE_LIST => 'kivi.requirement_spec.make_text_block_picture_lists_sortable';

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(text_block) ],
  'scalar --get_set_init' => [ qw(predefined_texts picture) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_requirement_spec_text_block', only => [qw(ajax_edit ajax_update ajax_delete ajax_flag dragged_and_dropped ajax_copy ajax_add_picture)]);

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

  $self->show_list(output_position => $new_where, id => $::form->{clicked_id}, set_type => 1) if ($new_where != ($current_where // -1));

  $self->js
    ->run(SORTABLE_PICTURE_LIST())
    ->render($self);
}

sub action_ajax_add {
  my ($self) = @_;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type}) // -1;
  my $new_where     = $self->output_position_from_id($::form->{id})                                                  // $::form->{output_position};

  $self->show_list(output_position => $new_where) if $new_where != $current_where;

  $self->add_new_text_block_form(output_position => $new_where, insert_after_id => $::form->{id}, requirement_spec_id => $::form->{requirement_spec_id});

  $self->invalidate_version->render;
}

sub action_ajax_edit {
  my ($self) = @_;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type}) // -1;

  if ($self->text_block->output_position != $current_where) {
    $self->show_list(output_position => $self->text_block->output_position, id => $self->text_block->id, requirement_spec_id => $self->text_block->requirement_spec_id);
  }

  my $html = $self->render('requirement_spec_text_block/_form', { output => 0 });

  $self->js
     ->hide('#text-block-' . $self->text_block->id)
     ->remove('#edit_text_block_' . $self->text_block->id . '_form')
     ->insertAfter($html, '#text-block-' . $self->text_block->id)
     ->jstree->select_node('#tree', '#tb-' . $self->text_block->id)
     ->focus('#edit_text_block_' . $self->text_block->id . '_title')
     ->reinit_widgets
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
  my $node = $self->text_block->presenter->jstree_data;

  $self->invalidate_version
    ->hide('#text-block-list-empty')
    ->replaceWith('#' . $::form->{form_prefix} . '_form', $html)
    ->run(SORTABLE_PICTURE_LIST())
    ->jstree->create_node('#tree', $insert_after ? ('#tb-' . $insert_after, 'after') : ('#tb-' . ($attributes->{output_position} == 0 ? 'front' : 'back'), 'last'), $node)
    ->jstree->select_node('#tree', '#tb-' . $self->text_block->id);
  $self->add_new_text_block_form(output_position => $self->text_block->output_position, insert_after_id => $self->text_block->id, requirement_spec_id => $self->text_block->requirement_spec_id)
    ->reinit_widgets
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

  $self->invalidate_version
    ->remove('#' . $prefix . '_form')
    ->replaceWith('#text-block-' . $self->text_block->id, $html)
    ->run(SORTABLE_PICTURE_LIST())
    ->jstree->rename_node('#tree', '#tb-' . $self->text_block->id, $self->text_block->title)
    ->prop('#tb-' . $self->text_block->id . ' a', 'title', $self->text_block->content_excerpt)
    ->addClass('#tb-' . $self->text_block->id . ' a', 'tooltip')
    ->reinit_widgets
    ->render($self);
}

sub action_ajax_delete {
  my ($self) = @_;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type}) // -1;
  if ($self->text_block->output_position == $current_where) {
    $self->js
       ->remove('#edit_text_block_' . $self->text_block->id . '_form')
       ->remove('#text-block-' . $self->text_block->id);

    $self->js->show('#text-block-list-empty') if 1 == scalar @{ $self->text_block->get_full_list };
  }

  $self->text_block->delete;

  $self->invalidate_version
     ->jstree->delete_node('#tree', '#tb-' . $self->text_block->id)
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

  $self->text_block->db->with_transaction(sub {
    1;
    $self->text_block->remove_from_list;
    $self->text_block->output_position($position =~ m/before|after/ ? $dropped_text_block->output_position : $::form->{dropped_type} eq 'text-blocks-front' ? 0 : 1);
    $self->text_block->add_to_list(position => $position, reference => $dropped_text_block ? $dropped_text_block->id : undef);
  });

  # $::lxdebug->dump(0, "form", $::form);

  $self->invalidate_version
    ->jstree->open_node('#tree', '#tb-' . (!$self->text_block->output_position ? 'front' : 'back'));

  return $self->js->render($self) if $::form->{current_content_type} !~ m/^text-block/;

  my $current_where = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type}) // -1;
  my $new_where     = $self->text_block->output_position;
  my $id            = $self->text_block->id;

  # $::lxdebug->message(0, "old $old_where current $current_where new $new_where current_CID " . $::form->{current_content_id} . ' selfid ' . $self->text_block->id);
  if (($old_where != $new_where) && ($::form->{current_content_id} == $self->text_block->id)) {
    # The currently selected text block is dragged to the opposite
    # text block location. Re-render the whole content column.
    $self->show_list(output_position => $new_where, id => $id);

  } else {
    if ($old_where == $current_where) {
      $self->js->remove('#text-block-' . $self->text_block->id);

      if (0 == scalar(@{ SL::DB::Manager::RequirementSpecTextBlock->get_all(where => [ requirement_spec_id => $self->text_block->requirement_spec_id, output_position => $current_where ]) })) {
        $self->js->show('#text-block-list-empty');
      }
    }

    if ($new_where == $current_where) {
      $self->js->hide('#text-block-list-empty');

      my $html             = "" . $self->render('requirement_spec_text_block/_text_block', { output => 0 }, text_block => $self->text_block);
      $html                =~ s/^\s+//;
      my $prior_text_block = $self->text_block->get_previous_in_list;

      if ($prior_text_block) {
        $self->js->insertAfter($html, '#text-block-' . $prior_text_block->id);
      } else {
        $self->js->prependTo($html, '#text-block-list');
      }
    }
  }

  $self->js
    ->run(SORTABLE_PICTURE_LIST())
    ->render($self);
}

sub action_ajax_copy {
  my ($self, %params) = @_;

  SL::Clipboard->new->copy($self->text_block);
  SL::ClientJS->new->render($self);
}

sub action_ajax_paste {
  my ($self, %params) = @_;

  my $copied = SL::Clipboard->new->get_entry(qr/^RequirementSpec(?:TextBlock|Picture)$/);
  if (!$copied) {
    return SL::ClientJS->new
      ->error(t8("The clipboard does not contain anything that can be pasted here."))
      ->render($self);
  }

  if (ref($copied) =~ m/Picture$/) {
    $self->load_requirement_spec_text_block;
    return $self->paste_picture($copied);
  }

  my $current_output_position = $self->output_position_from_id($::form->{current_content_id}, $::form->{current_content_type});
  my $new_output_position     = $::form->{id} ? $self->output_position_from_id($::form->{id}) : $::form->{output_position};
  my $front_back              = 0 == $new_output_position ? 'front' : 'back';

  $self->text_block($copied->to_object);
  $self->text_block->update_attributes(requirement_spec_id => $::form->{requirement_spec_id}, output_position => $new_output_position);
  $self->text_block->add_to_list(position => 'after', reference => $::form->{id}) if $::form->{id};

  if ($current_output_position == $new_output_position) {
    my $html = $self->render('requirement_spec_text_block/_text_block', { output => 0 }, text_block => $self->text_block);
    $self->js->action($::form->{id} ? 'insertAfter' : 'appendTo', $html, '#text-block-' . ($::form->{id} || 'list'));
  }

  my $node = $self->text_block->presenter->jstree_data;
  $self->invalidate_version
    ->run(SORTABLE_PICTURE_LIST())
    ->jstree->create_node('#tree', $::form->{id} ? ('#tb-' . $::form->{id}, 'after') : ("#tb-${front_back}", 'last'), $node)
    ->render($self);
}

#
# actions for pictures
#

sub action_ajax_add_picture {
  my ($self) = @_;

  $self->picture(SL::DB::RequirementSpecPicture->new);
  $self->render('requirement_spec_text_block/_picture_form', { layout => 0 });
}

sub action_ajax_edit_picture {
  my ($self) = @_;

  $self->text_block($self->picture->text_block);
  $self->render('requirement_spec_text_block/_picture_form', { layout => 0 });
}

sub action_ajax_create_picture {
  my ($self, %params)              = @_;

  my $attributes                   = $::form->{ $::form->{form_prefix} } || die "Missing attributes";
  $attributes->{picture_file_name} = ((($::form->{ATTACHMENTS} || {})->{ $::form->{form_prefix} } || {})->{picture_content} || {})->{filename};
  my @errors                       = $self->picture(SL::DB::RequirementSpecPicture->new(%{ $attributes }))->validate;

  return $self->js->error(@errors)->render($self) if @errors;

  $self->picture->save;

  $self->text_block($self->picture->text_block);
  my $html = $self->render('requirement_spec_text_block/_text_block_picture', { output => 0 }, picture => $self->picture);

  $self->invalidate_version
    ->dialog->close('#jqueryui_popup_dialog')
    ->append('#text-block-' . $self->text_block->id . '-pictures', $html)
    ->show('#text-block-' . $self->text_block->id . '-pictures')
    ->render($self);
}

sub action_ajax_update_picture {
  my ($self)     = @_;

  my $attributes = $::form->{ $::form->{form_prefix} } || die "Missing attributes";

  if (!$attributes->{picture_content}) {
    delete $attributes->{picture_content};
  } else {
    $attributes->{picture_file_name} = ((($::form->{ATTACHMENTS} || {})->{ $::form->{form_prefix} } || {})->{picture_content} || {})->{filename};
  }

  $self->picture->assign_attributes(%{ $attributes });
  my @errors = $self->picture->validate;

  return $self->js->error(@errors)->render($self) if @errors;

  $self->picture->save;

  $self->text_block($self->picture->text_block);
  my $html = $self->render('requirement_spec_text_block/_text_block_picture', { output => 0 }, picture => $self->picture);

  $self->invalidate_version
    ->dialog->close('#jqueryui_popup_dialog')
    ->replaceWith('#text-block-picture-' . $self->picture->id, $html)
    ->show('#text-block-' . $self->text_block->id . '-pictures')
    ->render($self);
}

sub action_ajax_delete_picture {
  my ($self) = @_;

  $self->picture->delete;
  $self->text_block(SL::DB::RequirementSpecTextBlock->new(id => $self->picture->text_block_id)->load);

  $self->invalidate_version
    ->remove('#text-block-picture-' . $self->picture->id)
    ->action_if(!@{ $self->text_block->pictures }, 'hide', '#text-block-' . $self->text_block->id . '-pictures')
    ->render($self);
}

sub action_ajax_download_picture {
  my ($self) = @_;

  $self->send_file(\$self->picture->{picture_content}, type => $self->picture->picture_content_type, name => $self->picture->picture_file_name);
}

sub action_ajax_copy_picture {
  my ($self, %params) = @_;

  SL::Clipboard->new->copy($self->picture);
  SL::ClientJS->new->render($self);
}

sub action_ajax_paste_picture {
  my ($self, %params) = @_;

  my $copied = SL::Clipboard->new->get_entry(qr/^RequirementSpecPicture$/);
  if (!$copied) {
    return SL::ClientJS->new
      ->error(t8("The clipboard does not contain anything that can be pasted here."))
      ->render($self);
  }

  $self->text_block($self->picture->text_block);   # Save text block via the picture the user clicked on

  $self->paste_picture($copied);
}

sub action_reorder_pictures {
  my ($self) = @_;

  SL::DB::RequirementSpecPicture->reorder_list(@{ $::form->{picture_id} || [] });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  my ($self) = @_;
  $::auth->assert('requirement_spec_edit');
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
  return SL::DB::Manager::RequirementSpecPredefinedText->get_all_sorted(where => [ useable_for_text_blocks => 1 ]);
}

sub init_picture {
  return SL::DB::RequirementSpecPicture->new(id => $::form->{picture_id} || $::form->{id})->load;
}

sub invalidate_version {
  my ($self) = @_;

  my $html   = $self->render('requirement_spec/_version', { output => 0 },
                             requirement_spec => SL::DB::RequirementSpec->new(id => $::form->{requirement_spec_id} || $self->text_block->requirement_spec_id)->load);
  return $self->js->html('#requirement_spec_version', $html);
}

sub add_new_text_block_form {
  my ($self, %params) = @_;

  croak "Missing parameter output_position"     unless defined($params{output_position}) && ($params{output_position} ne '');
  croak "Missing parameter requirement_spec_id" unless $params{requirement_spec_id};

  $self->text_block(SL::DB::RequirementSpecTextBlock->new(
    requirement_spec_id => $params{requirement_spec_id},
    output_position     => $params{output_position},
  ));

  my $id_base = join('_', 'new_text_block', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $html    = $self->render('requirement_spec_text_block/_form', { output => 0 }, id_base => $id_base, insert_after => $params{insert_after_id});

  $self->js
     ->action($params{insert_after_id} ? 'insertAfter' : 'appendTo', $html, '#text-block-' . ($params{insert_after_id} || 'list'))
     ->reinit_widgets
     ->focus('#' . $id_base . '_title');
}

sub show_list {
  my $self   = shift;
  my %params = Params::Validate::validate(@_, { output_position => 1, id => 0, requirement_spec_id => 0, set_type => 0, });

  $params{requirement_spec_id} ||= $::form->{requirement_spec_id};
  croak "Unknown requirement_spec_id" if !$params{requirement_spec_id};

  my $text_blocks = SL::DB::Manager::RequirementSpecTextBlock->get_all_sorted(where => [ output_position => $params{output_position}, requirement_spec_id => $params{requirement_spec_id} ]);
  my $html        = $self->render('requirement_spec_text_block/ajax_list', { output => 0 }, TEXT_BLOCKS => $text_blocks, output_position => $params{output_position});

  $self->js->html('#column-content', $html);

  $self->js->val('#current_content_type', 'text-blocks-' . (0 == $params{output_position} ? 'front' : 'back')) if $params{id} || $params{set_type};
  $self->js->val('#current_content_id',   $params{id})                                                         if $params{id};

  return $self->set_function_blocks_tab_menu_class(class => 'text-block-context-menu');
}

sub paste_picture {
  my ($self, $copied) = @_;

  if (!$self->text_block->db->with_transaction(sub {
    1;
    $self->picture($copied->to_object)->save;        # Create new picture from copied data and save
    $self->text_block->add_pictures($self->picture); # Add new picture to text block
    $self->text_block->save;
  })) {
    $::lxdebug->message(LXDebug::WARN(), "Error: " . $self->text_block->db->error);
    return $self->js->error($::locale->text('Saving failed. Error message from the database: #1', $self->text_block->db->error))->render;
  }

  my $html = $self->render('requirement_spec_text_block/_text_block_picture', { output => 0 }, picture => $self->picture);

  $self->invalidate_version
    ->append('#text-block-' . $self->text_block->id . '-pictures', $html)
    ->show('#text-block-' . $self->text_block->id . '-pictures')
    ->render;
}

1;
