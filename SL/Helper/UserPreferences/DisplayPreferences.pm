package SL::Helper::UserPreferences::DisplayPreferences;

use strict;
use parent qw(Rose::Object);

use SL::Helper::UserPreferences;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(user_prefs) ],
);

sub get_longdescription_dialog_size_percentage {
  $_[0]->user_prefs->get('longdescription_dialog_size_percentage');
}

sub store_longdescription_dialog_size_percentage {
  $_[0]->user_prefs->store('longdescription_dialog_size_percentage', $_[1]);
}

sub get_layout_style {
  my $value   = $_[0]->user_prefs->get('layout_style');
  $value    //= $::instance_conf->get_layout_style;
  return $value;
}

sub store_layout_style {
  my ($self, $style) = @_;

  if (!$style) {
    $self->user_prefs->delete('layout_style');
    return;
  }

  if ( !($style eq 'desktop' || $style eq 'mobile' || $style eq 'auto') ) {
    die "unknown layout style '$style'";
  }

  $self->user_prefs->store('layout_style', $style);
}

sub init_user_prefs {
  SL::Helper::UserPreferences->new(
    namespace => $_[0]->namespace,
  )
}

# read only stuff
sub namespace     { 'DisplayPreferences' }
sub version       { 1 }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Helper::UserPreferences::DisplayPreferences - preferences intended
to store user settings for various display settings.

=head1 SYNOPSIS

  use SL::Helper::UserPreferences::DisplayPreferences;
  my $prefs = SL::Helper::UserPreferences::DisplayPreferences->new();

  $prefs->store_longdescription_dialog_size_percentage(25);
  my $value = $prefs->get_longdescription_dialog_size_percentage;

=head1 DESCRIPTION

This module manages storing the user's choise for settings for
various display settings.

=head2 These settings are supported:

=over 4

=item longdescription_dialog_size_percentage

The preferred procentual size of the edit-dialog for longdescriptions
of positions can be stored.

=item layout_style

Here the layout style can be forced to be 'desktop' or 'mobile'
regardless of the user agend string. If this user setting is unset
then the setting from the client configuration will be used.

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
