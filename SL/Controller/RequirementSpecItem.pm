package SL::Controller::RequirementSpecItem;

use strict;

use parent qw(SL::Controller::Base);

use Carp;
use List::MoreUtils qw(apply);
use List::Util qw(first);
use Time::HiRes ();

use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecComplexity;
use SL::DB::RequirementSpecItem;
use SL::DB::RequirementSpecRisk;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(item visible_item visible_section) ],
  'scalar --get_set_init' => [ qw(complexities risks) ],
);

__PACKAGE__->run_before('load_requirement_spec_item', only => [ qw(dragged_and_dropped ajax_update ajax_edit ajax_delete ajax_flag) ]);
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

  $self->item(SL::DB::RequirementSpecItem->new(id => $::form->{clicked_id})->load->get_section);

  $self->render_list($js, $self->item) if !$self->visible_section || ($self->visible_section->id != $self->item->id);

  $self->render($js);
}

sub action_dragged_and_dropped {
  my ($self)             = @_;

  my $position           = $::form->{position} =~ m/^ (?: before | after | last ) $/x ? $::form->{position}                                             : die "Unknown 'position' parameter";
  my $dropped_item       = $::form->{dropped_id}                                  ? SL::DB::RequirementSpecItem->new(id => $::form->{dropped_id})->load : undef;

  my $visible_section_id = $self->visible_section ? $self->visible_section->id : undef;
  my $old_parent_id      = $self->item->parent_id;
  my $old_type           = $self->item->get_type;

  $self->item->db->do_transaction(sub {
    $self->item->remove_from_list;
    $self->item->parent_id($position =~ m/before|after/ ? $dropped_item->parent_id : $dropped_item->id);
    $self->item->add_to_list(position => $position, reference => $::form->{dropped_id} || undef);
  });

  my $js = SL::ClientJS->new;

  $self->item(SL::DB::RequirementSpecItem->new(id => $self->item->id)->load);
  my $new_section = $self->item->get_section;
  my $new_type    = $self->item->get_type;

  return $self->render($js) if !$visible_section_id || ($new_type eq 'section');

  my $old_parent  = SL::DB::RequirementSpecItem->new(id => $old_parent_id)->load;
  my $old_section = $old_parent->get_section;

  # $::lxdebug->message(0, "old sec ID " . $old_section->id . " new " . $new_section->id . " visible $visible_section_id PARENT: old " . $old_parent->id . " new " . $self->item->parent_id . '/' . $self->item->parent->id);

  if ($visible_section_id == $old_section->id) {
    my $id_prefix = $old_type eq 'sub-function-block' ? 'sub-' : '';
    $js->remove('#' . $id_prefix . 'function-block-' . $self->item->id);

    if ($old_type eq 'sub-function-block') {
      $self->replace_bottom($js, $old_parent) ;
      $js->hide('#sub-function-block-container-' . $old_parent->id) if 0 == scalar(@{ $old_parent->children });

    } elsif (0 == scalar(@{ $old_section->children })) {
      $js->show('#section-list-empty');
    }
  }

  if ($visible_section_id == $new_section->id) {
    $js->hide('#section-list-empty');

    my $id_prefix = $new_type eq 'sub-function-block' ? 'sub-' : '';
    my $template  = 'requirement_spec_item/_' . (apply { s/-/_/g; $_ } $new_type);
    my $html      = "" . $self->render($template, { output => 0 }, requirement_spec_item => $self->item);
    my $next_item = $self->item->get_next_in_list;

    if ($next_item) {
      $js->insertBefore($html, '#' . $id_prefix . 'function-block-' . $next_item->id);
    } else {
      my $parent_is_section = $self->item->parent->get_type eq 'section';
      $js->appendTo($html, $parent_is_section ? '#section-list' : '#sub-function-block-container-' . $self->item->parent_id);
      $js->show('#sub-function-block-container-' . $self->item->parent_id) if !$parent_is_section;
    }

    $self->replace_bottom($js, $self->item->parent) if $new_type eq 'sub-function-block';
  }

  # $::lxdebug->dump(0, "js", $js->to_array);

  $self->render($js);
}

