package SL::Controller::AssemblyPlot;

use strict;
use parent qw(SL::Controller::Base);

use List::Util qw(first head);

use SL::DB::Part;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(part) ],
  #'scalar'                => [ qw() ],
);


__PACKAGE__->run_before(sub { $::auth->assert('part_service_assembly_edit') });
__PACKAGE__->run_before(sub { $::request->layout->use_javascript('d3.js', 'kivi.AssemblyPlot.js') },
                        only => ['show']);


sub action_show {
  my ($self) = @_;

  $self->render(
    'assembly_plot/show',
    title => SL::DB::Part->new(id => $::form->{id})->load->displayable_name,
  );
}

sub action_get_objects {
  my ($self) = @_;

  die "export_assembly_assortment_components: recursively only works for assemblies by now" if !$self->part->is_assembly;
  my $items = $self->part->assembly_items_recursively;

  # Get parents for items.
  # Parent of one item is the nearest predecessor with level = item.level - 1.
  # The following is not efficient!.
  # Root/first parent is the part itself.

  $self->part->{unique_id} = 1;

  foreach my $idx (0..$#{$items}) {
    my $item = $items->[$idx];
    my $current_level = $item->{level};

    $item->{unique_id} = $idx + 2;

    if ($current_level-1 == -1) {
      $item->{parent_id} = $self->part->{unique_id};
    } else {

      my @rfront = reverse head $idx, @$items;
      my $parent_assembly = first { $_->{level} == $current_level-1  && $_->part->is_assembly } @rfront;
      $item->{parent_id} = $parent_assembly->{unique_id};
    }
  }

  my $objects;
  foreach my $item (@$items) {
    push @$objects, {parentId => $item->{parent_id},
                     id       => $item->{unique_id},
                     qty      => $item->qty,
                     link     => $self->url_for(controller => 'Part',
                                                action     => 'edit',
                                                'part.id' => $item->part->id),
                     map { ($_ => $item->part->$_) } qw(partnumber description ean part_type),
    };
  }
  push @$objects, {parentId => undef,
                   id       => $self->part->{unique_id},
                   link     => $self->url_for(controller => 'Part',
                                              action     => 'edit',
                                              'part.id'  => $self->part->id),
                   map { ($_ => $self->part->$_) } qw(partnumber description ean part_type)};

  $self->render(\SL::JSON::to_json($objects), { type => 'json', process => 0 });
}


sub init_part {
  SL::DB::Part->new(id => $::form->{id})->load;
}
