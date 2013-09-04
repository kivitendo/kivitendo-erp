package SL::DB::Object;

use strict;

use English qw(-no_match_vars);
use Rose::DB::Object;
use List::MoreUtils qw(any);

use SL::DB;
use SL::DB::Helper::Attr;
use SL::DB::Helper::Metadata;
use SL::DB::Helper::Manager;
use SL::DB::Object::Hooks;

use base qw(Rose::DB::Object);

my @rose_reserved_methods = qw(
  db dbh delete DESTROY error init_db _init_db insert load meta meta_class
  not_found save update import
);

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new();

  $self->_assign_attributes(@_) if $self;

  return $self;
}

sub init_db {
  my $class_or_self = shift;
  my $class         = ref($class_or_self) || $class_or_self;
  my $type          = $class =~ m/::Auth/ ? 'KIVITENDO_AUTH' : 'KIVITENDO';

  return SL::DB::create(undef, $type);
}

sub meta_class {
  return 'SL::DB::Helper::Metadata';
}

sub _get_manager_class {
  my $class_or_self = shift;
  my $class         = ref($class_or_self) || $class_or_self;

  return $class->meta->convention_manager->auto_manager_class_name($class);
}

my %text_column_types = (text => 1, char => 1, varchar => 1);

sub assign_attributes {
  my $self       = shift;
  my %attributes = @_;

  my $pk         = ref($self)->meta->primary_key;
  delete @attributes{$pk->column_names} if $pk;
  delete @attributes{@rose_reserved_methods};

  return $self->_assign_attributes(%attributes);
}

sub _assign_attributes {
  my $self       = shift;
  my %attributes = @_;

  my %types      = map { $_->name => $_->type } ref($self)->meta->columns;

  # Special case for *_as_man_days / *_as_man_days_string /
  # *_as_man_days_unit: the _unit variation must always be called
  # after the non-unit methods.
  my @man_days_attributes = grep { m/_as_man_days(?:_string)?$/ } keys %attributes;
  foreach my $attribute (@man_days_attributes) {
    my $value = delete $attributes{$attribute};
    $self->$attribute(defined($value) && ($value eq '') ? undef : $value);
  }

  while (my ($attribute, $value) = each %attributes) {
    my $type = lc($types{$attribute} || 'text');
    $value   = $type eq 'boolean'                ? ($value ? 't' : 'f')
             : $text_column_types{$type}         ? $value
             : defined($value) && ($value eq '') ? undef
             :                                     $value;
    $self->$attribute($value);
  }

  return $self;
}

sub update_attributes {
  my $self = shift;

  $self->assign_attributes(@_)->save;

  return $self;
}

sub call_sub {
  my $self = shift;
  my $sub  = shift;
  return $self->$sub(@_);
}

sub call_sub_if {
  my $self  = shift;
  my $sub   = shift;
  my $check = shift;

  $check    = $check->($self) if ref($check) eq 'CODE';

  return $check ? $self->$sub(@_) : $self;
}

sub get_first_conflicting {
  my ($self, @attributes) = @_;

  my $primary_key         = ($self->meta->primary_key)[0];
  my @where               = map { ($_ => $self->$_) } @attributes;

  push @where, ("!$primary_key" => $self->$primary_key) if $self->$primary_key;

  return $self->_get_manager_class->get_first(where => [ and => \@where ]);
}

# These three functions cannot sit in SL::DB::Object::Hooks because
# mixins don't deal well with super classes (SUPER is the current
# package's super class, not $self's).
sub load {
  my ($self, @args) = @_;

  SL::DB::Object::Hooks::run_hooks($self, 'before_load');
  my $result = $self->SUPER::load(@args);
  SL::DB::Object::Hooks::run_hooks($self, 'after_load', $result);

  return $result;
}

sub save {
  my ($self, @args) = @_;

  my ($result, $exception);
  my $worker = sub {
    $exception = $EVAL_ERROR unless eval {
      SL::DB::Object::Hooks::run_hooks($self, 'before_save');
      $result = $self->SUPER::save(@args);
      SL::DB::Object::Hooks::run_hooks($self, 'after_save', $result);
      1;
    };

    return $result;
  };

  $self->db->in_transaction ? $worker->() : $self->db->do_transaction($worker);

  die $exception if $exception;

  return $result;
}

sub delete {
  my ($self, @args) = @_;

  my ($result, $exception);
  my $worker = sub {
    $exception = $EVAL_ERROR unless eval {
      SL::DB::Object::Hooks::run_hooks($self, 'before_delete');
      $result = $self->SUPER::delete(@args);
      SL::DB::Object::Hooks::run_hooks($self, 'after_delete', $result);
      1;
    };

    return $result;
  };

  $self->db->in_transaction ? $worker->() : $self->db->do_transaction($worker);

  die $exception if $exception;

  return $result;
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

=item C<call_sub $name, @args>

Calls the sub C<$name> on C<$self> with the arguments C<@args> and
returns its result. This is meant for situations in which the sub's
name is a composite, e.g.

  my $chart_id = $buchungsgruppe->call_sub(($is_sales ? "income" : "expense") . "_accno_id_${taxzone_id}");

=item C<call_sub_if $name, $check, @args>

Calls the sub C<$name> on C<$self> with the arguments C<@args> if
C<$check> is trueish. If C<$check> is a code reference then it will be
called with C<$self> as the only argument and its result determines
whether or not C<$name> is called.

Returns the sub's result if the check is positive and C<$self>
otherwise.

=item C<get_first_conflicting @attributes>

Returns the first object for which all properties listed in
C<@attributes> equal those in C<$self> but which is not C<$self>. Can
be used to check whether or not an object's columns are unique before
saving or during validation.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
