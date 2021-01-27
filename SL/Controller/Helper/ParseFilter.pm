package SL::Controller::Helper::ParseFilter;

use strict;

use Exporter qw(import);
our @EXPORT = qw(parse_filter);

use DateTime;
use SL::Helper::DateTime;
use List::MoreUtils qw(uniq);
use SL::Util qw(trim);
use SL::MoreCommon qw(listify);
use Data::Dumper;
use Text::ParseWords;

sub _lazy_bool_eq {
  my ($key, $value) = @_;

  return ()                                   if ($value // '') eq '';
  return (or => [ $key => undef, $key => 0 ]) if !$value;
  return ($key => 1);
}

my %filters = (
  date    => sub { DateTime->from_lxoffice($_[0]) },
  number  => sub { $::form->parse_amount(\%::myconfig, $_[0]) },
  percent => sub { $::form->parse_amount(\%::myconfig, $_[0]) / 100 },
  head    => sub { trim($_[0]) . '%' },
  tail    => sub { '%' . trim($_[0]) },
  substr  => sub { '%' . trim($_[0]) . '%' },
  trim    => sub { trim($_[0]) },
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

my %complex_methods = (
  lazy_bool_eq => \&_lazy_bool_eq,
);

sub parse_filter {
  my ($filter, %params) = @_;

  my $objects      = $params{with_objects} || [];

  my ($flattened, $auto_objects) = flatten($filter, '', %params);

  if (!$params{class}) {
    _add_uniq($objects, $_) for @$auto_objects;
  }

  _launder_keys($filter, $params{launder_to}) unless $params{no_launder};

  my $query = _parse_filter($flattened, $objects, %params);

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

  my $all_filters = { %filters,         %{ $params{filters}         || {} } };
  my $all_methods = { %methods,         %{ $params{methods}         || {} } };
  my $all_complex = { %complex_methods, %{ $params{complex_methods} || {} } };

  my @result;
  for (my $i = 0; $i < scalar @$flattened; $i += 2) {
    my (@args, @filters, $method);

    my ($key, $value) = ($flattened->[$i], $flattened->[$i+1]);
    my ($type, $op)   = $key =~ m{:(.+)::(.+)};

    my $is_multi      = $key =~ s/:multi//;
    my @value_tokens  = $is_multi ? parse_line('\s+', 0, $value) : ($value);

    ($key, $method)   = split m{::}, $key, 2;
    ($key, @filters)  = split m{:},  $key;

    my $orig_key      = $key;

    for my $value_token (@value_tokens) {
      $key                 = $orig_key;

      $value_token         = _apply($value_token, $_, $all_filters) for @filters;
      $value_token         = _apply($value_token, $method, $all_methods)                                 if $method && exists $all_methods->{$method};
      ($key, $value_token) = _apply_complex($key, $value_token, $method, $all_complex)                   if $method && exists $all_complex->{$method};
      ($key, $value_token) = _dispatch_custom_filters($params{class}, $with_objects, $key, $value_token) if $params{class};
      ($key, $value_token) = _apply_value_filters($key, $value_token, $type, $op);

      push @args, $key, $value_token;
    }

    next unless defined $key;

    push @result, $is_multi ? (and => [ @args ]) : @args;
  }
  return \@result;
}

sub _apply_value_filters {
  my ($key, $value, $type, $op) = @_;

  return ($key, $value) unless $key && $value && $type && $op && (ref($value) eq 'HASH');

  if (($type eq 'date') && ($op eq 'le')) {
    my $date     = delete $value->{le};
    $value->{lt} = $date->add(days => 1);
  }

  return ($key, $value);
}

sub _dispatch_custom_filters {
  my ($class, $with_objects, $key, $value) = @_;

  # the key should by now have no filters left
  # if it has, catch it here:
  die 'unrecognized filters' if $key =~ /:/;

  my @tokens     = split /\./, $key;
  my $curr_class = $class->object_class;

  # our key will consist of dot-delimited tokens
  # like this: order.part.unit.name
  # each of these tokens except the last one is one of:
  #  - a relationship in the parent object
  #  - a custom filter
  #
  # the last token must be
  #  - a custom filter
  #  - a column in the parent object
  #
  # find first token which is not a relationship,
  # so we can pass the rest on
  my $i = 0;
   while ($i < $#tokens) {
    eval {
      $curr_class = $curr_class->meta->relationship($tokens[$i])->class;
      ++$i;
    } or do {
      last;
    }
  }

  my $manager    = $curr_class->meta->convention_manager->auto_manager_class_name;
  my $obj_path   = join '.', @tokens[0..$i-1];
  my $obj_prefix = join '.', @tokens[0..$i-1], '';
  my $key_token  = $tokens[$i];
  my @additional_tokens = @tokens[$i+1..$#tokens];

  if ($manager->can('filter')) {
    ($key, $value, my $obj) = $manager->filter($key_token, $value, $obj_prefix, $obj_path, @additional_tokens);
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

sub _apply_complex {
  my ($key, $value, $name, $filters) = @_;
  return $key, $value unless $name && $filters->{$name};
  return $filters->{$name}->($key, $value);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::ParseFilter - Convert a form filter spec into a RDBO get_all filter

=head1 SYNOPSIS

  use SL::Controller::Helper::ParseFilter;
  SL::DB::Manager::Object->get_all(parse_filter($::form->{filter}));

  # or more complex
  SL::DB::Manager::Object->get_all(parse_filter($::form->{filter},
    with_objects => [ qw(part customer) ]));

=head1 DESCRIPTION

A search filter will usually search for things in relations of the actual
search target. A search for sales orders may be filtered by the name of the
customer. L<Rose::DB::Object> allows you to search for these by filtering them prefixed with their table:

  query => [
    'customer.name'          => 'John Doe',
    'department.description' => [ ilike => '%Sales%' ],
    'orddate'                => [ lt    => DateTime->today ],
  ]

Unfortunately, if you specify them in your form as these strings, the form
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

Additionally you can add a modifier to the name to set a certain method:

  [% L.input_tag('filter.department.description:substr::ilike', ...) %]

This will add the "% .. %" wildcards for substr matching in SQL, and add an
C<< ilike => $value >> block around it to match case insensitively.

As a rule all value filters require a single colon and must be placed before
match method suffixes, which are appended with 2 colons. See below for a full
list of modifiers.

=back

=head1 LAUNDERING

Unfortunately Template cannot parse the postfixes if you want to
rerender the filter. For this reason all colon filter keys are by
default laundered into underscores, so you can use them like this:

  [% L.input_tag('filter.price:number::lt', filter.price_number__lt) %]

Also Template has trouble when looking up the contents of arrays, so
these will get copied into a _ suffixed version as hashes:

  [% L.checkbox_tag('filter.ids[]', value=15, checked=filter.ids_.15) %]

All of your original entries will stay intact. If you don't want this to
happen pass C<< no_launder => 1 >> as a parameter.  Additionally you can pass a
different target for the laundered values with the C<launder_to>  parameter. It
takes a hashref and will deep copy all values in your filter to the target. So
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

For more about custom filters, see L<SL::DB::Helper::Filtered>.

=head1 FILTERS (leading with :)

The following filters are built in, and can be used.

=over 4

=item date

Parses the input string with C<< DateTime->from_lxoffice >>

=item number

Pasres the input string with C<< Form->parse_amount >>

=item percent

Parses the input string with C<< Form->parse_amount / 100 >>

=item trim

Removes whitespace characters (to be precice, characters with the \p{WSpace}
property from beginning and end of the value.

=item head

Adds "%" at the end of the string and applies C<trim>.

=item tail

Adds "%" at the end of the string and applies C<trim>.

=item substr

Adds "% .. %" around the search string and applies C<trim>.

=back

=head2 METHODS (leading with ::)

=over 4

=item lt

=item gt

=item ilike

=item like

All these are recognized like the L<Rose::DB::Object> methods.

=item lazy_bool_eq

If the value is undefined or an empty string then this parameter will
be completely removed from the query. Otherwise a falsish filter value
will match for C<NULL> and C<FALSE>; trueish values will only match
C<TRUE>.

=item eq_ignore_empty

Ignores this item if it's empty. Otherwise compares it with the
standard SQL C<=> operator.

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

This will search for orders whose invoice has the _same_ customer, which matches
both inputs. This is because tables are aliased by their name and not by their
position in with_objects.

=head1 TODO

=over 4

=item *

Additional filters should be pluggable.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
