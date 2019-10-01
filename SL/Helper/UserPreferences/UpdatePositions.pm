package SL::Helper::UserPreferences::UpdatePositions;

use strict;
use parent qw(Rose::Object);

use Carp;
use List::MoreUtils qw(none);

use SL::Helper::UserPreferences;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(user_prefs) ],
);

sub get_show_update_button {
  !!$_[0]->user_prefs->get('show_update_button');
}

sub store_show_update_button {
  $_[0]->user_prefs->store('show_update_button', $_[1]);
}

sub init_user_prefs {
  SL::Helper::UserPreferences->new(
    namespace => $_[0]->namespace,
  )
}

# read only stuff
sub namespace     { 'UpdatePositions' }
sub version       { 1 }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Helper::UserPreferences::UpdatePositions - preferences intended
to store user settings for displaying an update button for the postions
of document forms to update the positions (parts) from master data.

=head1 SYNOPSIS

  use SL::Helper::UserPreferences::UpdatePositions;
  my $prefs = SL::Helper::UserPreferences::UpdatePositions->new();

  $prefs->store_show_update_button(1);
  my $value = $prefs->get_show_update_button;

=head1 DESCRIPTION

This module manages storing the user's choise for displaying an update button
in the positions area in forms (new order controller).

=head1 BUGS

None yet :)

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
