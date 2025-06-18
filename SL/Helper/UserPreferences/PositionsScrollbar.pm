package SL::Helper::UserPreferences::PositionsScrollbar;

use strict;
use parent qw(Rose::Object);

use Carp;
use List::MoreUtils qw(none);

use SL::Helper::UserPreferences;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(user_prefs) ],
);

sub get_height {
  my $value = $_[0]->user_prefs->get('height');
  return !defined($value) ? 0 : $value;
}

sub store_height {
  $_[0]->user_prefs->store('height', $_[1]);
}

sub init_user_prefs {
  SL::Helper::UserPreferences->new(
    namespace => $_[0]->namespace,
  )
}

# read only stuff
sub namespace     { 'PositionsScrollbar' }
sub version       { 1 }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Helper::UserPreferences::PositionsScrollbar - preferences intended
to store user settings for displaying a scrollbar for the postions area
of document forms (it's height).

=head1 SYNOPSIS

  use SL::Helper::UserPreferences::PositionsScrollbar;
  my $prefs = SL::Helper::UserPreferences::PositionsScrollbar->new();

  $prefs->store_height(75);
  my $value = $prefs->get_height;

=head1 DESCRIPTION

This module manages storing the height for displaying the scrollbar in the
positions area in forms (new order controller).

=head1 BUGS

None yet :)

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
