package SL::Clipboard::Base;

use strict;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(content timestamp) ],
);

use Rose::DB::Object::Helpers ();

sub init_timestamp { die "'timestamp' property not set"; }
sub init_content   { die "'content' property not set";   }

sub type {
  my ($self_or_class) = @_;
  return (split m/::/, ref($self_or_class) ? ref($self_or_class) : $self_or_class)[-1];
}

sub reload_object {
  my ($self, $object) = @_;

  return ref($object)->new(map { $_ => $object->$_ } $object->meta->primary_key)->load;
}

sub as_tree {
  my ($self, $object, %params) = @_;

  my $tree = Rose::DB::Object::Helpers::as_tree($object, %params);
  $self->_fix_tree($tree, $object);
  return $tree;
}

sub to_object {
  my ($self) = @_;
  my $object = Rose::DB::Object::Helpers::new_from_tree("SL::DB::" . $self->type, $self->content);

  # Reset primary key columns and itime/mtime if the class supports it.
  foreach ($object->meta->primary_key, 'itime', 'mtime') {
    $object->$_(undef) if $object->can($_);
  }

  # Let sub classes fix the objects further.
  $self->_fix_object($object);
  return $object;
}

sub dump {
  my ($self, $object) = @_;
  return $self->as_tree($self->reload_object($object), max_depth => 1);
}

sub describe {
  die "'describe' method not overwritten by derived class";
}

sub _fix_object {
  my ($self, $object) = @_;
  # To be overwritten by child classes.
}

sub _fix_tree {
  my ($self, $tree, $object) = @_;

  # Delete primary key columns and itime/mtime if the class supports it.
  foreach ($object->meta->primary_key, 'itime', 'mtime') {
    delete $tree->{$_} if $object->can($_);
  }
}

sub _binary_column_names {
  my ($self, $class) = @_;
  return map  { $_->name }
         grep { ref($_) =~ m/Pg::Bytea$/i }
         @{ $class->meta->columns };
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Clipboard::Base - Base class for clipboard specialization classes

=head1 SYNOPSIS

See the synopsis of L<SL::Clipboard>.

=head1 OVERVIEW

This is a base class providing a lot of utility and
defaults. Sub-classes must overwrite at least the function
L</describe> but can overwrite others as well.

Writing a specialized sub-class for a database type involves
overwriting one or more functions. These are:

=over 4

=item * C<describe>

Must be overwritten. Returns a human-readable description of the
content. Should only be one line.

=item * C<dump>

Optional. Overwrite if sub-class needs to dump more/less than the
implementation in this class dumps.

=item * C<_fix_object>

Optional. Overwrite if re-created Rose::DB::Object instances must be
cleaned further before they're returned to the caller.

=item * C<_fix_tree>

Optional. Overwrite if the tree created during a copy operation of a
Rose::DB::Object instance must be cleaned further before it's stored.

=back

You don't have to or should not overwrite the other functions:

=over 4

=item * C<as_tree>

=item * C<reload_object>

=item * C<to_object>

=item * C<type>

=back

Don't forget to C<use> the specialized module here in Base!

=head1 FUNCTIONS

=over 4

=item C<as_tree $object, %params>

A convenience function calling L<Rose::DB::Object::Helpers/as_tree>
with C<$object> and C<%params> as parameters. Returns a hash/array
reference tree of the function.

Don't overwrite this function in sub-classes. Overwrite L</dump>
instead.

=item C<describe>

Returns a human-readable description of the content. This should only
be a single line without any markup.

Sub-classes must overwrite this function.

=item C<dump $object>

Dumps the object as a hash/array tree and returns it by calling
L<Rose::DB::Object::Helpers/as_tree>. The default implementation
reloads the object first by calling L</reload_object>. It also only
dumps the object itself, not any of the relationships, by calling
C<as_tree> with the parameter C<max_depth =E<gt> 1>.

Overwrite this in a sub-class if you need to dump more or differently
(see L<SL::Clipboard::RequirementSpecItem> for an example).

=item C<reload_object $object>

Reloads C<$object> from the database and returns a new instance. Can
be useful for sanitizing the object given to L</dump> before
converting into a tree. It is used by the default implementation of
L</dump>.

=item C<to_object>

Converts the dumped representation back to a Rose::DB::Object
instance. Several columns of the newly created object are cleared by
C<to_object> itself: the primary key columns (if any) and the columns
C<itime> and C<mtime> (if the object has such columns).

This function should not be overwritten by sub-classes. Instead,
functions can overwrite C<_fix_object> which can be used for sanitizing
the newly created object before handing it back to the caller.

=item C<type>

Returns the actual clipped type (e.g. C<RequirementSpecItem>). This is
derived from the actual class name of C<$self>.

=item C<_binary_column_names $class>

Returns an array of column names that have a binary type. Useful for
sub-classes which need to encode binary content in Base64 during
C<dump>.

=item C<_fix_object $object>

This function is called by L</to_object> before the object is passed
back to the caller. It does not do anything in the default
implementation, but sub-classes are free to overwrite it if they need
to sanitize the object. See L<SL::Clipboard::RequirementSpecItem> for
an example.

Its return value is ignored.

=item C<_fix_tree $tree, $object>

This function is called by L</as_tree> after dumping and before the
object is stored during a copy operation. In the default
implementation all primary key columns and the columns C<itime> and
C<mtime> (if the object has such columns) are removed from the tree.
Sub-classes are free to overwrite it if they need to sanitize the
tree. See L<SL::Clipboard::RequirementSpecItem> for an example.

C<$object> is just passed in for reference and should not be modified.

Its return value is ignored.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
