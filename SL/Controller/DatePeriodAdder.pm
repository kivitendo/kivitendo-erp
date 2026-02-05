package SL::Controller::DatePeriodAdder;

use strict;

use parent qw(SL::Controller::Base);

use SL::Presenter::DatePeriod qw(date_period_picker);
use SL::JSON;
use Carp;

# Minimal controller to return a new DatePeriod presenter via AJAX.

sub action_ajax_get {
  my ($self) = @_;

  my $name = $::form->{name} // croak('Need name parameter');

  # Render the date period picker.
  my $html = date_period_picker($name);

  $self->render(\ SL::JSON::to_json({ html => $html }), { type => 'json', process => 0 });
}

1;

__END__

=pod

=head1 NAME

SL::Controller::DatePeriodAdder - AJAX provider for date period adders

=head1 DESCRIPTION

Provides an action to request a new date period picker HTML fragment via AJAX.

=cut
