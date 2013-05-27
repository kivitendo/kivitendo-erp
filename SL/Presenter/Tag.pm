package SL::Presenter::Tag;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(html_tag input_tag man_days_tag name_to_id select_tag stringify_attributes);

use Carp;

my %_valueless_attributes = map { $_ => 1 } qw(
  checked compact declare defer disabled ismap multiple noresize noshade nowrap
  readonly selected
);

sub _call_on {
  my ($object, $method, @params) = @_;
  return $object->$method(@params);
}

{ # This will give you an id for identifying html tags and such.
  # It's guaranteed to be unique unless you exceed 10 mio calls per request.
  # Do not use these id's to store information across requests.
my $_id_sequence = int rand 1e7;
sub _id {
  return ( $_id_sequence = ($_id_sequence + 1) % 1e7 );
}
}


sub stringify_attributes {
  my ($self, %params) = @_;

  my @result = ();
  while (my ($name, $value) = each %params) {
    next unless $name;
    next if $_valueless_attributes{$name} && !$value;
    $value = '' if !defined($value);
    push @result, $_valueless_attributes{$name} ? $self->escape($name) : $self->escape($name) . '="' . $self->escape($value) . '"';
  }

  return @result ? ' ' . join(' ', @result) : '';
}

sub html_tag {
  my ($self, $tag, $content, %params) = @_;
  my $attributes = $self->stringify_attributes(%params);

  return "<${tag}${attributes}>" unless defined($content);
  return "<${tag}${attributes}>${content}</${tag}>";
}

sub input_tag {
  my ($self, $name, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $name);
  $attributes{type} ||= 'text';

  return $self->html_tag('input', undef, %attributes, name => $name, value => $value);
}

sub man_days_tag {
  my ($self, $name, $object, %attributes) = @_;

  my $size           =  delete($attributes{size})   || 5;
  my $method         =  $name;
  $method            =~ s/^.*\.//;

  my $time_selection =  $self->input_tag( "${name}_as_man_days_string", _call_on($object, "${method}_as_man_days_string"), %attributes, size => $size);
  my $unit_selection =  $self->select_tag("${name}_as_man_days_unit",   [[ 'h', $::locale->text('h') ], [ 'man_day', $::locale->text('MD') ]],
                                          %attributes, default => _call_on($object, "${method}_as_man_days_unit"));

  return $time_selection . $unit_selection;
}

sub name_to_id {
  my ($self, $name) = @_;

  $name =~ s/\[\+?\]/ _id() /ge; # give constructs with [] or [+] unique ids
  $name =~ s/[^\w_]/_/g;
  $name =~ s/_+/_/g;

  return $name;
}

sub select_tag {
  my ($self, $name, $collection, %attributes) = @_;

  _set_id_attribute(\%attributes, $name);

  my $value_key       = delete($attributes{value_key})   || 'id';
  my $title_key       = delete($attributes{title_key})   || $value_key;
  my $default_key     = delete($attributes{default_key}) || 'selected';


  my $value_title_sub = delete($attributes{value_title_sub});

  my $value_sub       = delete($attributes{value_sub});
  my $title_sub       = delete($attributes{title_sub});
  my $default_sub     = delete($attributes{default_sub});

  my $with_empty      = delete($attributes{with_empty});
  my $empty_title     = delete($attributes{empty_title});

  my $with_optgroups  = delete($attributes{with_optgroups});

  my %selected;

  if ( ref($attributes{default}) eq 'ARRAY' ) {

    foreach my $entry (@{$attributes{default}}) {
      $selected{$entry} = 1;
    }
  } elsif ( defined($attributes{default}) ) {
    $selected{$attributes{default}} = 1;
  }

  delete($attributes{default});

  my $normalize_entry = sub {
    my ($type, $entry, $sub, $key) = @_;

    return $sub->($entry) if $sub;

    my $ref = ref($entry);

    if ( !$ref ) {
      return $entry if $type eq 'value' || $type eq 'title';
      return 0;
    }

    if ( $ref eq 'ARRAY' ) {
      return $entry->[ $type eq 'value' ? 0 : $type eq 'title' ? 1 : 2 ];
    }

    return $entry->{$key} if $ref  eq 'HASH';
    return $entry->$key   if $type ne 'default' || $entry->can($key);
    return undef;
  };

  my $list_to_code = sub {
    my ($sub_collection) = @_;

    my @options;
    foreach my $entry ( @{ $sub_collection } ) {
      my $value;
      my $title;

      if ( $value_title_sub ) {
        ($value, $title) = @{ $value_title_sub->($entry) };
      } else {

        $value = $normalize_entry->('value', $entry, $value_sub, $value_key);
        $title = $normalize_entry->('title', $entry, $title_sub, $title_key);
      }

      my $default = $normalize_entry->('default', $entry, $default_sub, $default_key);

      push(@options, [$value, $title, $default]);
    }

    foreach my $entry (@options) {
      $entry->[2] = 1 if $selected{$entry->[0]};
    }

    return join '', map { $self->html_tag('option', $self->escape($_->[1]), value => $_->[0], selected => $_->[2]) } @options;
  };

  my $code  = '';
  $code    .= $self->html_tag('option', $self->escape($empty_title || ''), value => '') if $with_empty;

  if (!$with_optgroups) {
    $code .= $list_to_code->($collection);

  } else {
    $code .= join '', map {
      my ($optgroup_title, $sub_collection) = @{ $_ };
      $self->html_tag('optgroup', $list_to_code->($sub_collection), label => $optgroup_title)
    } @{ $collection };
  }

  return $self->html_tag('select', $code, %attributes, name => $name);
}

