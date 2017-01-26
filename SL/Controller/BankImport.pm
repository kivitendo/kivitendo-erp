package SL::Controller::BankImport;
use strict;
use Data::Dumper;
use parent qw(SL::Controller::Base);

use SL::Locale::String qw(t8);
use SL::DB::CsvImportProfile;
use SL::Helper::MT940;

__PACKAGE__->run_before('check_auth');

sub action_upload_mt940 {
  my ($self, %params) = @_;

  my $profile = SL::DB::Manager::CsvImportProfile->find_by(name => 'MT940', login => $::myconfig{login});
  if ( ! $profile ) {
    $profile = SL::DB::Manager::CsvImportProfile->find_by(name => 'MT940', login => 'default');
  }

  $self->setup_upload_mt940_action_bar;
  $self->render('bankimport/form', title => $::locale->text('MT940 import'), profile => $profile ? 1 : 0);
}

sub action_import_mt940 {
  my ($self, %params) = @_;

  die "missing file for action import" unless $::form->{file};

  my $converted_data = SL::Helper::MT940::convert_mt940_data($::form->{file});

  # store the converted data in a session file with a name expected by the profile type "bank_transactions"
  my $file = SL::SessionFile->new("csv-import-bank_transactions.csv", mode => '>');
  $file->fh->print($converted_data);
  $file->fh->close;

  my $profile = SL::DB::Manager::CsvImportProfile->find_by(name => 'MT940', login => $::myconfig{login});
  if ( ! $profile ) {
    $profile = SL::DB::Manager::CsvImportProfile->find_by(name => 'MT940', login => 'default');
  }
  die t8("The MT940 import needs an import profile called MT940") unless $profile;

  $self->redirect_to(controller => 'controller.pl', action => 'CsvImport/test', 'profile.type' => 'bank_transactions', 'profile.id' => $profile->id, force_profile => 1);
}

sub check_auth {
  $::auth->assert('bank_transaction');
}

sub setup_upload_mt940_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $::locale->text('Preview'),
        submit    => [ '#form', { action => 'BankImport/import_mt940' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
