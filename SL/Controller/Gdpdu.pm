package SL::Controller::Gdpdu;

# TODO:
#  - depending exclusive checkboses via javascript

use strict;

use parent qw(SL::Controller::Base);

use SL::GDPDU;
use SL::Locale::String qw(t8);
use SL::Helper::Flash;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(from to) ],
);

__PACKAGE__->run_before('check_auth');

sub action_filter {
  my ($self) = @_;

  $self->from(DateTime->today->add(years => -1)->add(days => 1)) if !$self->from;
  $self->to(DateTime->today)                                     if !$self->to;

  $self->render('gdpdu/filter', title => t8('GDPDU Export'));
}

sub action_export {
  my ($self) = @_;

  if (!$self->check_inputs) {
    $self->action_filter;
    return;
  }

  my $gdpdu = SL::GDPDU->new(
    company    => $::instance_conf->get_company,
    location   => $::instance_conf->get_address,
    from       => $self->from,
    to         => $self->to,
    all_tables => $::form->{all_tables},
  );

  my $filename = $gdpdu->generate_export;

  $self->send_file($filename, name => t8('gdpdu-#1-#2.zip', $self->from->ymd, $self->to->ymd), unlink => 1);
}

#--- other stuff

sub check_auth { $::auth->assert('report') }

sub check_inputs {
  my ($self) = @_;

  my $error = 0;

  if (!$::form->{from}) {
    my $epoch = DateTime->new(day => 1, month => 1, year => 1900);
    flash('info', t8('No start date given, setting to #1', $epoch->to_kivitendo));
    $self->from($epoch);
  }

  if (!$::form->{to}) {
    flash('info', t8('No end date given, setting to today'));
    $self->to(DateTime->today);
  }

  !$error;
}

sub init_from { DateTime->from_kivitendo($::form->{from}) }
sub init_to { DateTime->from_kivitendo($::form->{to}) }

1;
