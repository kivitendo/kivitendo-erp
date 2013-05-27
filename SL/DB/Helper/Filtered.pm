package SL::DB::Helper::Filtered;

use strict;
use SL::Controller::Helper::ParseFilter ();

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw (filter add_filter_specs);

my %filter_spec;

sub filter {
  my ($class, $key, $value, $prefix) = @_;

  my $filters = _get_filters($class);

  return ($key, $value) unless $filters->{$key};

  return $filters->{$key}->($key, $value, $prefix);
}

sub _get_filters {
  my ($class) = @_;
  return $filter_spec{$class} ||= {};
}

sub add_filter_specs {
  my $class = shift;

  my $filters = _get_filters($class);

  while (@_ > 1) {
    my $key          = shift;
    $filters->{$key} = shift;
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::Sorted - Manager mixin for filtered results.

=head1 SYNOPSIS

In the manager:

  use SL::Helper::Filtered;

  __PACKAGE__->add_filter_specs(
    custom_filter_name => sub {
      my ($key, $value, $prefix) = @_;
      # code to handle this
      return ($key, $value, $with_objects);
    },
    another_filter_name => \&_sub_to_handle_this,
  );

In consuming code:

  ($key, $value, $with_objects) = $manager_class->filter($key, $value, $prefix);

=head1 FUNCTIONS

=over 4

=item C<add_filter_specs %PARAMS>

Adds new filters to this package as key value pairs. The key will be the new
filters name, the value is expected to be a coderef to an implementation of
this filter. See L<INTERFACE OF A CUSTOM FILTER> for details on this.

You can add multiple filters in one call, but only one filter per key.

=item C<filter $key, $value, $prefix>

Tells the manager to pply custom filters. If none is registered for C<$key>,
returns C<$key, $value>.

Otherwise the filter code is called.

=back

=head1 INTERFACE OF A CUSTOM FILTER

Lets look at an example of a working filter. Suppose your model has a lot of
notes fields, and you need to search in all of them. A working filter would be:

  __PACKAGE__->add_filter_specs(
    all_notes => sub {
      my ($key, $value, $prefix) = @_;

      return or => [
        $prefix . notes1 => $value,
        $prefix . notes2 => $value,
      ];
    }
  );

If someone filters for C<filter.model.all_notes:substr::ilike=telephone>, your
filter will get called with:

  ->filter('all_notes', { ilike => '%telephone%' }, '')

and the result will be:

  or => [
    notes1 => { notes1 => '%telephone%' },
    notes2 => { notes1 => '%telephone%' },
  ]

The prefix is to make sure this also works when called on submodels:

  C<filter.customer.model.all_notes:substr::ilike=telephone>

will pass C<customer.> as prefix so that the resulting query will be:

  or => [
    customer.notes1 => { notes1 => '%telephone%' },
    customer.notes2 => { notes1 => '%telephone%' },
  ]

which is pretty much what you would expect.

As a final touch consider a filter that needs to search somewhere else to work,
like this one:

  __PACKAGE__->add_filter_specs(
    name => sub {
      my ($key, $value, $prefix) = @_;

      return $prefix . person.name => $value,
             $prefix . 'person';
    },
  };

Now you can search for C<name> in your model without ever knowing that the real
name lies in the table C<person>. Unfortunately Rose has to know about it to
get the joins right, and so you need to tell it to include C<person> into its
C<with_objects>. That's the reason for the third return value.


To summarize:

=over 4

=item *

You will get passed the name of your filter as C<$key> stripped of all filters
and escapes.

=item *

You will get passed the C<$value> processed with all filters and escapes.

=item *

You will get passed a C<$prefix> that can be prepended to all database columns
to make sense to Rose.

=item *

You are expeceted to return exactly one key and one value. That can mean you
have to encapsulate your arguments into C<< or => [] >> or C<< and => [] >> blocks.

=item *

If your filter needs relationships that are not always loaded, you need to
return them in C<with_objects> style. If you need to return more than one, use
an arrayref.

=back

=head1 BUGS

None yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
