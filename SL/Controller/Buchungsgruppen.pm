package SL::Controller::Buchungsgruppen;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::TaxZone;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::TaxzoneChart;
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

  $self->setup_list_action_bar;
  $::form->header;
  $self->render('buchungsgruppen/list',
                title           => t8('Booking groups'),
                BUCHUNGSGRUPPEN => $buchungsgruppen,
                CHARTLIST       => \%chartlist,
                TAXZONES        => $taxzones);
}

sub action_new {
  my ($self) = @_;

  $self->config(SL::DB::Buchungsgruppe->new());
  $self->show_form(title => t8('Add booking group'));
}

sub show_form {
  my ($self, %params) = @_;

  $self->setup_show_form_action_bar;
  $self->render('buchungsgruppen/form', %params,
                 TAXZONES       => SL::DB::Manager::TaxZone->get_all_sorted());
}

sub action_edit {
  my ($self) = @_;

  # Allow editing of the charts of the Buchungsgruppe if it isn't assigned to
  # any parts. This is checked inside the template via the Buchungsgruppen
  # orphaned method, where an IF-ELSE statement toggles between L.select_tag
  # and text.

  $self->show_form(title     => t8('Edit booking group'),
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

  $self->{config}->db->with_transaction(sub {
    my $taxzone_charts = SL::DB::Manager::TaxzoneChart->get_all(where => [ buchungsgruppen_id => $self->config->id ]);
    foreach my $taxzonechart ( @{$taxzone_charts} ) { $taxzonechart->delete };
    $self->config->delete();
    flash_later('info',  $::locale->text('The booking group has been deleted.'));

    1;
  }) || flash_later('error', $::locale->text('The booking group is in use and cannot be deleted.'));

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

  my @errors;

  my $db = $self->config->db;
  if (!$db->with_transaction(sub {

    $self->config->assign_attributes(%{ $params }); # assign description and inventory_accno_id

    @errors = $self->config->validate; # check for description and inventory_accno_id

    if (@errors) {
      die "foo" . @errors . "\n";
    };

    $self->config->save;

    # Save or update taxzone_charts for new or unused Buchungsgruppen
    if ($is_new or $self->config->orphaned) {
      my $taxzones = SL::DB::Manager::TaxZone->get_all_sorted();

      foreach my $tz (@{ $taxzones }) {

        my $income_accno_id    = $::form->{"income_accno_id_"  . $tz->id};
        my $expense_accno_id   = $::form->{"expense_accno_id_" . $tz->id};

        my ($income_accno, $expense_accno);
        $income_accno    = SL::DB::Manager::Chart->find_by( id => $income_accno_id  ) if $income_accno_id;
        $expense_accno   = SL::DB::Manager::Chart->find_by( id => $expense_accno_id ) if $expense_accno_id;

        push(@errors, t8('Tax zone #1 needs a valid income account'   , $tz->description)) unless $income_accno;
        push(@errors, t8('Tax zone #1 needs a valid expense account'  , $tz->description)) unless $expense_accno;

        my $taxzone_chart = SL::DB::Manager::TaxzoneChart->find_by_or_create(buchungsgruppen_id => $self->config->id, taxzone_id => $tz->id);
        $taxzone_chart->taxzone_id($tz->id);
        $taxzone_chart->buchungsgruppen_id($self->config->id);
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

  flash_later('info', $is_new ? t8('The booking group has been created.') : t8('The booking group has been saved.'));
  $self->redirect_to(action => 'list');
}

#
# initializers
#

sub init_defaults        { SL::DB::Default->get }

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
        submit    => [ '#form', { action => 'Buchungsgruppen/' . ($is_new ? 'create' : 'update') } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'Buchungsgruppen/delete' } ],
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
