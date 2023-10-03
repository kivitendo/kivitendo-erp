package SL::Presenter::MaterialComponents;

use strict;

use SL::HTML::Restrict;
use SL::MoreCommon qw(listify);
use SL::Presenter::EscapedText qw(escape);
use SL::Presenter::Tag qw(html_tag);
use Scalar::Util qw(blessed);
use List::UtilsBy qw(partition_by);

use Exporter qw(import);
our @EXPORT_OK = qw(
  button_tag
  input_tag
  textarea_tag
  date_tag
  submit_tag
  icon
  select_tag
  checkbox_tag
);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use constant BUTTON          => 'btn';
use constant BUTTON_FLAT     => 'btn-flat';
use constant BUTTON_FLOATING => 'btn-floating';
use constant BUTTON_LARGE    => 'btn-large';
use constant BUTTON_SMALL    => 'btn-small';
use constant DISABLED        => 'disabled';
use constant LEFT            => 'left';
use constant MATERIAL_ICONS  => 'material-icons';
use constant RIGHT           => 'right';
use constant LARGE           => 'large';
use constant MEDIUM          => 'medium';
use constant SMALL           => 'small';
use constant TINY            => 'tiny';
use constant INPUT_FIELD     => 'input-field';
use constant DATEPICKER      => 'datepicker';

use constant WAVES_EFFECT    => 'waves-effect';
use constant WAVES_LIGHT     => 'waves-light';


my %optional_classes = (
  button => {
    disabled => DISABLED,
    flat     => BUTTON_FLAT,
    floating => BUTTON_FLOATING,
    large    => BUTTON_LARGE,
    small    => BUTTON_SMALL,
  },
  icon => {
    left   => LEFT,
    right  => RIGHT,
    large  => LARGE,
    medium => MEDIUM,
    small  => SMALL,
    tiny   => TINY,
  },
  size => {
    map { $_ => $_ }
      qw(col row),
      (map { "s$_" } 1..12),
      (map { "m$_" } 1..12),
      (map { "l$_" } 1..12),
  },
);

use Carp;

sub _confirm_js {
  'if (!confirm("'. _J($_[0]) .'")) return false;'
}

sub _confirm_to_onclick {
  my ($attributes, $onclick) = @_;

  if ($attributes->{confirm}) {
    $$onclick //= '';
    $$onclick = _confirm_js(delete($attributes->{confirm})) . $attributes->{onlick};
  }
}

# used to extract material properties that need to be translated to classes
# supports prefixing for delegation
# returns a list of classes, mutates the attributes
sub _extract_attribute_classes {
  my ($attributes, $type, $prefix) = @_;

  my @classes;
  my $attr;
  for my $key (keys %$attributes) {
    if ($prefix) {
      next unless $key =~ /^${prefix}_(.*)/;
      $attr = $1;
    } else {
      $attr = $key;
    }

    if ($optional_classes{$type}{$attr}) {
      $attributes->{$key} = undef;
      push @classes, $optional_classes{$type}{$attr};
    }
  }

  # delete all undefined values
  my @delete_keys = grep { !defined $attributes->{$_} } keys %$attributes;
  delete $attributes->{$_} for @delete_keys;

  @classes;
}

# used to extract material classes that are passed directly as classes
sub _extract_classes {
  my ($attributes, $type) = @_;

  my @classes = map { split / / } listify($attributes->{class});
  my %classes = partition_by { !!$optional_classes{$type}{$_} } @classes;

  $attributes->{class} = $classes{''};
  $classes{1};
}

sub _set_id_attribute {
  my ($attributes, $name, $unique) = @_;

  if (!delete($attributes->{no_id}) && !$attributes->{id}) {
    $attributes->{id}  = name_to_id($name);
    $attributes->{id} .= '_' . $attributes->{value} if $unique;
  }

  %{ $attributes };
}

{ # This will give you an id for identifying html tags and such.
  # It's guaranteed to be unique unless you exceed 10 mio calls per request.
  # Do not use these id's to store information across requests.
my $_id_sequence = int rand 1e7;
sub _id {
  return ( $_id_sequence = ($_id_sequence + 1) % 1e7 );
}
}

sub name_to_id {
  my ($name) = @_;

  if (!$name) {
    return "id_" . _id();
  }

  $name =~ s/\[\+?\]/ _id() /ge; # give constructs with [] or [+] unique ids
  $name =~ s/[^\w_]/_/g;
  $name =~ s/_+/_/g;

  return $name;
}

sub button_tag {
  my ($onclick, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $attributes{name}) if $attributes{name};
  _confirm_to_onclick(\%attributes, \$onclick);

  my @button_classes = _extract_attribute_classes(\%attributes, "button");
  my @icon_classes   = _extract_attribute_classes(\%attributes, "icon", "icon");

  $attributes{class} = [
    grep { $_ } $attributes{class}, WAVES_EFFECT, WAVES_LIGHT, BUTTON, @button_classes
  ];

  if ($attributes{icon}) {
    $value = icon(delete $attributes{icon}, class => \@icon_classes)
           . $value;
  }

  html_tag('a', $value, %attributes, onclick => $onclick);
}

