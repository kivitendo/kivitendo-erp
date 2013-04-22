package SL::Controller::RequirementSpecItem;

use strict;

use parent qw(SL::Controller::Base);

use Carp;
use List::MoreUtils qw(apply);
use List::Util qw(first);
use Time::HiRes ();

use SL::Clipboard;
use SL::Controller::Helper::RequirementSpec;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecComplexity;
use SL::DB::RequirementSpecItem;
use SL::DB::RequirementSpecRisk;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(item visible_item visible_section clicked_item sections) ],
  'scalar --get_set_init' => [ qw(complexities risks) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_requirement_spec_item', only => [ qw(dragged_and_dropped ajax_update ajax_edit ajax_delete ajax_flag ajax_copy) ]);
__PACKAGE__->run_before('init_visible_section');

#
# actions
#

sub action_ajax_list {
  my ($self, $js) = @_;

  my $js = SL::ClientJS->new;

  if (!$::form->{clicked_id}) {
    # Clicked on "sections" in the tree. Do nothing.
    return $self->render($js);
  }

  my $clicked_item = SL::DB::RequirementSpecItem->new(id => $::form->{clicked_id})->load;
  $self->item($clicked_item->section);

  if (!$self->visible_section || ($self->visible_section->id != $self->item->id)) {
    $self->render_list($js, $self->item, $clicked_item);
  } else {
    $self->select_node($js, $clicked_item);
  }

  $self->render($js);
}

sub insert_new_item_in_section_view {
  my ($self, $js) = @_;

  $js->hide('#section-list-empty');

  my $new_type  = $self->item->item_type;
  my $id_prefix = $new_type eq 'sub-function-block' ? 'sub-' : '';
  my $template  = 'requirement_spec_item/_' . (apply { s/-/_/g; $_ } $new_type);
  my $html      = "" . $self->render($template, { output => 0 }, requirement_spec_item => $self->item);
  my $next_item = $self->item->get_next_in_list;

  if ($next_item) {
    $js->insertBefore($html, '#' . $id_prefix . 'function-block-' . $next_item->id);
  } else {
    my $parent_is_section = $self->item->parent->item_type eq 'section';
    $js->appendTo($html, $parent_is_section ? '#section-list' : '#sub-function-block-container-' . $self->item->parent_id);
    $js->show('#sub-function-block-container-' . $self->item->parent_id) if !$parent_is_section;
  }

  $self->replace_bottom($js, $self->item->parent) if $new_type eq 'sub-function-block';
}

sub action_dragged_and_dropped {
  my ($self)              = @_;

  my $position            = $::form->{position} =~ m/^ (?: before | after | last ) $/x ? $::form->{position}                                             : die "Unknown 'position' parameter";
  my $dropped_item        = $::form->{dropped_id}                                  ? SL::DB::RequirementSpecItem->new(id => $::form->{dropped_id})->load : undef;

  my $old_visible_section = $self->visible_section ? $self->visible_section : undef;
  my $old_parent_id       = $self->item->parent_id;
  my $old_type            = $self->item->item_type;

  $self->item->db->do_transaction(sub {
    $self->item->remove_from_list;
    $self->item->parent_id($position =~ m/before|after/ ? $dropped_item->parent_id : $dropped_item->id);
    $self->item->add_to_list(position => $position, reference => $::form->{dropped_id} || undef);
  });

  my $js = SL::ClientJS->new;

  $self->item(SL::DB::RequirementSpecItem->new(id => $self->item->id)->load);
  my $new_section         = $self->item->section;
  my $new_type            = $self->item->item_type;
  my $new_visible_section = SL::DB::RequirementSpecItem->new(id => $self->visible_item->id)->load->section;

  return $self->render($js) if !$old_visible_section || ($new_type eq 'section');

  # From here on $old_visible_section is definitely set.

  my $old_parent  = SL::DB::RequirementSpecItem->new(id => $old_parent_id)->load;
  my $old_section = $old_parent->section;

  # $::lxdebug->message(0, "old sec ID " . $old_section->id . " new " . $new_section->id . " old visible " . $old_visible_section->id . " new visible " . $new_visible_section->id
  #                       . " PARENT: old " . $old_parent->id . " new " . $self->item->parent_id . '/' . $self->item->parent->id);

  if ($old_visible_section->id != $new_visible_section->id) {
    # The currently visible item has been dragged to a different section.
    return $self->render_list($js, $new_section, $self->item)
      ->render($self);
  }

  if ($old_visible_section->id == $old_section->id) {
    my $id_prefix = $old_type eq 'sub-function-block' ? 'sub-' : '';
    $js->remove('#' . $id_prefix . 'function-block-' . $self->item->id);

    if ($old_type eq 'sub-function-block') {
      $self->replace_bottom($js, $old_parent) ;
      $js->hide('#sub-function-block-container-' . $old_parent->id) if 0 == scalar(@{ $old_parent->children });

    } elsif (0 == scalar(@{ $old_section->children })) {
      $js->show('#section-list-empty');
    }
  }

  if ($old_visible_section->id == $new_section->id) {
    $self->insert_new_item_in_section_view($js);
  }

  # $::lxdebug->dump(0, "js", $js->to_array);

  $self->render($js);
}

sub action_ajax_add_section {
  my ($self, %params) = @_;

  die "Missing parameter 'requirement_spec_id'" if !$::form->{requirement_spec_id};

  $self->item(SL::DB::RequirementSpecItem->new(requirement_spec_id => $::form->{requirement_spec_id}, item_type => 'section'));

  my $insert_after = $::form->{id} ? SL::DB::RequirementSpecItem->new(id => $::form->{id})->load->section->id : undef;
  my $html         = $self->render('requirement_spec_item/_section_form', { output => 0 }, id_base => 'new_section', insert_after => $insert_after);

  SL::ClientJS->new
    ->remove('#new_section_form')
    ->hide('#column-content > *')
    ->appendTo($html, '#column-content')
    ->focus('#new_section_title')
    ->render($self);
}

sub action_ajax_add_function_block {
  my ($self, %params) = @_;

  return $self->add_function_block('function-block');
}

sub action_ajax_add_sub_function_block {
  my ($self, %params) = @_;

  return $self->add_function_block('sub-function-block');
}

sub action_ajax_create {
  my ($self, %params) = @_;

  my $js              = SL::ClientJS->new;
  my $prefix          = $::form->{form_prefix} || die "Missing parameter 'form_prefix'";
  my $attributes      = $::form->{$prefix}     || die "Missing parameter group '${prefix}'";
  my $insert_after    = delete $attributes->{insert_after};

  my @errors = $self->item(SL::DB::RequirementSpecItem->new(%{ $attributes }))->validate;
  return $js->error(@errors)->render($self) if @errors;

  $self->item->save;
  $self->item->add_to_list(position => 'after', reference => $insert_after) if $insert_after;

  my $type = $self->item->item_type;

  if ($type eq 'section') {
    my $node = $self->presenter->requirement_spec_item_jstree_data($self->item);
    return $self->render_list($js, $self->item)
      ->jstree->create_node('#tree', $insert_after ? ('#fb-' . $insert_after, 'after') : ('#sections', 'last'), $node)
      ->jstree->select_node('#tree', '#fb-' . $self->item->id)
      ->render($self);
  }

  my $template = 'requirement_spec_item/_' . (apply { s/-/_/g; $_ } $type);
  my $html     = $self->render($template, { output => 0 }, requirement_spec_item => $self->item, id_prefix => $type eq 'function-block' ? '' : 'sub-');
  my $node     = $self->presenter->requirement_spec_item_jstree_data($self->item);

  $js->replaceWith('#' . $prefix . '_form', $html)
     ->hide('#section-list-empty')
     ->jstree->create_node('#tree', $insert_after ? ('#fb-' . $insert_after, 'after') : ('#fb-' . $self->item->parent_id, 'last'), $node)
     ->jstree->select_node('#tree', '#fb-' . $self->item->id);

  $self->replace_bottom($js, $self->item->parent) if $type eq 'sub-function-block';

  $js->render($self);
}

sub action_ajax_edit {
  my ($self, %params) = @_;

  $self->item(SL::DB::RequirementSpecItem->new(id => $::form->{id})->load);

  my $js = SL::ClientJS->new;

  if (!$self->is_item_visible) {
    # Show section/item to edit if it is not visible.

    my $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $self->item->section);
    $js->html('#column-content', $html);
  }

  if ($self->item->item_type =~ m/section/) {
    # Edit the section header, not an item.
    my $html = $self->render('requirement_spec_item/_section_form', { output => 0 });

    $js->hide('#section-header-' . $self->item->id)
       ->remove("#edit_section_form")
       ->insertAfter($html, '#section-header-' . $self->item->id)
       ->jstree->select_node('#tree', '#fb-' . $self->item->id)
       ->focus("#edit_section_title")
       ->val('#current_content_type', 'section')
       ->val('#current_content_id',   $self->item->id)
       ->render($self);
    return;
  }

  # Edit a function block or a sub function block
  my @dependencies          = $self->create_dependencies;
  my @selected_dependencies = map { $_->id } @{ $self->item->dependencies };

  my $html                  = $self->render('requirement_spec_item/_function_block_form', { output => 0 }, DEPENDENCIES => \@dependencies, SELECTED_DEPENDENCIES => \@selected_dependencies);
  my $id_base               = 'edit_function_block_' . $self->item->id;
  my $content_top_id        = '#' . $self->item->item_type . '-content-top-' . $self->item->id;

  $js->hide($content_top_id)
     ->remove("#${id_base}_form")
     ->insertAfter($html, $content_top_id)
     ->jstree->select_node('#tree', '#fb-' . $self->item->id)
     ->focus("#${id_base}_description")
     ->val('#current_content_type', $self->item->item_type)
     ->val('#current_content_id', $self->item->id)
     ->render($self);
}

