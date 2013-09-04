package SL::Controller::Helper::ParseFilter;

use strict;

use Exporter qw(import);
our @EXPORT = qw(parse_filter);

use DateTime;
use SL::Helper::DateTime;
use List::MoreUtils qw(uniq);
use SL::MoreCommon qw(listify);
use Data::Dumper;

my %filters = (
  date    => sub { DateTime->from_lxoffice($_[0]) },
  number  => sub { $::form->parse_amount(\%::myconfig, $_[0]) },
  percent => sub { $::form->parse_amount(\%::myconfig, $_[0]) / 100 },
  head    => sub { $_[0] . '%' },
  tail    => sub { '%' . $_[0] },
  substr  => sub { '%' . $_[0] . '%' },
);

my %methods = (
  enable => sub { ;;;; },
  eq_ignore_empty => sub { ($_[0] // '') eq '' ? () : +{ eq => $_[0] } },
  map {
    # since $_ is an alias it can't be used in a closure. even "".$_ or "$_"
    # does not work, we need a real copy.
    my $_copy = "$_";
    $_   => sub { +{ $_copy    => $_[0] } },
  } qw(similar match imatch regex regexp like ilike rlike is is_not ne eq lt gt le ge),
);

sub parse_filter {
  my ($filter, %params) = @_;

  my $objects      = $params{with_objects} || [];

  my ($flattened, $auto_objects) = flatten($filter, '', %params);

  if (!$params{class}) {
    _add_uniq($objects, $_) for @$auto_objects;
  }

  my $query = _parse_filter($flattened, $objects, %params);

  _launder_keys($filter, $params{launder_to}) unless $params{no_launder};

  return
    ($query   && @$query   ? (query => $query) : ()),
    ($objects && @$objects ? ( with_objects => [ uniq @$objects ]) : ());
}

sub _launder_keys {
  my ($filter, $launder_to) = @_;
  $launder_to ||= $filter;
  return unless ref $filter eq 'HASH';
  for my $key (keys %$filter) {
    my $orig = $key;
    $key =~ s/:/_/g;
    if ('' eq ref $filter->{$orig}) {
      $launder_to->{$key} = $filter->{$orig};
    } elsif ('ARRAY' eq ref $filter->{$orig}) {
      $launder_to->{"${key}_"} = { map { $_ => 1 } @{ $filter->{$orig} } };
    } else {
      $launder_to->{$key} ||= { };
      _launder_keys($filter->{$key}, $launder_to->{$key});
    }
  };
}

sub flatten {
  my ($filter, $prefix, %params) = @_;

  return (undef, []) unless 'HASH'  eq ref $filter;
  my $with_objects = [];

  my @result;

  while (my ($key, $value) = each %$filter) {
    next if !defined $value || $value eq ''; # 0 is fine
    if ('HASH' eq ref $value) {
      my ($query, $more_objects) = flatten($value, _prefix($prefix, $key));
      push @result, @$query        if  $query;
      _add_uniq($with_objects, $_) for _prefix($prefix, $key), @$more_objects;
    } else {
      push @result, _prefix($prefix, $key) => $value;
    }
  }

  return \@result, $with_objects;
}

sub _parse_filter {
  my ($flattened, $with_objects, %params) = @_;

  return () unless 'ARRAY' eq ref $flattened;

  $flattened = _collapse_indirect_filters($flattened);

  my @result;
  for (my $i = 0; $i < scalar @$flattened; $i += 2) {
    my ($key, $value) = ($flattened->[$i], $flattened->[$i+1]);

    ($key, $value) = _apply_all($key, $value, qr/\b:(\w+)/,  { %filters, %{ $params{filters} || {} } });
    ($key, $value) = _apply_all($key, $value, qr/\b::(\w+)/, { %methods, %{ $params{methods} || {} } });
    ($key, $value) = _dispatch_custom_filters($params{class}, $with_objects, $key, $value) if $params{class};

    push @result, $key, $value;
  }
  return \@result;
}

sub _dispatch_custom_filters {
  my ($class, $with_objects, $key, $value) = @_;

  # the key should by now have no filters left
  # if it has, catch it here:
  die 'unrecognized filters' if $key =~ /:/;

  my @tokens     = split /\./, $key;
  my $last_token = pop @tokens;
  my $curr_class = $class->object_class;

  for my $token (@tokens) {
    eval {
      $curr_class = $curr_class->meta->relationship($token)->class;
      1;
    } or do {
      require Carp;
      Carp::croak("Could not resolve the relationship '$token' in '$key' while building the filter request");
    }
  }

  my $manager    = $curr_class->meta->convention_manager->auto_manager_class_name;
  my $obj_path   = join '.', @tokens;
  my $obj_prefix = join '.', @tokens, '';

  if ($manager->can('filter')) {
    ($key, $value, my $obj) = $manager->filter($last_token, $value, $obj_prefix);
    _add_uniq($with_objects, $obj) if $obj;
  } else {
    _add_uniq($with_objects, $obj_path) if $obj_path;
  }

  return ($key, $value);
}

sub _add_uniq {
   my ($array, $what) = @_;

   $array //= [];
   @$array = (uniq @$array, listify($what));
}

sub _collapse_indirect_filters {
  my ($flattened) = @_;

  die 'flattened filter array length is uneven, should be possible to use as hash' if @$flattened % 2;

  my (%keys_to_delete, %keys_to_move, @collapsed);

  # search keys matching /::$/;
  for (my $i = 0; $i < scalar @$flattened; $i += 2) {
    my ($key, $value) = ($flattened->[$i], $flattened->[$i+1]);

    next unless $key =~ /^(.*\b)::$/;

    $keys_to_delete{$key}++;
    $keys_to_move{$1} = $1 . '::' . $value;
  }

  for (my $i = 0; $i < scalar @$flattened; $i += 2) {
    my ($key, $value) = ($flattened->[$i], $flattened->[$i+1]);

    if ($keys_to_move{$key}) {
      push @collapsed, $keys_to_move{$key}, $value;
      next;
    }
    if (!$keys_to_delete{$key}) {
      push @collapsed, $key, $value;
    }
  }

  return \@collapsed;
}

sub _prefix {
  join '.', grep $_, @_;
}

sub _apply {
  my ($value, $name, $filters) = @_;
  return $value unless $name && $filters->{$name};
  return [ map { _apply($_, $name, $filters) } @$value ] if 'ARRAY' eq ref $value;
  return $filters->{$name}->($value);
}

sub _apply_all {
  my ($key, $value, $re, $subs) = @_;

  while ($key =~ s/$re//) {
    $value = _apply($value, $1, $subs);
  }

  return $key, $value;
}

1;

__END__

=head1 NAME

SL::Controller::Helper::ParseFilter - Convert a form filter spec into a RDBO get_all filter

=head1 SYNOPSIS

  use SL::Controller::Helper::ParseFilter;
  SL::DB::Object->get_all(parse_filter($::form->{filter}));

  # or more complex
  SL::DB::Object->get_all(parse_filter($::form->{filter},
    with_objects => [ qw(part customer) ]));

=head1 DESCRIPTION

A search filter will usually search for things in relations of the actual
search target. A search for sales orders may be filtered by the name of the
customer. L<Rose::DB::Object> alloes you to search for these by filtering them prefixed with their table:

  query => [
    'customer.name'          => 'John Doe',
    'department.description' => [ ilike => '%Sales%' ],
    'orddate'                => [ lt    => DateTime->today ],
  ]

Unfortunately, if you specify them in you form as these strings, the form
parser will convert them into nested structures like this:

  $::form = bless {
    filter => {
      customer => {
        name => 'John Doe',
      },
    },
  }, Form;

And the substring match requires you to recognize the ilike, and modify the value.

C<parse_filter> tries to ease this by recognizing these structures and
providing suffixes for common search patterns.

=head1 FUNCTIONS

=over 4

=item C<parse_filter \%FILTER, [ %PARAMS ]>

First argument is the filter from form. It is highly recommended that you put
all filter attributes into a named container as to not confuse them with the
rest of your form.

Nested structures will be parsed and interpreted as foreign references. For
example if you search for L<Order>s, this input will search for those with a
specific L<Salesman>:

  [% L.select_tag('filter.salesman.id', ...) %]

Additionally you can add modifier to the name to set a certain method:

  [% L.input_tag('filter.department.description:substr::ilike', ...) %]

This will add the "% .. %" wildcards for substr matching in SQL, and add an
C<< ilike => $value >> block around it to match case insensitively.

As a rule all value filters require a single colon and must be placed before
match method suffixes, which are appended with 2 colons. See below for a full
list of modifiers.

=back

=head1 LAUNDERING

Unfortunately Template cannot parse the postfixes if you want to
rerender the filter. For this reason all colons filter keys are by
default laundered into underscores, so you can use them like this:

  [% L.input_tag('filter.price:number::lt', filter.price_number__lt) %]

Also Template has trouble when looking up the contents of arrays, so
these will get copied into a _ suffixed version as hashes:

  [% L.checkbox_tag('filter.ids[]', value=15, checked=filter.ids_.15) %]

All of your original entries will stay intact. If you don't want this to
happen pass C<< no_launder => 1 >> as a parameter.  Additionally you can pass a
different target for the laundered values with the C<launder_to>  parameter. It
takes an hashref and will deep copy all values in your filter to the target. So
if you have a filter that looks like this:

  $filter = {
    'price:number::lt' => '2,30',
    closed             => '1',
    type               => [ 'part', 'assembly' ],
  }

and parse it with

  parse_filter($filter, launder_to => $laundered_filter = { })

the original filter will be unchanged, and C<$laundered_filter> will end up
like this:

  $filter = {
    'price_number__lt' => '2,30',
     closed            => '1',
    'type_'            => { part => 1, assembly => 1 },
  }

=head1 INDIRECT FILTER METHODS

The reason for the method being last is that it is possible to specify the
method in another input. Suppose you want a date input and a separate
before/after/equal select, you can use the following:

  [% L.date_tag('filter.appointed_date:date', ... ) %]

and later

  [% L.select_tag('filter.appointed_date:date::', ... ) %]

The special empty method will be used to set the method for the previous
method-less input.

=head1 CUSTOM FILTERS FROM OBJECTS

If the L<parse_filter> call contains a parameter C<class>, custom filters will
be honored. Suppose you have added a custom filter 'all' for parts which
expands to search both description and partnumber, the following

  $filter = {
    'part.all:substr::ilike' => 'A1',
  }

will expand to:

  query => [
    or => [
      part.description => { ilike => '%A1%' },
      part.partnumber  => { ilike => '%A1%' },
    ]
  ]

For more abuot custom filters, see L<SL::DB::Helper::Filtered>.

=head1 FILTERS (leading with :)

The following filters are built in, and can be used.

=over 4

=item date

Parses the input string with C<< DateTime->from_lxoffice >>

=item number

Pasres the input string with C<< Form->parse_amount >>

=item percent

Parses the input string with C<< Form->parse_amount / 100 >>

=item head

Adds "%" at the end of the string.

=item tail

Adds "%" at the end of the string.

=item substr

Adds "% .. %" around the search string.

=item eq_ignore_empty

Ignores this item if it's empty. Otherwise compares it with the
standard SQL C<=> operator.

=back

=head2 METHODS (leading with ::)

=over 4

=item lt

=item gt

=item ilike

=item like

All these are recognized like the L<Rose::DB::Object> methods.

=back

=head1 BUGS AND CAVEATS

This will not properly handle multiple versions of the same object in different
context.

Suppose you want all L<SL::DB::Order>s which have either themselves a certain
customer, or are linked to a L<SL::DB::Invoice> with this customer, the
following will not work as you expect:

  # does not work!
  L.input_tag('customer.name:substr::ilike', ...)
  L.input_tag('invoice.customer.name:substr::ilike', ...)

This will sarch for orders whose invoice has the _same_ customer, which matches
both inputs. This is because tables are aliased by their name and not by their
position in with_objects.

=head1 TODO

=over 4

=item *

Additional filters shoud be pluggable.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