sub submit_tag {
  my ($name, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $attributes{name}) if $attributes{name};
  _confirm_to_onclick(\%attributes, \($attributes{onclick} //= ''));

  my @button_classes = _extract_attribute_classes(\%attributes, "button");
  my @icon_classes   = _extract_attribute_classes(\%attributes, "icon", "icon");

  $attributes{class} = [
    grep { $_ } $attributes{class}, WAVES_EFFECT, WAVES_LIGHT, BUTTON, @button_classes
  ];

  if ($attributes{icon}) {
    $value = icon(delete $attributes{icon}, class => \@icon_classes)
           . $value;
  }

  html_tag('button', $value, type => 'submit',  %attributes);
}


sub icon {
  my ($name, %attributes) = @_;

  my @icon_classes = _extract_attribute_classes(\%attributes, "icon");

  html_tag('i', $name, class => [ grep { $_ } MATERIAL_ICONS, @icon_classes, delete $attributes{class} ], %attributes);
}


sub input_tag {
  my ($name, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $attributes{name});

  my $class = delete $attributes{class};
  my $icon  = $attributes{icon}
    ? icon(delete $attributes{icon}, class => 'prefix')
    : '';

  my $label = $attributes{label}
    ? html_tag('label', delete $attributes{label}, for => $attributes{id})
    : '';

  $attributes{type} //= 'text';

  html_tag('div',
    $icon .
    html_tag('input', undef, value => $value, %attributes, name => $name) .
    $label,
    class => [ grep $_, $class, INPUT_FIELD ],
  );
}

sub textarea_tag {
  my ($name, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $attributes{name});

  my $class = delete $attributes{class};
  my $icon  = $attributes{icon}
    ? icon(delete $attributes{icon}, class => 'prefix')
    : '';

  my $label = $attributes{label}
    ? html_tag('label', delete $attributes{label}, for => $attributes{id})
    : '';

  html_tag('div',
    $icon .
    html_tag('textarea', $value, class => 'materialize-textarea', %attributes, name => $name) .
    $label,
    class => [ grep $_, $class, INPUT_FIELD ],
  );
}

sub date_tag {
  my ($name, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $name);

  my $icon  = $attributes{icon}
    ? icon(delete $attributes{icon}, class => 'prefix')
    : '';

  my $label = $attributes{label}
    ? html_tag('label', delete $attributes{label}, for => $attributes{id})
    : '';

  $attributes{type} = 'text'; # required for materialize

  my @onchange = $attributes{onchange} ? (onChange => delete $attributes{onchange}) : ();
  my @classes  = (delete $attributes{class});

  $::request->layout->add_javascripts('kivi.Validator.js');
  $::request->presenter->need_reinit_widgets($attributes{id});

  $attributes{'data-validate'} = join(' ', "date", grep { $_ } (delete $attributes{'data-validate'}));

  html_tag('div',
    $icon .
    html_tag('input',
      blessed($value) ? $value->to_lxoffice : $value,
      size   => 11, type => 'text', name => $name,
      %attributes,
      class => DATEPICKER, @onchange,
    ) .
    $label,
    class => [ grep $_, @classes, INPUT_FIELD ],
  );
}

sub select_tag {
  my ($name, $collection, %attributes) = @_;


  _set_id_attribute(\%attributes, $name);
  my @size_classes   = _extract_classes(\%attributes, "size");


  my $icon  = $attributes{icon}
    ? icon(delete $attributes{icon}, class => 'prefix')
    : '';

  my $label = $attributes{label}
    ? html_tag('label', delete $attributes{label}, for => $attributes{id}, class => 'active')
    : '';

  my $select_html = SL::Presenter::Tag::select_tag($name, $collection, %attributes,
    class => 'browser-default');

  html_tag('div',
    $icon . $select_html . $label,
    class => [ INPUT_FIELD, @size_classes ],
  );
}

sub checkbox_tag {
  my ($name, %attributes) = @_;

  _set_id_attribute(\%attributes, $name);

  my $label = $attributes{label}
    ? html_tag('span', delete $attributes{label})
    : '';

  my $checkbox_html = SL::Presenter::Tag::checkbox_tag($name, %attributes);

  html_tag('label',
    $checkbox_html . $label,
  );
}


1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::MaterialComponents - MaterialCSS Component wrapper

=head1 SYNOPSIS


=head1 DESCRIPTION

This is a collection of components in the style of L<SL::Presenter::Tag>
intended for materialzecss. They should be useable similarly to their original
versions but be well-behaved for materialize.

They will also recognize some materialize conventions:

=over 4

=item icon>

Most elements can be decorated with an icon by supplying the C<icon> with the name.

=item grid classes

Grid classes like C<s12> or C<m6> can be given as keys with any truish value or
directly as classes.

=back

=head1 BUGS & ISSUES

There is a bug in MaterializeCSS, when using a Materialize select element on an iphone,
the wrong element is selected. This is currently worked around in the presenter by using
the 'browser-default' class on the select element as well as the 'active' class on the
label (to prevent the label from overlapping the select element).
This should be fixed, upstream, in MaterializeCSS. However it seems that the project is
not maintained anymore (according to github issues[^1]). There is a community fork[^2],
which it's still maintained and where the problem seems to be fixed already. It is currently
in alpha V. 2.0.3-alpha. Maybe it would be good to consider switching to that fork at some
point.

[1]: e.g. https://github.com/Dogfalo/materialize/issues/6688
[2]: https://github.com/materializecss/materialize

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@googlemail.comE<gt>

=cut