sub action_ajax_update {
  my ($self, %params) = @_;

  my $js         = SL::ClientJS->new;
  my $prefix     = $::form->{form_prefix} || die "Missing parameter 'form_prefix'";
  my $attributes = $::form->{$prefix}     || {};

  foreach (qw(requirement_spec_id parent_id position)) {
    delete $attributes->{$_} if !defined $attributes->{$_};
  }

  my @errors = $self->item->assign_attributes(%{ $attributes })->validate;
  return $js->error(@errors)->render($self) if @errors;

  $self->item->save;

  my $type = $self->item->item_type;

  if ($type eq 'section') {
    # Updated section, now update section header.

    my $html = $self->render('requirement_spec_item/_section_header', { output => 0 }, requirement_spec_item => $self->item);

    return SL::ClientJS->new
      ->remove('#edit_section_form')
      ->html('#section-header-' . $self->item->id, $html)
      ->show('#section-header-' . $self->item->id)
      ->jstree->rename_node('#tree', '#fb-' . $self->item->id, $::request->presenter->requirement_spec_item_tree_node_title($self->item))
      ->render($self);
  }

  # Updated function block or sub function block. Update (sub)
  # function block and potentially the bottom of the parent function
  # block.

  my $id_prefix    = $type eq 'function-block' ? '' : 'sub-';
  my $html_top     = $self->render('requirement_spec_item/_function_block_content_top',    { output => 0 }, requirement_spec_item => $self->item, id_prefix => $id_prefix);
  $id_prefix      .= 'function-block-content-';

  my $js = SL::ClientJS->new
    ->remove('#' . $prefix . '_form')
    ->replaceWith('#' . $id_prefix . 'top-' . $self->item->id, $html_top)
    ->jstree->rename_node('#tree', '#fb-' . $self->item->id, $::request->presenter->requirement_spec_item_tree_node_title($self->item));

  $self->replace_bottom($js, $self->item, id_prefix => $id_prefix);
  $self->replace_bottom($js, $self->item->parent) if $type eq 'sub-function-block';

  $js->render($self);
}

