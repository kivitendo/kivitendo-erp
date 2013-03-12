package SL::Controller::RequirementSpecItem;

use strict;

use parent qw(SL::Controller::Base);

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

__PACKAGE__->run_before('load_requirement_spec_item', only => [ qw(dragged_and_dropped ajax_update ajax_edit ajax_delete) ]);
__PACKAGE__->run_before('init_visible_section',       only => [ qw(dragged_and_dropped ajax_list   ajax_edit ajax_delete) ]);

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
    my $template  = apply { s/-/_/g; $_ } $new_type;
    my $html      = "" . $self->render('requirement_spec_item/_' . $template, { output => 0 }, requirement_spec_item => $self->item);
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

sub action_ajax_edit {
  my ($self, %params) = @_;

  $self->item(SL::DB::RequirementSpecItem->new(id => $::form->{id})->load);

  my $js = SL::ClientJS->new;

  die "TODO: edit section" if $self->item->get_type =~ m/section/;

  if (!$self->visible_section || ($self->visible_section->id != $self->item->get_section->id)) {
    my $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $self->item);
    $js->html('#column-content', $html);
  }

  if ($self->item->get_type =~ m/function-block/) {
    my $create_item = sub {
      [ $_[0]->id, $self->presenter->truncate(join(' ', grep { $_ } ($_[1], $_[0]->fb_number, $_[0]->description))) ]
    };
    my @dependencies =
      map { [ $_->fb_number . ' ' . $_->title,
              [ map { ( $create_item->($_),
                        map { $create_item->($_, '->') } @{ $_->sorted_children })
                    } @{ $_->sorted_children } ] ]
          } @{ $self->item->requirement_spec->sections };

    my @selected_dependencies = map { $_->id } @{ $self->item->dependencies };

    my $html                  = $self->render('requirement_spec_item/_function_block_form', { output => 0 }, DEPENDENCIES => \@dependencies, SELECTED_DEPENDENCIES => \@selected_dependencies);
    my $id_base               = $self->item->get_type . '-' . $self->item->id;
    my $content_top_id        = '#' . $self->item->get_type . '-content-top-' . $self->item->id;

    $js->hide($content_top_id)
       ->remove("#edit_${id_base}_form")
       ->insertAfter($html, $content_top_id)
       ->jstree->select_node('#tree', '#fb-' . $self->item->id)
       ->focus("#edit_${id_base}_description")
       ->val('#current_content_type', $self->item->get_type)
       ->val('#current_content_id', $self->item->id)
       ->render($self);
  }
}

sub action_ajax_update {
  my ($self, %params) = @_;

  my $js         = SL::ClientJS->new;
  my $prefix     = $::form->{form_prefix} || 'function_block';
  my $attributes = $::form->{$prefix}     || {};

  foreach (qw(requirement_spec_id parent_id position)) {
    delete $attributes->{$_} if !defined $attributes->{$_};
  }

  my @errors = $self->item->assign_attributes(%{ $attributes })->validate;
  return $js->error(@errors)->render($self) if @errors;

  $self->item->save;

  my $id_prefix    = $self->item->get_type eq 'function-block' ? '' : 'sub-';
  my $html_top     = $self->render('requirement_spec_item/_function_block_content_top',    { output => 0 }, requirement_spec_item => $self->item, id_prefix => $id_prefix);
  $id_prefix      .= 'function-block-content-';

  my $js = SL::ClientJS->new
    ->remove('#' . $prefix . '_form')
    ->replaceWith('#' . $id_prefix . 'top-' . $self->item->id, $html_top)
    ->jstree->rename_node('#tree', '#fb-' . $self->item->id, $::request->presenter->requirement_spec_item_tree_node_title($self->item));

  $self->replace_bottom($js, $self->item, id_prefix => $id_prefix);
  $self->replace_bottom($js, $self->item->parent) if $self->item->get_type eq 'sub-function-block';

  $js->render($self);
}

sub action_ajax_delete {
  my ($self) = @_;

  my $js = SL::ClientJS->new;

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

    if (1 == scalar @{ $self->item->get_full_list }) {
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

1;
