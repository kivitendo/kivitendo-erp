package SL::Presenter::MaterialComponents;

use strict;

use SL::HTML::Restrict;
use SL::Presenter::EscapedText qw(escape);
use SL::Presenter::Tag qw(html_tag);
use Scalar::Util qw(blessed);

use Exporter qw(import);
our @EXPORT_OK = qw(
  button_tag
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

  # todo icons
  # todo label/active
  # todo validate

  html_tag('input', $name, $value, %attributes) . html_tag('label', for => $attributes{id}, $name);
}


1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::MaterialComponents - MaterialCSS Component wrapper

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@googlemail.comE<gt>

=cut
