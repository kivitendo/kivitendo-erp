package SL::Controller::CsvImport;

use strict;

use SL::DB::Buchungsgruppe;
use SL::DB::CsvImportProfile;
use SL::DB::CsvImportReport;
use SL::DB::Unit;
use SL::DB::Helper::Paginated ();
use SL::Helper::Flash;
use SL::Locale::String;
use SL::SessionFile;
use SL::Controller::CsvImport::Contact;
use SL::Controller::CsvImport::CustomerVendor;
use SL::Controller::CsvImport::Part;
use SL::Controller::CsvImport::Shipto;
use SL::Controller::CsvImport::Project;
use SL::BackgroundJob::CsvImport;
use SL::System::TaskServer;

use List::MoreUtils qw(none);
use List::Util qw(min);

use parent qw(SL::Controller::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(type profile file all_profiles all_charsets sep_char all_sep_chars quote_char all_quote_chars escape_char all_escape_chars all_buchungsgruppen all_units
                                 import_status errors headers raw_data_headers info_headers data num_imported num_importable displayable_columns file) ],
 'scalar --get_set_init' => [ qw(worker task_server) ],
 'array'                 => [
   progress_tracker     => { },
   add_progress_tracker => {  interface => 'add', hash_key => 'progress_tracker' },
 ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('ensure_form_structure');
__PACKAGE__->run_before('check_type', except => [ qw(report) ]);
__PACKAGE__->run_before('load_all_profiles');
__PACKAGE__->run_before('check_task_server');

__PACKAGE__->run_after('cleanup_reports');

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

  if ($data->{errors} and my $first_error =  $data->{errors}->[0]) {
    flash('error', $::locale->text('There was an error parsing the csv file: #1 in line #2.', $first_error->[2], $first_error->[0]));
  }

  if ($data->{progress}{finished} || $data->{errors}) {
    $self->render('csv_import/_deferred_report', { layout => 0 });
  } else {
    if (!$self->task_server->is_running) {
      $self->task_server->start;
      $self->{status_text} = t8('Task Server is not running, starting it now. If this does not change, please check your task server config');
    } elsif (my $phase = $data->{progress}{phase}) {
      $self->{status_text} = "$data->{progress}{plan}{$phase} / $data->{progress}{num_phases} " . t8($phase);
    } else {
      $self->{status_text} = t8('Import not started yet, please wait...');
    }

    $self->render('csv_import/_deferred_results', { layout => 0 });
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

  my $report_id = $params{report_id} || $::form->{id};

  $self->{report}      = SL::DB::Manager::CsvImportReport->find_by(id => $report_id);

  if (!$self->{report}) {
    $::form->error(t8('No report with id #1', $report_id));
  }
  my $num_rows         = $self->{report}->numrows;
  my $num_cols         = SL::DB::Manager::CsvImportReportRow->get_all_count(query => [ csv_import_report_id => $report_id, row => 0 ]);

  # manual paginating, yuck
  my $page = $::form->{page} || 1;
  my $pages = {};
  $pages->{per_page}        = $::form->{per_page} || 20;
  $pages->{max}             = SL::DB::Helper::Paginated::ceil($num_rows, $pages->{per_page}) || 1;
  $pages->{cur}             = $page < 1 ? 1
                            : $page > $pages->{max} ? $pages->{max}
                            : $page;
  $pages->{common}          = [ grep { $_->{visible} } @{ SL::DB::Helper::Paginated::make_common_pages($pages->{cur}, $pages->{max}) } ];

  $self->{display_rows} = [
    0,
    $pages->{per_page} * ($pages->{cur}-1) + 1
      ..
    min($pages->{per_page} * $pages->{cur}, $num_rows)
  ];

  my @query = (
    csv_import_report_id => $report_id,
    or => [
      row => 0,
      and => [
        row => { gt => $pages->{per_page} * ($pages->{cur}-1) },
        row => { le => $pages->{per_page} * $pages->{cur} },
      ]
    ]
  );

  my $rows             = SL::DB::Manager::CsvImportReportRow->get_all(query => \@query);
  my $status           = SL::DB::Manager::CsvImportReportStatus->get_all(query => \@query);

  $self->{report_rows}   = $self->{report}->folded_rows(rows => $rows);
  $self->{report_status} = $self->{report}->folded_status(status => $status);
  $self->{pages} = $pages;
  $self->{base_url} = $self->url_for(action => 'report', id => $report_id, no_layout => $params{no_layout} || $::form->{no_layout} );

  $self->render('csv_import/report', { layout => !($params{no_layout} || $::form->{no_layout}) });
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

  my $file = SL::SessionFile->new($self->csv_file_name, mode => '<', encoding => $self->profile->get('charset'));
  if (!$file->fh) {
    flash('error', $::locale->text('No file has been uploaded yet.'));
    return $self->action_new;
  }

  $self->{background_job} = SL::BackgroundJob::CsvImport->create_job(
    file    => $self->csv_file_name,
    profile => $self->profile,
    type    => $self->profile->type,
    test    => $params{test},
  )->save;

  if ($self->task_server->is_running) {
    $self->task_server->wake_up;
  } else {
    $self->task_server->start;
  }

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

  $worker->run(%params);

  return if $self->errors;

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

  $self->track_progress(phase => 'building report', progress => 0);

  my $clone_profile = $self->profile->clone_and_reset_deep;
  $clone_profile->save; # weird bug. if this isn't saved before adding it to the report, it will default back to the last profile.

  my $report = SL::DB::CsvImportReport->new(
    session_id => $::auth->create_or_refresh_session,
    profile    => $clone_profile,
    type       => $self->type,
    file       => '',
    numrows    => scalar @{ $self->data },
  );

  $report->save(cascade => 1) or die $report->db->error;

  my $dbh = $::form->get_standard_dbh;
  $dbh->begin_work;

  my $query  = 'INSERT INTO csv_import_report_rows (csv_import_report_id, col, row, value) VALUES (?, ?, ?, ?)';
  my $query2 = 'INSERT INTO csv_import_report_status (csv_import_report_id, row, type, value) VALUES (?, ?, ?, ?)';

  my $sth = $dbh->prepare($query);
  my $sth2 = $dbh->prepare($query2);

  # save headers
  my (@headers, @info_methods, @raw_methods, @methods);

  for my $i (0 .. $#{ $self->info_headers->{headers} }) {
    next unless         $self->info_headers->{used}->{ $self->info_headers->{methods}->[$i] };
    push @headers,      $self->info_headers->{headers}->[$i];
    push @info_methods, $self->info_headers->{methods}->[$i];
  }
  for my $i (0 .. $#{ $self->headers->{headers} }) {
    next unless         $self->headers->{used}->{ $self->headers->{headers}->[$i] };
    push @headers,      $self->headers->{headers}->[$i];
    push @methods,      $self->headers->{methods}->[$i];
  }
  for my $i (0 .. $#{ $self->raw_data_headers->{headers} }) {
    next unless         $self->raw_data_headers->{used}->{ $self->raw_data_headers->{headers}->[$i] };
    push @headers,      $self->raw_data_headers->{headers}->[$i];
    push @raw_methods,  $self->raw_data_headers->{headers}->[$i];
  }

  $sth->execute($report->id, $_, 0, $headers[$_]) for 0 .. $#headers;

  # col offsets
  my $o1 =       @info_methods;
  my $o2 = $o1 + @methods;

  for my $row (0 .. $#{ $self->data }) {
    $self->track_progress(progress => $row / @{ $self->data } * 100) if $row % 1000 == 0;
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
  my ($self, %params) = @_;

  for my $tracker ($self->progress_tracker) {
    $tracker->track_progress(%params);
  }
}

sub init_task_server {
  SL::System::TaskServer->new;
}

sub cleanup_reports {
  SL::DB::Manager::CsvImportReport->cleanup;
}

sub check_task_server {
  return 1 if $_[0]->task_server->is_running;

  flash('info', t8('The task server is not running at the moment but needed for this module'));

  1;
}

1;
