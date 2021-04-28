package SL::Helper::UserPreferences::TimeRecording;

use strict;
use parent qw(Rose::Object);

use Carp;
use List::MoreUtils qw(none);

use SL::Helper::UserPreferences;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(user_prefs) ],
);

sub get_use_duration {
  !!$_[0]->user_prefs->get('use_duration');
}

sub store_use_duration {
  $_[0]->user_prefs->store('use_duration', $_[1]);
}

sub init_user_prefs {
  SL::Helper::UserPreferences->new(
    namespace => $_[0]->namespace,
  )
}

# read only stuff
sub namespace     { 'TimeRecording' }
sub version       { 1 }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Helper::UserPreferences::TimeRecording - preferences intended
to store user settings for using the time recording functionality.

=head1 SYNOPSIS

  use SL::Helper::UserPreferences::TimeRecording;
  my $prefs = SL::Helper::UserPreferences::TimeRecording->new();

  $prefs->store_use_duration(1);
  my $value = $prefs->get_use_duration;

=head1 DESCRIPTION

This module manages storing the user's choise for settings for
the time recording controller.
For now it can be choosen if an entry is done by entering start and
end time or a date and a duration.

=head1 BUGS

None yet :)

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
