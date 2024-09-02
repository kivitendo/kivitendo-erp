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
  );
}

sub action_get_objects {
  my ($self) = @_;

  my $recursively = !! delete $::form->{recursively};
  my $items;
  if ($recursively) {
    die "export_assembly_assortment_components: recursively only works for assemblies by now" if !$self->part->is_assembly;
    $items = $self->part->assembly_items_recursively;
  } else {
    $items = $self->part->items;
  }

  # Get parents for items.
  # Parent of one item is the nearest predecessor with level = item.level - 1.
  # The following is not efficient!.
  # Root/first parent is the part itself.
  foreach my $idx (0..$#{$items}) {
    my $item = $items->[$idx];
    my $current_level = $item->{level};

    if ($current_level-1 == -1) {
      $item->{parent} = $self->part;
    } else {

      my @rfront = reverse head $idx, @$items;
      my $parent_assembly = first { $_->{level} == $current_level-1  && $_->part->is_assembly } @rfront;
      $item->{parent} = $parent_assembly->part;
    }
  }

  my $objects;
  foreach my $item (@$items) {
    push @$objects, {parentId => $item->{parent}->id,
                     qty      => $item->qty,
                     map { ($_ => $item->part->$_) } qw(id partnumber description part_type)};
  }
  push @$objects, {parentId => undef,
                   map { ($_ => $self->part->$_) } qw(id partnumber description part_type)};

  $::lxdebug->dump(0, "bb: objects", $objects);

  $self->render(\SL::JSON::to_json($objects), { type => 'json', process => 0 });
}


sub init_part {
  SL::DB::Part->new(id => $::form->{id})->load;
}
