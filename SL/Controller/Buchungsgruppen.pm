package SL::Controller::Buchungsgruppen;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::TaxZone;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::TaxzoneChart;
use SL::Controller::ClientConfig;
use SL::DB::Default;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(config) ],
  'scalar --get_set_init' => [ qw(defaults) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_config', only => [ qw(edit update delete) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  my $buchungsgruppen = SL::DB::Manager::Buchungsgruppe->get_all_sorted();
  my $taxzones        = SL::DB::Manager::TaxZone->get_all_sorted(query => [ obsolete => 0 ]);

  my %chartlist = ();
  foreach my $gruppe (@{ $buchungsgruppen }) {
      $chartlist{ $gruppe->id } = SL::DB::TaxzoneChart->get_all_accounts_by_buchungsgruppen_id($gruppe->id);
  }

  $::form->header;
  $self->render('buchungsgruppen/list',
                title           => t8('Buchungsgruppen'),
                BUCHUNGSGRUPPEN => $buchungsgruppen,
                CHARTLIST       => \%chartlist,
                TAXZONES        => $taxzones);
}

sub action_new {
  my ($self) = @_;

  $self->config(SL::DB::Buchungsgruppe->new());
  $self->show_form(title => t8('Add Buchungsgruppe'));
}

sub show_form {
  my ($self, %params) = @_;

  $self->render('buchungsgruppen/form', %params,
                 TAXZONES       => SL::DB::Manager::TaxZone->get_all_sorted(),
                 ACCOUNTS       => SL::Controller::ClientConfig->init_accounts(),
                 account_label  => sub { "$_[0]{accno}--$_[0]{description}" });
}

sub action_edit {
  my ($self) = @_;

  # Allow editing of the charts of the Buchungsgruppe if it isn't assigned to
  # any parts. This is checked inside the template via the Buchungsgruppen
  # orphaned method, where an IF-ELSE statement toggles between L.select_tag
  # and text.

  $self->show_form(title     => t8('Edit Buchungsgruppe'),
                   CHARTLIST => SL::DB::TaxzoneChart->get_all_accounts_by_buchungsgruppen_id($self->config->id));
}

sub action_create {
  my ($self) = @_;

  $self->config(SL::DB::Buchungsgruppe->new());
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_delete {
  my ($self) = @_;

  # allow deletion of unused Buchungsgruppen. Will fail, due to database
  # constraint, if Buchungsgruppe is connected to a part

  my $db = $self->{config}->db;
  $db->do_transaction(sub {
        my $taxzone_charts = SL::DB::Manager::TaxzoneChart->get_all(where => [ buchungsgruppen_id => $self->config->id ]);
        foreach my $taxzonechart ( @{$taxzone_charts} ) { $taxzonechart->delete };
        $self->config->delete();
        flash_later('info',  $::locale->text('The buchungsgruppe has been deleted.'));
  }) || flash_later('error', $::locale->text('The buchungsgruppe is in use and cannot be deleted.'));

  $self->redirect_to(action => 'list');

}

sub action_reorder {
  my ($self) = @_;

  SL::DB::Buchungsgruppe->reorder_list(@{ $::form->{bg_id} || [] });

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

  $self->config(SL::DB::Buchungsgruppe->new(id => $::form->{id})->load);
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

  # Save or update taxzone_charts for new or unused Buchungsgruppen
  if ($is_new or $self->config->orphaned) {
    my $taxzones = SL::DB::Manager::TaxZone->get_all_sorted();

    foreach my $tz (@{ $taxzones }) {
      my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by_or_create(buchungsgruppen_id => $self->config->id, taxzone_id => $tz->id);
      $taxzone_chart->taxzone_id($tz->id);
      $taxzone_chart->buchungsgruppen_id($self->config->id);
      $taxzone_chart->income_accno_id($::form->{"income_accno_id_" . $tz->id});
      $taxzone_chart->expense_accno_id($::form->{"expense_accno_id_" . $tz->id});
      $taxzone_chart->save;
    }
  }

  flash_later('info', $is_new ? t8('The Buchungsgruppe has been created.') : t8('The Buchungsgruppe has been saved.'));
  $self->redirect_to(action => 'list');
}

#
# initializers
#

sub init_defaults        { SL::DB::Default->get }

1;
