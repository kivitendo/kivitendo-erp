package SL::Controller::Taxzones;

use strict;

use parent qw(SL::Controller::Base);

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
__PACKAGE__->run_before('load_config', only => [ qw(edit update delete) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  my $taxzones = SL::DB::Manager::TaxZone->get_all_sorted();

  $self->setup_list_action_bar;
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

  $self->setup_show_form_action_bar;
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

sub action_delete {
  my ($self) = @_;

  # allow deletion of unused tax zones. Will fail, due to database
  # constraints, if tax zone is used anywhere

  $self->{config}->db->with_transaction(sub {
    my $taxzone_charts = SL::DB::Manager::TaxzoneChart->get_all(where => [ taxzone_id => $self->config->id ]);
    foreach my $taxzonechart ( @{$taxzone_charts} ) { $taxzonechart->delete };
    $self->config->delete();
    flash_later('info',  $::locale->text('The tax zone has been deleted.'));

    1;
  }) || flash_later('error', $::locale->text('The tax zone is in use and cannot be deleted.'));

  $self->redirect_to(action => 'list');

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

  my @errors;

  my $db = $self->config->db;
  if (!$db->with_transaction(sub {

    # always allow editing of description and obsolete
    $self->config->assign_attributes( %{$params} ) ;

    push(@errors, $self->config->validate); # check for description

    if (@errors) {
      die @errors . "\n";
    };

    $self->config->save;

    if ( $is_new or $self->config->orphaned ) {
      # Save taxzone_charts
      my $buchungsgruppen = SL::DB::Manager::Buchungsgruppe->get_all_sorted();

      foreach my $bg (@{ $buchungsgruppen }) {
        my $income_accno_id  = $::form->{"income_accno_id_"  . $bg->id};
        my $expense_accno_id = $::form->{"expense_accno_id_" . $bg->id};

        my ($income_accno, $expense_accno);
        $income_accno  = SL::DB::Manager::Chart->find_by( id => $income_accno_id )  if $income_accno_id;
        $expense_accno = SL::DB::Manager::Chart->find_by( id => $expense_accno_id ) if $expense_accno_id;

        push(@errors, t8('Booking group #1 needs a valid income account' , $bg->description)) unless $income_accno;
        push(@errors, t8('Booking group #1 needs a valid expense account', $bg->description)) unless $expense_accno;

        my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by_or_create(buchungsgruppen_id => $bg->id, taxzone_id => $self->config->id);
        # if taxzonechart doesn't exist an empty new TaxzoneChart object is
        # created by find_by_or_create, so we have to assign buchungsgruppe and
        # taxzone again for the new case to work
        $taxzone_chart->taxzone_id($self->config->id);
        $taxzone_chart->buchungsgruppen_id($bg->id);
        $taxzone_chart->income_accno_id($income_accno->id);
        $taxzone_chart->expense_accno_id($expense_accno->id);
        $taxzone_chart->save;
      }
    }

    1;
  })) {
    die @errors ? join("\n", @errors) . "\n" : $db->error . "\n";
    # die with rollback of taxzone save if saving of any of the taxzone_charts fails
    # only show the $db->error if we haven't already identified the likely error ourselves
  }

  flash_later('info', $is_new ? t8('The taxzone has been created.') : t8('The taxzone has been saved.'));
  $self->redirect_to(action => 'list');
}

#
# initializers
#

sub init_defaults { SL::DB::Default->get };

#
# helpers
#

sub setup_show_form_action_bar {
  my ($self) = @_;

  my $is_new = !$self->config->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'Taxzones/' . ($is_new ? 'create' : 'update') } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'Taxzones/delete' } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => $is_new                  ? t8('This object has not been saved yet.')
                  : !$self->config->orphaned ? t8('The object is in use and cannot be deleted.')
                  :                            undef,
      ],

      link => [
        t8('Abort'),
        link => $self->url_for(action => 'list'),
      ],
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add'),
        link => $self->url_for(action => 'new'),
      ],
    );
  }
}

1;