sub action_ajax_delete {
  my ($self) = @_;

  my $js        = SL::ClientJS->new;
  my $full_list = $self->item->get_full_list;

  $self->item->delete;

  if ($self->visible_section && ($self->visible_section->id == $self->item->id)) {
    # Currently visible section is deleted.

    my $new_section = first { $_->id != $self->item->id } @{ $self->item->requirement_spec->sections };
    if ($new_section) {
      $self->render_list($js, $new_section);

    } else {
      my $html = $self->render('requirement_spec_item/_no_section', { output => 0 });
      $js->html('#column-content', $html)
         ->val('#current_content_type', '')
         ->val('#current_content_id', '')
    }

  } elsif ($self->is_item_visible) {
    # Item in currently visible section is deleted.

    my $type = $self->item->item_type;
    $js->remove('#edit_function_block_' . $self->item->id . '_form')
       ->remove('#' . $type . '-' . $self->item->id);

    $self->replace_bottom($js, $self->item->parent_id) if $type eq 'sub-function-block';

    if (1 == scalar @{ $full_list }) {
      if ($type eq 'function-block') {
        $js->show('#section-list-empty');
      } elsif ($type eq 'sub-function-block') {
        $js->hide('#sub-function-block-container-' . $self->item->parent_id);
      }
    }
  }

  $js->jstree->delete_node('#tree', '#fb-' . $self->item->id)
     ->render($self);
}

