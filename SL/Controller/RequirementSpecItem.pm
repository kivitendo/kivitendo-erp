package SL::Controller::RequirementSpecItem;

use strict;

use parent qw(SL::Controller::Base);

use Time::HiRes ();

use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecItem;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
  scalar => [ qw(requirement_spec item visible_item visible_section) ],
);

# __PACKAGE__->run_before('load_requirement_spec');
__PACKAGE__->run_before('load_requirement_spec_item', only => [qw(dragged_and_dropped edit_section update_section)]);

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

sub action_new {
  my ($self) = @_;

  eval {
    my $type         = ($::form->{item_type} || '') =~ m/^ (?: section | (?: sub-)? function-block ) $/x ? $::form->{item_type} : die "Invalid item_type";
    $self->{item}    = SL::DB::RequirementSpecItem->new(requirement_spec_id => $::form->{requirement_spec_id});
    my $section_form = $self->presenter->render("requirement_spec_item/_${type}_form", id => create_random_id(), title => t8('Create a new section'));

    $self->render(\to_json({ status => 'ok', html => $section_form }), { type => 'json' });
    1;
  } or do {
    $self->render(\to_json({ status => 'failed', error => "Exception:\n" . format_exception() }), { type => 'json' });
  }
}

sub action_create {
  my ($self) = @_;

  my $type = ($::form->{item_type} || '') =~ m/^ (?: section | (?: sub-)? function-block ) $/x ? $::form->{item_type} : die "Invalid item_type";

  $self->render(\to_json({ status => 'failed', error => 'not good, not good' }), { type => 'json' });
}

sub action_dragged_and_dropped {
  my ($self)       = @_;

  $::lxdebug->dump(0, "form", $::form);

  my $dropped_item = SL::DB::RequirementSpecItem->new(id => $::form->{dropped_id})->load || die "No such dropped item";
  my $position     = $::form->{position} =~ m/^ (?: before | after | last ) $/x ? $::form->{position} : die "Unknown 'position' parameter";

  $self->item->db->do_transaction(sub {
    $self->item->remove_from_list;
    $self->item->parent_id($position =~ m/before|after/ ? $dropped_item->parent_id : $dropped_item->id);
    $self->item->add_to_list(position => $position, reference => $dropped_item->id);
  });

  $self->render(\'', { type => 'json' });
}

sub action_edit_section {
  my ($self, %params) = @_;
  $self->render('requirement_spec_item/_section_form', { layout => 0 });
}

sub action_update_section {
  my ($self, %params) = @_;

  $self->item->update_attributes(title => $::form->{title}, description => $::form->{description});

  my $result = {
    id          => $self->item->id,
    header_html => $self->render('requirement_spec_item/_section_header', { layout => 0, output => 0 }, requirement_spec_item => $self->item),
    node_name   => join(' ', map { $_ || '' } ($self->item->fb_number, $self->item->title)),
  };
  $self->render(\to_json($result), { type => 'json' });
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

1;
