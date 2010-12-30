package SL::DB::Object;

use strict;

use Readonly;
use Rose::DB::Object;
use List::MoreUtils qw(any);

use SL::DB;
use SL::DB::Helpers::Attr;
use SL::DB::Helpers::Metadata;
use SL::DB::Helpers::Manager;

use base qw(Rose::DB::Object);

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new();

  $self->_assign_attributes(@_) if $self;

  return $self;
}

sub init_db {
  my $class_or_self = shift;
  my $class         = ref($class_or_self) || $class_or_self;
  my $type          = $class =~ m/::Auth/ ? 'LXOFFICE_AUTH' : 'LXOFFICE';

  return SL::DB::create(undef, $type);
}

sub meta_class {
  return 'SL::DB::Helpers::Metadata';
}

sub _get_manager_class {
  my $class_or_self = shift;
  my $class         = ref($class_or_self) || $class_or_self;

  return $class->meta->convention_manager->auto_manager_class_name($class);
}

Readonly my %text_column_types => (text => 1, char => 1, varchar => 1);

sub assign_attributes {
  my $self       = shift;
  my %attributes = @_;

  my $pk         = ref($self)->meta->primary_key;
  delete @attributes{$pk->column_names} if $pk;

  return $self->_assign_attributes(%attributes);
}

sub _assign_attributes {
  my $self       = shift;
  my %attributes = @_;

  my %types      = map { $_->name => $_->type } ref($self)->meta->columns;

  while (my ($attribute, $value) = each %attributes) {
    my $type = lc($types{$attribute} || 'text');
    $value   = $type eq 'boolean'        ? ($value ? 't' : 'f')
             : $text_column_types{$type} ? $value
             :                             ($value || undef);
    $self->$attribute($value);
  }

  return $self;
}

sub update_attributes {
  my $self = shift;

  $self->assign_attributes(@_)->save;

  return $self;
}

1;

__END__

=pod

=head1 NAME

SL::DB::Object: Base class for all of our model classes

=head1 DESCRIPTION

This is the base class from which all other model classes are
derived. It contains functionality and settings required for all model
classes.

Several functions (e.g. C<make_manager_class>, C<init_db>) in this
class are used for setting up the classes / base classes used for all
model instances. They overwrite the functions from
L<Rose::DB::Object>.

=head1 FUNCTIONS

=over 4

=item assign_attributes %attributes

=item _assign_attributes %attributes

Assigns all elements from C<%attributes> to the columns by calling
their setter functions. The difference between the two functions is
that C<assign_attributes> protects primary key columns while
C<_assign_attributes> doesn't.

Both functions handle values that are empty strings by replacing them
with C<undef> for non-text columns. This allows the calling functions
to use data from HTML forms as the input for C<assign_attributes>
without having to remove empty strings themselves (think of
e.g. select boxes with an empty option which should be turned into
C<NULL> in the database).

=item update_attributes %attributes

Assigns the attributes from C<%attributes> by calling the
C<assign_attributes> function and saves the object afterwards. Returns
the object itself.

=item _get_manager_class

Returns the manager package for the object or class that it is called
on. Can be used from methods in this package for getting the actual
object's manager.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
