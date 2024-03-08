package SL::Controller::RecordBase;

use strict;
use parent qw(SL::Controller::Base);

use List::Util qw(first);
use List::MoreUtils qw(none);

use SL::Helper::Flash qw(flash flash_later);

use SL::DB::ValidityToken;

use Rose::Object::MakeMethods::Generic(
 scalar => [ qw(
   item_ids_to_delete is_custom_shipto_to_delete
   ) ],
 'scalar --get_set_init' => [ qw(record) ],
);

# actions ----------------------------------------------------------------------
sub action_add {
  my ($self) = @_;

  $self->record(SL::Model::Record->update_after_new($self->record));

  $self->pre_render();

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_RECORD_SAVE())->token;
  }

  $self->render(
    $self->base_template_folder . '/form',
    title => $self->record->type_data->text('add'),
    %{$self->{template_args}}
  );
}

# helper -----------------------------------------------------------------------

# load record object from form or create a new object
#
# And assign changes from the form to this object.
# If the record is loaded from db, check if items are deleted in the form,
# remove them form the object and collect them for removing from db on saving.
# Then create/update items from form (via make_item) and add them.
sub init_record {
  my ($self) = @_;

  die "type in form needed" unless $::form->{type};
  my $record;
  if ($::form->{id}) {
    $record = SL::Model::Record->get_record($::form->{type}, $::form->{id});
  } else {
    $record = SL::Model::Record->create_new_record($::form->{type});

    my $cv_id_method = $record->type_data->properties('customervendor'). '_id';
    if ($::form->{$cv_id_method}) {
      $record->$cv_id_method($::form->{$cv_id_method});
      $record = SL::Model::Record->update_after_customer_vendor_change($record);
    };
  }

  my $object_key = $record->type_data->properties('object_key');
  my $items_key = $record->type_data->properties('items_key');
  my $form_items = delete $::form->{$object_key}->{$items_key};


  $record->assign_attributes(%{$::form->{$object_key}});

  $self->setup_custom_shipto_from_form($record, $::form);

  # remove deleted items
  $self->item_ids_to_delete([]);
  foreach my $idx (reverse 0..$#{$record->items}) {
    my $item = $record->items->[$idx];
    if (none { $item->id == $_->{id} } @{$form_items}) {
      splice @{$record->items}, $idx, 1;
      push @{$self->item_ids_to_delete}, $item->id;
    }
  }

  my @items;
  my $pos = 1;
  foreach my $form_attr (@{$form_items}) {
    my $item = $self->make_item($record, $form_attr);
    $item->position($pos);
    push @items, $item;
    $pos++;
  }
  $record->add_items(grep {!$_->id} @items);

  return $record;
}

# create or update items from form
#
# Make item objects from form values. For items already existing read from db.
# Create a new item else. And assign attributes.
sub make_item {
  my ($self, $record, $attr) = @_;

  my $item;
  $item = first { $_->id == $attr->{id} } @{$record->items} if $attr->{id};

  my $is_new = !$item;

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $item ||= SL::Model::Record->create_new_record_item($record->record_type);

  $item->assign_attributes(%$attr);

  if ($is_new) {
    my $texts = $self->get_part_texts($item->part, $record->language_id);
    $item->longdescription($texts->{longdescription})              if !defined $attr->{longdescription};
    $item->project_id($record->globalproject_id)                   if !defined $attr->{project_id};
    $item->lastcost($record->is_sales ? $item->part->lastcost : 0) if !defined $attr->{lastcost_as_number};
  }

  return $item;
}

# virtual functions ------------------------------------------------------------

sub base_template_folder {...}

sub pre_render {...}

sub setup_custom_shipto_from_form {...}

sub get_part_texts {...}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::RecordBase - base controller for records

=head1 SYNOPSIS

In a record controller:

  # RecordBase as parent class
  use parent qw(SL::Controller::RecordBase);

  # overwrite function 'foo_fun' of parent RecordBase
  sub foo_func {
    my ($self) = @_;

    # do stuff ...

    my $foo = $self->SUPER::foo_func()

    # do more stuff ...

    return $foo;
  }

=head1 DESCRIPTION

This is a base implementation of the functionality of a controller for handling
records with items.

The aim is to provide a reusable implementation of the core functions for
handling the form and templates. It uses the functions of C<SL::Model::Record>
to handle the record objects of different record types correctly.

=head1 BUGS

Nothing here yet :)

=head1 FURTHER WORK

=over 4

=item *

Create all standard functions for CRUD.

=item *

Move all duplicated functions from C<SL::Controller::Order>,
C<SL::Controller::DeliveryOrder> and C<SL::Controller::Reclamation>.

=back

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
