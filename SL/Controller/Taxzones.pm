package SL::Controller::Taxzones;

use strict;

use parent qw(SL::Controller::Base);

#use List::Util qw(first);

use SL::DB::TaxZone;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Manager::Buchungsgruppe;
use SL::DB::Manager::TaxzoneChart;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(config) ],
  'scalar --get_set_init' => [ qw(defaults) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_config', only => [ qw(edit update) ]); #destroy

#
# actions
#

sub action_list {
  my ($self) = @_;

  my $taxzones = SL::DB::Manager::TaxZone->get_all_sorted();

  $::form->header;
  $self->render('taxzones/list',
                title    => t8('List of tax zones'),
                TAXZONES => $taxzones);
}

sub action_new {
  my ($self) = @_;

  $self->config(SL::DB::TaxZone->new());
  $self->show_form(title => t8('Add taxzone'));
}

sub show_form {
  my ($self, %params) = @_;

  $self->render('taxzones/form', %params,
                BUCHUNGSGRUPPEN => SL::DB::Manager::Buchungsgruppe->get_all_sorted);
}

sub action_edit {
  my ($self) = @_;

  $self->show_form(title     => t8('Edit taxzone'),
                   CHARTLIST => SL::DB::TaxzoneChart->get_all_accounts_by_taxzone_id($self->config->id));
}

sub action_create {
  my ($self) = @_;

  $self->config(SL::DB::TaxZone->new());
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;

  $self->create_or_update;
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::TaxZone->reorder_list(@{ $::form->{tzone_id} || [] });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

sub load_config {
  my ($self) = @_;

  $self->config(SL::DB::TaxZone->new(id => $::form->{id})->load);
}

#
# helpers
#

sub create_or_update {
  my ($self) = @_;
  my $is_new = !$self->config->id;

  my $params = delete($::form->{config}) || { };
  delete $params->{id};

  $self->config->assign_attributes(%{ $params });

  my @errors = $self->config->validate;

  if (@errors) {
    flash('error', @errors);
    $self->show_form(title => $is_new ? t8('Add taxzone') : t8('Edit taxzone'));
    return;
  }

  $self->config->save;
  $self->config->obsolete($::form->{"obsolete"});

  #Save taxzone_charts for new taxzones:
  if ($is_new) {
    my $buchungsgruppen = SL::DB::Manager::Buchungsgruppe->get_all_sorted();

    foreach my $bg (@{ $buchungsgruppen }) {
      my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by_or_create(buchungsgruppen_id => $bg->id, taxzone_id => $self->config->id);

      $taxzone_chart->taxzone_id($self->config->id);
      $taxzone_chart->buchungsgruppen_id($bg->id);
      $taxzone_chart->income_accno_id($::form->{"income_accno_id_" . $bg->id});
      $taxzone_chart->expense_accno_id($::form->{"expense_accno_id_" . $bg->id});
      $taxzone_chart->save;
    }
  }

  flash_later('info', $is_new ? t8('The taxzone has been created.') : t8('The taxzone has been saved.'));
  $self->redirect_to(action => 'list');
}

#
# initializers
#

sub init_defaults { SL::DB::Default->get };

1;
