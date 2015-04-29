package SL::Clipboard;

use strict;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(content) ],
);

use Carp;
use List::MoreUtils qw(apply);
use List::Util qw(first);
use Scalar::Util qw(blessed);

use SL::Clipboard::RequirementSpecItem;
use SL::Clipboard::RequirementSpecTextBlock;

sub init_content {
  my $value = $::auth->get_session_value('clipboard-content');
  return ref($value) eq 'HASH' ? $value : { entries => [] };
}

sub copy {
  my ($self, $object) = @_;

  my $copied = $self->_create_copy_of($object);
  push @{ $self->content->{entries} }, $copied;

  $self->_save_content;

  return $copied;
}

sub get_entry {
  my ($self, $type) = @_;

  $type ||= qr/./;

  return first   { $_->type =~ $type          }
         reverse @{ $self->content->{entries} };
}

sub get_entries {
  my ($self, $type) = @_;

  $type ||= qr/./;

  return grep    { $_->{type} =~ $type        }
         reverse @{ $self->content->{entries} };
}

sub clear {
  my ($self) = @_;

  $self->content->{entries} = [];
  $self->_save_content;

  return $self;
}

sub _log_entries {
  my ($self) = @_;

  $::lxdebug->message(0, "Clipboard entries: " . scalar(@{ $self->content->{entries} }));
  foreach (@{ $self->content->{entries} }) {
    $::lxdebug->message(0, "  " . $_->type . ' ' . $_->timestamp . ' ' . $_->describe);
  }
}

sub _create_copy_of {
  my ($self, $object) = @_;

  croak "\$object is not a blessed reference." unless blessed($object);

  my $type   = (split(m/::/, ref($object)))[-1];
  my $copied = eval { "SL::Clipboard::${type}"->new(timestamp => DateTime->now_local) };

  croak "Class '" . ref($object) . "' not supported for copy/paste operations" if !$copied;

  $copied->content($copied->dump($object));

  return $copied;
}

sub _save_content {
  my ($self) = @_;

  $::auth->set_session_value('clipboard-content', $self->content);

  return $self;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Clipboard - A session-based clipboard mechanism for
Rose::DB::Object instances

=head1 SYNOPSIS

  # In a controller, e.g. for customers, you can react to a "copy" operation:
  my $customer = SL::DB::Customer->new(id => $::form->{id});
  SL::Clipboard->new->copy($customer);

  # Later in a paste action:
  my $copied = SL::Clipboard->new->get_entry(qr/^Customer$/);
  if ($copied) {
    my $customer = $copied->to_object;
    $customer->save;
  }

=head1 OVERVIEW

The clipboard can store an unlimited number of copies of
Rose::DB::Object instances. The instances are dumped into trees using
L<Rose::DB::Object::Helpers/as_tree>. How much of such an object is
copied depends on its type. For example, a dump of a customer object
might also include the dumps of the shipping address and contact
objects belonging to the customer.

Each clipped object is stored in the user's session along with the
timestamp of the copy operation. A controller can then query the
clipboard for the latest clipped object of a certain type (or more
types if the situation allows insertion of different types). If such a
clipped object is available it can be turned into a shiny new
Rose::DB::Object instance that can be saved to the database.

Primary key columns will always be reset as will other columns
depending on the type. For example, a copied requirement spec item
will have its C<requirement_spec_id> column cleared. The controller is
responsible for setting the columns before saving the object.

Not every Rose::DB::Object instance can be copied. For each supported
type C<Type> there must be a specialized clipboard support class
C<SL::Clipboard::Type>. The type's name is derived from the Rose class
name: by stripping the leading C<SL::DB::>. So the clipboard support
class for a requirement spec item Rose class
C<SL::DB::RequirementSpecItem> would be
C<SL::Clipboard::RequirementSpecItem>. These support classes must
inherit from L<SL::Clipboard::Base> which offers almost a full set of
support functions so that the actual specialized class has to do very
little.

As the clipboard is session-based its contents will be lost when the
session expires (either due to timeouts or to the user logging off).

=head1 FUNCTIONS

=over 4

=item C<clear>

Clears the clipboard (removes all entries).

=item C<copy $object>

Creates a dumped copy of C<$object> and stores that copy in the
session. An unlimited number of copies of differing types can be
made.

Returns the instance of the copied object, a sub-class of
L<SL::Clipboard::Base>.

=item C<get_entries [$type]>

Returns an array of clipped objects whose type matches the regular
expression C<$type>. If C<$type> is not given then all elements are
returned.

The array is sorted by the copy timestamp: the first element in the
array is the one most recently copied.

=item C<get_entry [$type]>

Returns the most recently clipped object whose type matches the
regular expression C<$type>. If C<$type> is not given then the
most recently copied object is returned.

If no such object exists C<undef> is returned instead.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