sub action_ajax_flag {
  my ($self) = @_;

  $self->item->update_attributes(is_flagged => !$self->item->is_flagged);

  SL::ClientJS->new
   ->action_if($self->is_item_visible, 'toggleClass', '#' . $self->item->item_type . '-' . $self->item->id, 'flagged')
   ->toggleClass('#fb-' . $self->item->id, 'flagged')
   ->render($self);
}

sub action_ajax_copy {
  my ($self, %params) = @_;

  SL::Clipboard->new->copy($self->item);
  SL::ClientJS->new->render($self);
}

sub determine_paste_position {
  my ($self) = @_;

  if ($self->item->item_type eq 'section') {
    # Sections are always pasted either directly after the
    # clicked-upon section or at the very end.
    return $self->clicked_item ? (undef, $self->clicked_item->section->id) : ();

  } elsif ($self->item->item_type eq 'function-block') {
    # A function block:
    # - paste on section list: insert into last section as last element
    # - paste on section: insert into that section as last element
    # - paste on function block: insert after clicked-upon element
    # - paste on sub function block: insert after parent function block of clicked-upon element
    return !$self->clicked_item                                ? ( $self->sections->[-1]->id,              undef                          )
         :  $self->clicked_item->item_type eq 'section'        ? ( $self->clicked_item->id,                undef                          )
         :  $self->clicked_item->item_type eq 'function-block' ? ( $self->clicked_item->parent_id,         $self->clicked_item->id        )
         :                                                       ( $self->clicked_item->parent->parent_id, $self->clicked_item->parent_id );

  } else {                      # sub-function-block
    # A sub function block:
    # - paste on section list: promote to function block and insert into last section as last element
    # - paste on section: promote to function block and insert into that section as last element
    # - paste on function block: insert as last element in clicked-upon element
    # - paste on sub function block: insert after clicked-upon element

    # Promote sub function blocks to function blocks when pasting on a
    # section or the section list.
    $self->item->item_type('function-block') if !$self->clicked_item || ($self->clicked_item->item_type eq 'section');

    return !$self->clicked_item                                ? ( $self->sections->[-1]->id,      undef                   )
         :  $self->clicked_item->item_type eq 'section'        ? ( $self->clicked_item->id,        undef                   )
         :  $self->clicked_item->item_type eq 'function-block' ? ( $self->clicked_item->id,        undef                   )
         :                                                       ( $self->clicked_item->parent_id, $self->clicked_item->id );
  }
}

sub assign_requirement_spec_id_rec {
  my ($self, $item) = @_;

  $item->requirement_spec_id($::form->{requirement_spec_id});
  $self->assign_requirement_spec_id_rec($_) for @{ $item->children || [] };

  return $item;
}

