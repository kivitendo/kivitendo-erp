package SL::Controller::GoBD;

use strict;

use parent qw(SL::Controller::Base);

use DateTime;
use SL::GoBD;
use SL::Locale::String qw(t8);
use SL::Helper::Flash;

use SL::DB::AccTransaction;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(from to) ],
);

__PACKAGE__->run_before('check_auth');

sub action_filter {
  my ($self) = @_;

  $self->from(DateTime->today->add(years => -1)->add(days => 1)) if !$self->from;
  $self->to(DateTime->today)                                     if !$self->to;

  $::request->layout->add_javascripts('kivi.GoBD.js');
  $self->setup_filter_action_bar;
  $self->render('gobd/filter', current_year => DateTime->today->year, title => t8('GoBD Export'));
}

sub action_export {
  my ($self) = @_;

  if (!$self->check_inputs) {
    $self->action_filter;
    return;
  }

  my $filename;
  my $gobd = SL::GoBD->new(
    company    => $::instance_conf->get_company,
    location   => $::instance_conf->get_address,
    from       => $self->from,
    to         => $self->to,
  );

  eval {
    $filename = $gobd->generate_export;
  } or do {
    my $errors = $@;
    flash('error', t8('The export failed because of malformed transactions. Please fix those before exporting.'));
    flash('error', $_) for @$errors;

    $self->action_filter;
    return;
  };

  $self->send_file($filename, name => t8('gobd-#1-#2.zip', $self->from->ymd, $self->to->ymd), unlink => 1);
}

#--- other stuff

sub check_auth { $::auth->assert('report') }

sub check_inputs {
  my ($self) = @_;

  my $error = 0;

  if ($::form->{method} eq 'year') {
    if ($::form->{year}) {
      $self->from(DateTime->new(year => $::form->{year}, month => 1,  day => 1));
      $self->to(  DateTime->new(year => $::form->{year}, month => 12, day => 31));
    } else {
      $error = 1;
      flash('error', t8('No year given for method year'));
    }
  } else {
    if (!$::form->{from}) {
      my $epoch = DateTime->new(day => 1, month => 1, year => 1900);
      flash('info', t8('No start date given, setting to #1', $epoch->to_kivitendo));
      $self->from($epoch);
    }

    if (!$::form->{to}) {
      flash('info', t8('No end date given, setting to today'));
      $self->to(DateTime->today);
    }
  }

  !$error;
}

sub available_years {
  my ($self) = @_;

  my $first_trans = SL::DB::Manager::AccTransaction->get_first(sort_by => 'transdate', limit => 1);

  return [] unless $first_trans;
  return [ reverse $first_trans->transdate->year .. DateTime->today->year ];
}

sub init_from { DateTime->from_kivitendo($::form->{from}) }
sub init_to { DateTime->from_kivitendo($::form->{to}) }

sub setup_filter_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Export'),
        submit    => [ '#filter_form', { action => 'GoBD/export' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