sub action_ajax_add_section {
  my ($self, %params) = @_;

  die "Missing parameter 'requirement_spec_id'" if !$::form->{requirement_spec_id};

  $self->item(SL::DB::RequirementSpecItem->new(requirement_spec_id => $::form->{requirement_spec_id}));

  my $insert_after = $::form->{id} ? SL::DB::RequirementSpecItem->new(id => $::form->{id})->load->get_section->id : undef;
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

  my $type = $self->item->get_type;

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

  if (!$self->visible_section || ($self->visible_section->id != $self->item->get_section->id)) {
    # Show section/item to edit if it is not visible.

    my $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $self->item);
    $js->html('#column-content', $html);
  }

  if ($self->item->get_type =~ m/section/) {
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
  my $content_top_id        = '#' . $self->item->get_type . '-content-top-' . $self->item->id;

  $js->hide($content_top_id)
     ->remove("#${id_base}_form")
     ->insertAfter($html, $content_top_id)
     ->jstree->select_node('#tree', '#fb-' . $self->item->id)
     ->focus("#${id_base}_description")
     ->val('#current_content_type', $self->item->get_type)
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

  my $type = $self->item->get_type;

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

  } elsif ($self->visible_section && ($self->visible_section->id == $self->item->get_section->id)) {
    # Item in currently visible section is deleted.

    my $type = $self->item->get_type;
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

  my $is_visible = $self->visible_section && ($self->visible_section->id == $self->item->get_section->id);

  SL::ClientJS->new
   ->action_if($is_visible, 'toggleClass', '#' . $self->item->get_type . '-' . $self->item->id, 'flagged')
   ->toggleClass('#fb-' . $self->item->id, 'flagged')
   ->render($self);
}

#
# filters
#

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

sub init_visible_section {
  my ($self)       = @_;

  my $content_id   = $::form->{current_content_id};
  my $content_type = $::form->{current_content_type};

  return undef unless $content_id;
  return undef unless $content_type =~ m/section|function-block/;

  $self->visible_item(SL::DB::Manager::RequirementSpecItem->find_by(id => $content_id));
  return undef unless $self->visible_item;

  return $self->visible_section($self->visible_item->get_section);
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
  my $id_prefix = $item->get_type eq 'function-block' ? '' : 'sub-';
  my $html      = $self->render('requirement_spec_item/_function_block_content_bottom', { output => 0 }, requirement_spec_item => $item, id_prefix => $id_prefix);
  return $js->replaceWith('#' . $id_prefix . 'function-block-content-bottom-' . $item->id, $html);
}

sub render_list {
  my ($self, $js, $item) = @_;

  my $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $item);
  $js->html('#column-content',      $html)
     ->val( '#current_content_type', $item->get_type)
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
  my $clicked_type = $clicked_item->get_type;

  die "Invalid clicked_type '$clicked_type'" if $clicked_type !~ m/^(?: section | (?:sub-)? function-block )$/x;

  my $case = "${clicked_type}:${new_type}";

  my ($insert_position, $insert_reference, $parent_id, $display_reference)
    = $case eq 'section:function-block'                ? ( 'appendTo',    $clicked_item->id,        $clicked_item->id,                '#section-list'                  )
    : $case eq 'function-block:function-block'         ? ( 'insertAfter', $clicked_item->id,        $clicked_item->parent_id,         '#function-block-'               )
    : $case eq 'function-block:sub-function-block'     ? ( 'appendTo'  ,  $clicked_item->id,        $clicked_item->id,                '#sub-function-block-container-' )
    : $case eq 'sub-function-block:function-block'     ? ( 'insertAfter', $clicked_item->parent_id, $clicked_item->parent->parent_id, '#function-block-'               )
    : $case eq 'sub-function-block:sub-function-block' ? ( 'insertAfter', $clicked_item->id,        $clicked_item->parent_id,         '#sub-function-block-'           )
    :                                                    die "Invalid combination of 'clicked_type (section)/new_type ($new_type)'";

  $self->item(SL::DB::RequirementSpecItem->new(requirement_spec_id => $::form->{requirement_spec_id}, parent_id => $parent_id));

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

  my $new_section = $self->item->get_section;
  if (!$self->visible_section || ($self->visible_section->id != $new_section->id)) {
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

1;