sub _set_id_attribute {
  my ($attributes, $name) = @_;

  $attributes->{id} = name_to_id(undef, $name) if !delete($attributes->{no_id}) && !$attributes->{id};

  return %{ $attributes };
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Tag - Layouting / tag generation

=head1 SYNOPSIS

Usage from a template:

  [% USE P %]

  [% P.select_tag('direction', [ [ 'left', 'To the left' ], [ 'right', 'To the right', 1 ] ]) %]

  [% P.select_tag('direction', [ { direction => 'left',  display => 'To the left'  },
                                 { direction => 'right', display => 'To the right' } ],
                               value_key => 'direction', title_key => 'display', default => 'right')) %]

  [% P.select_tag('direction', [ { direction => 'left',  display => 'To the left'  },
                                 { direction => 'right', display => 'To the right', selected => 1 } ],
                               value_key => 'direction', title_key => 'display')) %]

=head1 DESCRIPTION

A module modeled a bit after Rails' ActionView helpers. Several small
functions that create HTML tags from various kinds of data sources.

The C<id> attribute is usually calculated automatically. This can be
overridden by either specifying an C<id> attribute or by setting
C<no_id> to trueish.

=head1 FUNCTIONS

=head2 LOW-LEVEL FUNCTIONS

=over 4

=item C<html_tag $tag_name, $content_string, %attributes>

Creates an opening and closing HTML tag for C<$tag_name> and puts
C<$content_string> between the two. If C<$content_string> is undefined
or empty then only a E<lt>tag/E<gt> tag will be created. Attributes
are key/value pairs added to the opening tag.

C<$content_string> is not HTML escaped.

=item C<name_to_id $name>

Converts a name to a HTML id by replacing various characters.

=item C<stringify_attributes %items>

Creates a string from all elements in C<%items> suitable for usage as
HTML tag attributes. Keys and values are HTML escaped even though keys
must not contain non-ASCII characters for browsers to accept them.

=back

=head2 HIGH-LEVEL FUNCTIONS

=over 4

=item C<input_tag $name, $value, %attributes>

Creates a HTML 'input type=text' tag named C<$name> with the value
C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

=item C<man_days_tag $name, $object, %attributes>

Creates two HTML inputs: a text input for entering a number and a drop
down box for chosing the unit (either 'man days' or 'hours').

C<$object> must be a L<Rose::DB::Object> instance using the
L<SL::DB::Helper::AttrDuration> helper.

C<$name> is supposed to be the name of the underlying column,
e.g. C<time_estimation> for an instance of
C<SL::DB::RequirementSpecItem>. If C<$name> has the form
C<prefix.method> then the full C<$name> is used for the input's base
names while the methods called on C<$object> are only the suffix. This
makes it possible to write statements like e.g.

  [% P.man_days_tag("requirement_spec_item.time_estimation", SELF.item) %]

The attribute C<size> can be used to set the text input's size. It
defaults to 5.

=item C<select_tag $name, \@collection, %attributes>

Creates a HTML 'select' tag named C<$name> with the contents of one
'E<lt>optionE<gt>' tag for each element in C<\@collection> and with arbitrary
HTML attributes from C<%attributes>. The value
to use and the title to display are extracted from the elements in
C<\@collection>. Each element can be one of four things:

=over 12

=item 1. An array reference with at least two elements. The first element is
the value, the second element is its title. The third element is optional and and should contain a boolean.
If it is true, than the element will be used as default.

=item 2. A scalar. The scalar is both the value and the title.

=item 3. A hash reference. In this case C<%attributes> must contain
I<value_key>, I<title_key> and may contain I<default_key> keys that name the keys in the element to use
for the value, title and default respectively.

=item 4. A blessed reference. In this case C<%attributes> must contain
I<value_key>, I<title_key> and may contain I<default_key> keys that name functions called on the blessed
reference whose return values are used as the value, title and default
respectively.

=back

For cases 3 and 4 C<$attributes{value_key}> defaults to C<id>,
C<$attributes{title_key}> defaults to C<$attributes{value_key}>
and C<$attributes{default_key}> defaults to C<selected>.

In addition to pure keys/method you can also provide coderefs as I<value_sub>
and/or I<title_sub> and/or I<default_sub>. If present, these take precedence over keys or methods,
and are called with the element as first argument. It must return the value, title or default.

Lastly a joint coderef I<value_title_sub> may be provided, which in turn takes
precedence over the C<value_sub> and C<title_sub> subs. It will only be called once for each
element and must return a list of value and title.

If the option C<with_empty> is set then an empty element (value
C<undef>) will be used as the first element. The title to display for
this element can be set with the option C<empty_title> and defaults to
an empty string.

The option C<default> can be either a scalar or an array reference
containing the values of the options which should be set to be
selected.

The tag's C<id> defaults to C<name_to_id($name)>.

If the option C<with_optgroups> is set then this function expects
C<\@collection> to be one level deeper. The upper-most level is
translated into a HTML C<optgroup> tag. So the structure becomes:

=over 4

=item 1. Array of array references. Each element in the
C<\@collection> is converted into an optgroup.

=item 2. The optgroup's C<label> attribute will be set to the the
first element in the array element. The second array element is then
converted to a list of C<option> tags like it is described above.

=back

Example for use of optgroups:

  # First in a controller:
  my @collection = (
    [ t8("First optgroup with two items"),
      [ { id => 42, name => "item one" },
        { id => 54, name => "second item" },
        { id => 23, name => "and the third one" },
      ] ],
    [ t8("Another optgroup, with a lot of items from Rose"),
      SL::DB::Manager::Customer->get_all_sorted ],
  );

  # Later in the template:
  [% L.select_tag('the_selection', COLLECTION, with_optgroups=1, title_key='name') %]

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>,
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
