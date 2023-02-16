package SL::DB::Helper::TypeDataProxy;

use strict;

sub new {
  my ($class, $record_class, $type) = @_;

  my $type_data_class = $record_class . '::TypeData';
  eval "require $type_data_class" or die "invalid type data class '$type_data_class'";

  bless [
    $type,
    $type_data_class
  ], $class;
}

# convenience methods for common topics in type data
sub text {
  _via("get3", [ "text" ], @_);
}

sub properties {
  _via("get3", [ "properties" ], @_);
}

sub defaults {
  _via("get3", [ "defaults" ], @_);
}

sub show_menu {
  _via("get3", [ "show_menu" ], @_);
}

sub rights {
  _via("get3", [ "rights" ], @_);
}

sub _via {
  my $method = shift;
  my $additional_args = shift;
  my $self = shift;
  $self->[1]->can($method)->($self->[0], @$additional_args, @_);
}

sub AUTOLOAD {
  our $AUTOLOAD;

  my ($self, @args) = @_;

  my $method = $AUTOLOAD;
  $method    =~ s/.*:://;

  return if $method eq 'DESTROY';

  if (my $sub = $self->[1]->can($method)) {
    return $sub->($self->[0], @args);
  } else {
    die "no method $method in $self->[1]";
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::TypeDataProxy - proxy for accessing type data from a record instance

=head1 SYNOPSIS

    # in a SL::DB::Record type
    sub type_data {
      SL::DB::Helper::TypeDataProxy->new(ref $_[0], $_[0]->type);
    }

    # in consuming code with a record object
    # the methods are only available if the TypeData class supports them
    $record->type_data->is_type(...)
    $record->type_data->valid_types
    $record->type_data->text('edit')
    $record->type_data->properties('is_customer')

=head1 DESCRIPTION

Wrap the static type information of a given record into an accessible sub object.
Only works if a TypeData class exists that knows about the return values of the given type
Since this does not operate on the live objects but rather wraps a snapshot,
this will not get updated if the creating object changes.

=head1 PROXIED METHODS

=over 4

=item * C<valid_types>

Returns the known sub types of this record

=item * C<is_type> $type

Checks whether this record is of the given type

=item * C<is_valid_type>

=item * C<validate_type>

Check whether this record has a valid type. C<is_valid_type> returns boolish, C<validate_type> will throw if the validation fails.

=item * C<text> $action

Returns the translated text for this action and action

=item * C<properties> $property

Returns the named property for this type

=item * C<show_menu> $action

Rtuens whether the given menu action is valid for this type

=item * C<rights> $action

Returns the needed rights for this action with this type

=back

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schöling $<lt>s.schoeling@googlemail.comE<gt>

=cut
