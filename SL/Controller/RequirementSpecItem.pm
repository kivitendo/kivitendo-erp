package SL::Controller::RequirementSpecItem;

use strict;

use parent qw(SL::Controller::Base);

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
  scalar                  => [ qw(requirement_spec item visible_item visible_section) ],
  'scalar --get_set_init' => [ qw(complexities risks) ],
);

# __PACKAGE__->run_before('load_requirement_spec');
__PACKAGE__->run_before('load_requirement_spec_item', only => [qw(dragged_and_dropped ajax_update ajax_edit)]);

#
# actions
#

sub action_ajax_list {
  my ($self) = @_;

  my $js = SL::ClientJS->new;

  if (!$::form->{clicked_id}) {
    # Clicked on "sections" in the tree. Do nothing.
    return $self->render($js);
  }

  $self->init_visible_section($::form->{current_content_id}, $::form->{current_content_type});
  $self->item(SL::DB::RequirementSpecItem->new(id => $::form->{clicked_id})->load->get_section);

  if (!$self->visible_section || ($self->visible_section->id != $self->item->id)) {
    my $html = $self->render('requirement_spec_item/_section', { output => 0 }, requirement_spec_item => $self->item);
    $js->html('#column-content', $html)
       ->val('#current_content_type', $self->item->get_type)
       ->val('#current_content_id', $self->item->id);
  }

  $self->render($js);
}

sub action_dragged_and_dropped {
  my ($self)       = @_;

  my $dropped_item = SL::DB::RequirementSpecItem->new(id => $::form->{dropped_id})->load || die "No such dropped item";
  my $position     = $::form->{position} =~ m/^ (?: before | after | last ) $/x ? $::form->{position} : die "Unknown 'position' parameter";

  $self->item->db->do_transaction(sub {
    $self->item->remove_from_list;
    $self->item->parent_id($position =~ m/before|after/ ? $dropped_item->parent_id : $dropped_item->id);
    $self->item->add_to_list(position => $position, reference => $dropped_item->id);
  });

  $self->render(\'', { type => 'json' });
}

sub action_ajax_edit {
  my ($self, %params) = @_;

  $::lxdebug->dump(0, "form", $::form);

  $self->init_visible_section($::form->{current_content_id}, $::form->{current_content_type});
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
  my $prefix     = $::form->{form_prefix} || 'text_block';
  my $attributes = $::form->{$prefix}     || {};

  foreach (qw(requirement_spec_id parent_id position)) {
    delete $attributes->{$_} if !defined $attributes->{$_};
  }

  my @errors = $self->item->assign_attributes(%{ $attributes })->validate;
  return $js->error(@errors)->render($self) if @errors;

  $self->item->save;

  my $id_prefix    = $self->item->get_type eq 'function-block' ? '' : 'sub-';
  my $html_top     = $self->render('requirement_spec_item/_function_block_content_top',    { output => 0 }, requirement_spec_item => $self->item, id_prefix => $id_prefix);
  my $html_bottom  = $self->render('requirement_spec_item/_function_block_content_bottom', { output => 0 }, requirement_spec_item => $self->item, id_prefix => $id_prefix);
  $id_prefix      .= 'function-block-content-';

  my $js = SL::ClientJS->new
    ->remove('#' . $prefix . '_form')
    ->replaceWith('#' . $id_prefix . 'top-'    . $self->item->id, $html_top)
    ->replaceWith('#' . $id_prefix . 'bottom-' . $self->item->id, $html_bottom)
    ->jstree->rename_node('#tree', '#fb-' . $self->item->id, $::request->presenter->requirement_spec_item_tree_node_title($self->item));


  if ($self->item->get_type eq 'sub-function-block') {
    my $parent_html_bottom = $self->render('requirement_spec_item/_function_block_content_bottom', { output => 0 }, requirement_spec_item => $self->item->parent->load);
    $js->replaceWith('#function-block-content-bottom-' . $self->item->parent->id, $parent_html_bottom);
  }

  $js->render($self);
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
  my ($self, $content_id, $content_type) = @_;

  return undef unless $content_id;
  return undef unless $content_type =~ m/section|function-block/;

  $self->visible_item(SL::DB::RequirementSpecItem->new(id => $content_id)->load);
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

1;