sub create_and_insert_node_rec {
  my ($self, $js, $item, $new_parent_id, $insert_after) = @_;

  my $node = $self->presenter->requirement_spec_item_jstree_data($item);
  $js->jstree->create_node('#tree', $insert_after ? ('#fb-' . $insert_after, 'after') : $new_parent_id ? ('#fb-' . $new_parent_id, 'last') : ('#sections', 'last'), $node);

  $self->create_and_insert_node_rec($js, $_, $item->id) for @{ $item->children || [] };

  $js->jstree->open_node('#tree', '#fb-' . $item->id);
}

sub action_ajax_paste {
  my ($self, %params) = @_;

  my $js     = SL::ClientJS->new;
  my $copied = SL::Clipboard->new->get_entry(qr/^RequirementSpecItem$/);

  if (!$copied) {
    return $js->error(t8("The clipboard does not contain anything that can be pasted here."))
              ->render($self);
  }

  $self->item($self->assign_requirement_spec_id_rec($copied->to_object));
  my $req_spec = SL::DB::RequirementSpec->new(id => $::form->{requirement_spec_id})->load;
  $self->sections($req_spec->sections);

  if (($self->item->item_type ne 'section') && !@{ $self->sections }) {
    return $js->error(t8("You cannot paste function blocks or sub function blocks if there is no section."))
              ->render($self);
  }

  $self->clicked_item($::form->{id} ? SL::DB::RequirementSpecItem->new(id => $::form->{id})->load : undef);

  my ($new_parent_id, $insert_after) = $self->determine_paste_position;

  # Store result in database.
  $self->item->update_attributes(requirement_spec_id => $::form->{requirement_spec_id}, parent_id => $new_parent_id);
  $self->item->add_to_list(position => 'after', reference => $insert_after) if $insert_after;

  # Update the tree: create the node for all pasted objects.
  $self->create_and_insert_node_rec($js, $self->item, $new_parent_id, $insert_after);

  # Pasting the very first section?
  if (!@{ $self->sections }) {
    my $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $self->item);
    $js->html('#column-content', $html)
       ->jstree->select_node('#tree', '#fb-' . $self->item->id)
  }

  # Update the current view if required.
  $self->insert_new_item_in_section_view($js) if $self->is_item_visible;

  $js->render($self);
}

#
# filters
#

sub check_auth {
  my ($self) = @_;
  $::auth->assert('sales_quotation_edit');
}

sub load_requirement_spec {
  my ($self) = @_;
  $self->requirement_spec(SL::DB::RequirementSpec->new(id => $::form->{requirement_spec_id})->load || die "No such requirement spec");
}

sub load_requirement_spec_item {
  my ($self) = @_;
  $self->item(SL::DB::RequirementSpecItem->new(id => $::form->{id})->load || die "No such requirement spec item");
}

#
# helpers
#

sub create_random_id {
  return join '-', Time::HiRes::gettimeofday();
}

sub format_exception {
  return join "\n", (split m/\n/, $@)[0..4];
}

sub init_complexities {
  my ($self) = @_;

  return SL::DB::Manager::RequirementSpecComplexity->get_all_sorted;
}

sub init_risks {
  my ($self) = @_;

  return SL::DB::Manager::RequirementSpecRisk->get_all_sorted;
}

sub replace_bottom {
  my ($self, $js, $item_or_id) = @_;

  my $item      = (ref($item_or_id) ? $item_or_id : SL::DB::RequirementSpecItem->new(id => $item_or_id))->load;
  my $id_prefix = $item->item_type eq 'function-block' ? '' : 'sub-';
  my $html      = $self->render('requirement_spec_item/_function_block_content_bottom', { output => 0 }, requirement_spec_item => $item, id_prefix => $id_prefix);
  return $js->replaceWith('#' . $id_prefix . 'function-block-content-bottom-' . $item->id, $html);
}

sub render_list {
  my ($self, $js, $item, $item_to_select) = @_;

  my $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $item);
  $self->select_node($js->html('#column-content', $html), $item_to_select || $item);
}

sub select_node {
  my ($self, $js, $item) = @_;

  $js->val( '#current_content_type', $item->item_type)
     ->val( '#current_content_id',   $item->id)
     ->jstree->select_node('#tree', '#fb-' . $item->id);
}

