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

  $prefs->store_use_duration(1);
  my $value = $prefs->get_longdescription_dialog_size_percentage;

=head1 DESCRIPTION

This module manages storing the user's choise for settings for
various display settings.
For now the preferred procentual size of the edit-dialog for longdescriptions
of positions can be stored.

=head1 BUGS

None yet :)

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
