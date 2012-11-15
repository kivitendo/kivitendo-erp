package SL::Controller::CsvImport;

use strict;

use SL::DB::Buchungsgruppe;
use SL::DB::CsvImportProfile;
use SL::DB::CsvImportReport;
use SL::DB::Unit;
use SL::Helper::Flash;
use SL::SessionFile;
use SL::Controller::CsvImport::Contact;
use SL::Controller::CsvImport::CustomerVendor;
use SL::Controller::CsvImport::Part;
use SL::Controller::CsvImport::Shipto;
use SL::Controller::CsvImport::Project;
use SL::BackgroundJob::CsvImport;
use SL::System::TaskServer;

use List::MoreUtils qw(none);

use parent qw(SL::Controller::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(type profile file all_profiles all_charsets sep_char all_sep_chars quote_char all_quote_chars escape_char all_escape_chars all_buchungsgruppen all_units
                                 import_status errors headers raw_data_headers info_headers data num_imported num_importable displayable_columns file) ],
 'scalar --get_set_init' => [ qw(worker) ],
 'array'                 => [
   progress_tracker     => { },
   add_progress_tracker => {  interface => 'add', hash_key => 'progress_tracker' },
 ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('ensure_form_structure');
__PACKAGE__->run_before('check_type', except => [ qw(report) ]);
__PACKAGE__->run_before('load_all_profiles');

#
# actions
#

sub action_new {
  my ($self) = @_;

  $self->load_default_profile unless $self->profile;
  $self->render_inputs;
}

sub action_test {
  my ($self) = @_;
  $self->test_and_import_deferred(test => 1);
}

sub action_import {
  my $self = shift;
  $self->test_and_import_deferred(test => 0);
}

sub action_save {
  my ($self) = @_;

  $self->profile_from_form(SL::DB::Manager::CsvImportProfile->find_by(name => $::form->{profile}->{name}, login => $::myconfig{login}));
  $self->profile->save;

  flash_later('info', $::locale->text("The profile has been saved under the name '#1'.", $self->profile->name));
  $self->redirect_to(action => 'new', 'profile.type' => $self->type, 'profile.id' => $self->profile->id);
}

sub action_destroy {
  my $self = shift;

  my $profile = SL::DB::CsvImportProfile->new(id => $::form->{profile}->{id}, login => $::myconfig{login});
  $profile->delete(cascade => 1);

  flash_later('info', $::locale->text('The profile \'#1\' has been deleted.', $profile->name));
  $self->redirect_to(action => 'new', 'profile.type' => $self->type);
}

sub action_result {
  my $self = shift;

  # load resultobject
  $self->{background_job} = SL::DB::Manager::BackgroundJob->find_by(id => $::form->{job});

  my $data = $self->{background_job}->data_as_hash;

  my $profile = SL::DB::Manager::CsvImportProfile->find_by(id => $data->{profile_id});

  $self->profile($profile);

  if ($data->{progress} < 100) {
    $self->render('csv_import/_deferred_results', { no_layout => 1 });
  } else {
    $self->action_report(report_id => $data->{report_id}, no_layout => 1);
  }
}

sub action_download_sample {
  my $self = shift;

  $self->profile_from_form;
  $self->setup_help;

  my $file_name = 'csv_import_sample_' . $self->type . '.csv';
  my $file      = SL::SessionFile->new($file_name, mode => '>', encoding => $self->profile->get('charset'));
  my $csv       = Text::CSV_XS->new({ binary => 1, map { ( $_ => $self->profile->get($_) ) } qw(sep_char escape_char quote_char),});

  $csv->print($file->fh, [ map { $_->{name}        } @{ $self->displayable_columns } ]);
  $file->fh->print("\r\n");
  $csv->print($file->fh, [ map { $_->{description} } @{ $self->displayable_columns } ]);
  $file->fh->print("\r\n");

  $file->fh->close;

  $self->send_file($file->file_name, name => $file_name);
}

sub action_report {
  my ($self, %params) = @_;

  $self->{report} = SL::DB::Manager::CsvImportReport->find_by(id => $params{report_id} || $::form->{id});

  $self->render('csv_import/report', { no_layout => $params{no_layout} });
}


#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

sub check_type {
  my ($self) = @_;

  die "Invalid CSV import type" if none { $_ eq $::form->{profile}->{type} } qw(parts customers_vendors addresses contacts projects);
  $self->type($::form->{profile}->{type});
}

sub ensure_form_structure {
  my ($self, %params) = @_;

  $::form->{profile}  = {} unless ref $::form->{profile}  eq 'HASH';
  $::form->{settings} = {} unless ref $::form->{settings} eq 'HASH';
}

#
# helpers
#

sub render_inputs {
  my ($self, %params) = @_;

  $self->all_charsets([ [ 'UTF-8',       'UTF-8'                 ],
                        [ 'ISO-8859-1',  'ISO-8859-1 (Latin 1)'  ],
                        [ 'ISO-8859-15', 'ISO-8859-15 (Latin 9)' ],
                        [ 'CP850',       'CP850 (DOS/ANSI)'      ],
                        [ 'CP1252',      'CP1252 (Windows)'      ],
                      ]);

  my %char_map = $self->char_map;

  foreach my $type (qw(sep quote escape)) {
    my $sub = "all_${type}_chars";
    $self->$sub([ sort { $a->[0] cmp $b->[0] } values %{ $char_map{$type} } ]);

    my $char = $self->profile->get($type . '_char');
    $sub     = "${type}_char";
    $self->$sub(($char_map{$type}->{$char} || [])->[0] || $char);
  }

  $self->file(SL::SessionFile->new($self->csv_file_name));

  my $title = $self->type eq 'customers_vendors' ? $::locale->text('CSV import: customers and vendors')
            : $self->type eq 'addresses'         ? $::locale->text('CSV import: shipping addresses')
            : $self->type eq 'contacts'          ? $::locale->text('CSV import: contacts')
            : $self->type eq 'parts'             ? $::locale->text('CSV import: parts and services')
            : $self->type eq 'projects'          ? $::locale->text('CSV import: projects')
            : die;

  if ($self->{type} eq 'parts') {
    $self->all_buchungsgruppen(SL::DB::Manager::Buchungsgruppe->get_all_sorted);
    $self->all_units(SL::DB::Manager::Unit->get_all_sorted);
  }

  $self->setup_help;

  $self->render('csv_import/form', title => $title);
}

sub test_and_import_deferred {
  my ($self, %params) = @_;

  $self->profile_from_form;

  if ($::form->{file}) {
    my $file = SL::SessionFile->new($self->csv_file_name, mode => '>');
    $file->fh->print($::form->{file});
    $file->fh->close;
  }

  $self->{background_job} = SL::BackgroundJob::CsvImport->create_job(
    file    => $self->csv_file_name,
    profile => $self->profile,
    type    => $self->profile->type,
  )->save;

  SL::System::TaskServer->start_if_not_running;
  SL::System::TaskServer->wake_up;

  flash('info', $::locale->text('Your import is beig processed.'));

  $self->{deferred} = 1;

  $self->render_inputs;
}

sub test_and_import {
  my ($self, %params) = @_;

  my $file = SL::SessionFile->new(
    $self->csv_file_name,
    mode       => '<',
    encoding   => $self->profile->get('charset'),
    session_id => $params{session_id}
  );

  $self->file($file);

  my $worker = $self->worker();

  $worker->run;

  $self->num_imported(0);
  $worker->save_objects if !$params{test};

  $self->num_importable(scalar grep { !$_ } map { scalar @{ $_->{errors} } } @{ $self->data || [] });
  $self->import_status($params{test} ? 'tested' : 'imported');

#  flash('info', $::locale->text('Objects have been imported.')) if !$params{test};
}

sub load_default_profile {
  my ($self) = @_;

  my $profile;
  if ($::form->{profile}->{id}) {
    $profile = SL::DB::Manager::CsvImportProfile->find_by(id => $::form->{profile}->{id}, login => $::myconfig{login});
  }
  $profile ||= SL::DB::Manager::CsvImportProfile->find_by(type => $self->{type}, is_default => 1, login => $::myconfig{login});
  $profile ||= SL::DB::CsvImportProfile->new(type => $self->{type}, login => $::myconfig{login});

  $self->profile($profile);
  $self->profile->set_defaults;
}

sub load_all_profiles {
  my ($self, %params) = @_;

  $self->all_profiles(SL::DB::Manager::CsvImportProfile->get_all(
    where => [
      type  => $self->type,
      login => $::myconfig{login},
    ],
  sort_by => 'name'));
}

sub profile_from_form {
  my ($self, $existing_profile) = @_;

  delete $::form->{profile}->{id};

  my %char_map = $self->char_map;
  my @settings;

  foreach my $type (qw(sep quote escape)) {
    my %rev_chars = map { $char_map{$type}->{$_}->[0] => $_ } keys %{ $char_map{$type} };
    my $char      = $::form->{"${type}_char"} eq 'custom' ? $::form->{"custom_${type}_char"} : $rev_chars{ $::form->{"${type}_char"} };

    push @settings, { key => "${type}_char", value => $char };
  }

  if ($self->type eq 'parts') {
    $::form->{settings}->{sellprice_adjustment} = $::form->parse_amount(\%::myconfig, $::form->{settings}->{sellprice_adjustment});
  }

  delete $::form->{profile}->{id};
  $self->profile($existing_profile || SL::DB::CsvImportProfile->new(login => $::myconfig{login}));
  $self->profile->assign_attributes(%{ $::form->{profile} });
  $self->profile->settings(map({ { key => $_, value => $::form->{settings}->{$_} } } keys %{ $::form->{settings} }),
                           @settings);
  $self->profile->set_defaults;
}

sub char_map {
  return ( sep    => { ','  => [ 'comma',     $::locale->text('Comma')     ],
                       ';'  => [ 'semicolon', $::locale->text('Semicolon') ],
                       "\t" => [ 'tab',       $::locale->text('Tab')       ],
                       ' '  => [ 'space',     $::locale->text('Space')     ],
                     },
           quote  => { '"' => [ 'quote', $::locale->text('Quotes') ],
                       "'" => [ 'singlequote', $::locale->text('Single quotes') ],
                     },
           escape => { '"' => [ 'quote', $::locale->text('Quotes') ],
                       "'" => [ 'singlequote', $::locale->text('Single quotes') ],
                     },
         );
}

sub save_report {
  my ($self, $report_id) = @_;

  my $clone_profile = $self->profile->clone_and_reset_deep;
  $clone_profile->save; # weird bug. if this isn't saved before adding it to the report, it will default back to the last profile.

  my $report = SL::DB::CsvImportReport->new(
    session_id => $::auth->create_or_refresh_session,
    profile    => $clone_profile,
    type       => $self->type,
    file       => '',
  )->save(cascade => 1);

  my $dbh = $::form->get_standard_dbh;
  $dbh->begin_work;

  my $query  = 'INSERT INTO csv_import_report_rows (csv_import_report_id, col, row, value) VALUES (?, ?, ?, ?)';
  my $query2 = 'INSERT INTO csv_import_report_status (csv_import_report_id, row, type, value) VALUES (?, ?, ?, ?)';

  my $sth = $dbh->prepare($query);
  my $sth2 = $dbh->prepare($query2);

  # save headers
  my @headers = (
    grep({ $self->info_headers->{used}->{$_}     } @{ $self->info_headers->{headers} }),
    grep({ $self->headers->{used}->{$_}          } @{ $self->headers->{headers} }),
    grep({ $self->raw_data_headers->{used}->{$_} } @{ $self->raw_data_headers->{headers} }),
  );
  my @info_methods = grep { $self->info_headers->{used}->{$_}     } @{ $self->info_headers->{headers} };
  my @methods      = grep { $self->headers->{used}->{$_}          } @{ $self->headers->{methods} };
  my @raw_methods  = grep { $self->raw_data_headers->{used}->{$_} } @{ $self->raw_data_headers->{headers} };

  $sth->execute($report->id, $_, 0, $headers[$_]) for 0 .. $#headers;

  # col offsets
  my $o1 =       @info_methods;
  my $o2 = $o1 + @methods;

  for my $row (0 .. $#{ $self->data }) {
    my $data_row = $self->{data}[$row];

    $sth->execute($report->id,       $_, $row + 1, $data_row->{info_data}{ $info_methods[$_] }) for 0 .. $#info_methods;
    $sth->execute($report->id, $o1 + $_, $row + 1, $data_row->{object}->${ \ $methods[$_] })    for 0 .. $#methods;
    $sth->execute($report->id, $o2 + $_, $row + 1, $data_row->{raw_data}{ $raw_methods[$_] })   for 0 .. $#raw_methods;

    $sth2->execute($report->id, $row + 1, 'information', $_) for @{ $data_row->{information} || [] };
    $sth2->execute($report->id, $row + 1, 'errors', $_)      for @{ $data_row->{errors}      || [] };
  }

  $dbh->commit;

  return $report->id;
}

sub csv_file_name {
  my ($self) = @_;
  return "csv-import-" . $self->type . ".csv";
}

sub init_worker {
  my $self = shift;

  my @args = (controller => $self);

  if ( $self->file() ) {
    push(@args, file => $self->file());
  }

  return $self->{type} eq 'customers_vendors' ? SL::Controller::CsvImport::CustomerVendor->new(@args)
       : $self->{type} eq 'contacts'          ? SL::Controller::CsvImport::Contact->new(@args)
       : $self->{type} eq 'addresses'         ? SL::Controller::CsvImport::Shipto->new(@args)
       : $self->{type} eq 'parts'             ? SL::Controller::CsvImport::Part->new(@args)
       : $self->{type} eq 'projects'          ? SL::Controller::CsvImport::Project->new(@args)
       :                                        die "Program logic error";
}

sub setup_help {
  my ($self) = @_;

  $self->worker->setup_displayable_columns;
}

sub track_progress {
  my ($self, $progress) = @_;

  for my $tracker ($self->progress_tracker) {
    $tracker->track_progress($progress);
  }
}


1;