sub create_dependency_item {
  my $self = shift;
  [ $_[0]->id, $self->presenter->truncate(join(' ', grep { $_ } ($_[1], $_[0]->fb_number, $_[0]->description))) ];
}

sub create_dependencies {
  my ($self) = @_;

  return map { [ $_->fb_number . ' ' . $_->title,
                 [ map { ( $self->create_dependency_item($_),
                           map { $self->create_dependency_item($_, '->') } @{ $_->sorted_children })
                       } @{ $_->sorted_children } ] ]
             } @{ $self->item->requirement_spec->sections };
}

sub add_function_block {
  my ($self, $new_type) = @_;

  my $clicked_id = $::form->{id} || ($self->visible_item ? $self->visible_item->id : undef);

  die "Invalid new_type '$new_type'"               if $new_type !~ m/^(?:sub-)?function-block$/;
  die "Missing parameter 'id' and no visible item" if !$clicked_id;
  die "Missing parameter 'requirement_spec_id'"    if !$::form->{requirement_spec_id};

  my $clicked_item = SL::DB::RequirementSpecItem->new(id => $clicked_id)->load;
  my $clicked_type = $clicked_item->item_type;

  die "Invalid clicked_type '$clicked_type'" if $clicked_type !~ m/^(?: section | (?:sub-)? function-block )$/x;

  my $case = "${clicked_type}:${new_type}";

  my ($insert_position, $insert_reference, $parent_id, $display_reference)
    = $case eq 'section:function-block'                ? ( 'appendTo',    $clicked_item->id,        $clicked_item->id,                '#section-list'                  )
    : $case eq 'function-block:function-block'         ? ( 'insertAfter', $clicked_item->id,        $clicked_item->parent_id,         '#function-block-'               )
    : $case eq 'function-block:sub-function-block'     ? ( 'appendTo'  ,  $clicked_item->id,        $clicked_item->id,                '#sub-function-block-container-' )
    : $case eq 'sub-function-block:function-block'     ? ( 'insertAfter', $clicked_item->parent_id, $clicked_item->parent->parent_id, '#function-block-'               )
    : $case eq 'sub-function-block:sub-function-block' ? ( 'insertAfter', $clicked_item->id,        $clicked_item->parent_id,         '#sub-function-block-'           )
    :                                                    die "Invalid combination of 'clicked_type (section)/new_type ($new_type)'";

  $self->item(SL::DB::RequirementSpecItem->new(requirement_spec_id => $::form->{requirement_spec_id}, parent_id => $parent_id, item_type => $new_type));

  $display_reference .= $insert_reference if $display_reference =~ m/-$/;
  my $id_base         = join('_', 'new_function_block', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $html            = $self->render(
    'requirement_spec_item/_function_block_form',
    { output => 0 },
    DEPENDENCIES          => [ $self->create_dependencies ],
    SELECTED_DEPENDENCIES => [],
    requirement_spec_item => $self->item,
    id_base               => $id_base,
    insert_after          => $insert_position eq 'insertAfter' ? $insert_reference : undef,
  );

  my $js = SL::ClientJS->new;

  my $new_section = $self->item->section;
  if (!$self->is_item_visible) {
    # Show section/item to edit if it is not visible.

    $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $new_section);
    $js->html('#column-content', $html)
       ->val('#current_content_type', 'section')
       ->val('#current_content_id',   $new_section->id)
       ->jstree->select_node('#tree', '#fb-' . $new_section->id);
  }

  # $::lxdebug->message(0, "alright! clicked ID " . $::form->{id} . " type $clicked_type new_type $new_type insert_pos $insert_position ref " . ($insert_reference // '<undef>') . " parent $parent_id display_ref $display_reference");

  $js->action($insert_position, $html, $display_reference)
     ->focus("#${id_base}_description");

  $js->show('#sub-function-block-container-' . $parent_id) if $new_type eq 'sub-function-block';

  $js->render($self);
}

sub is_item_visible {
  my ($self, $item) = @_;

  $item ||= $self->item;
  return $self->visible_section && ($self->visible_section->id == $item->section->id);
}

1;
