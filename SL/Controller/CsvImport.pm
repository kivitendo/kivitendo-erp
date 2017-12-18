package SL::Controller::CsvImport;

use strict;

use SL::DB;
use SL::DB::Buchungsgruppe;
use SL::DB::CsvImportProfile;
use SL::DB::CsvImportReport;
use SL::DB::Unit;
use SL::DB::Helper::Paginated ();
use SL::DBUtils qw(do_statement);
use SL::Helper::Flash;
use SL::Locale::String;
use SL::SessionFile;
use SL::SessionFile::Random;
use SL::Controller::CsvImport::Contact;
use SL::Controller::CsvImport::CustomerVendor;
use SL::Controller::CsvImport::Part;
use SL::Controller::CsvImport::Inventory;
use SL::Controller::CsvImport::Shipto;
use SL::Controller::CsvImport::Project;
use SL::Controller::CsvImport::Order;
use SL::Controller::CsvImport::ARTransaction;
use SL::JSON;
use SL::Controller::CsvImport::BankTransaction;
use SL::BackgroundJob::CsvImport;
use SL::System::TaskServer;

use List::MoreUtils qw(none);
use List::Util qw(min);

use parent qw(SL::Controller::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(type profile all_profiles all_charsets sep_char all_sep_chars quote_char all_quote_chars escape_char all_escape_chars all_buchungsgruppen all_units
                                 import_status errors headers raw_data_headers info_headers data num_importable displayable_columns file all_taxzones) ],
 'scalar --get_set_init' => [ qw(worker task_server num_imported mappings) ],
 'array'                 => [
   progress_tracker     => { },
   add_progress_tracker => {  interface => 'add', hash_key => 'progress_tracker' },
 ],
);

__PACKAGE__->run_before('check_auth', except => [ qw(report) ]);
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
    flash('error', $::locale->text('There was an error parsing the csv file: #1 in line #2: #3', $first_error->[2], $first_error->[0], $first_error->[1]));
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

  if ($self->worker->is_multiplexed) {
    foreach my $p (@{ $self->worker->profile }) {
      $csv->print($file->fh, [ map { $_->{name}        } @{ $self->displayable_columns->{$p->{row_ident}} } ]);
      $file->fh->print("\r\n");
    }
    foreach my $p (@{ $self->worker->profile }) {
      $csv->print($file->fh, [ map { $_->{description} } @{ $self->displayable_columns->{$p->{row_ident}} } ]);
      $file->fh->print("\r\n");
    }
  } else {
    $csv->print($file->fh, [ map { $_->{name}        } @{ $self->displayable_columns } ]);
    $file->fh->print("\r\n");
    $csv->print($file->fh, [ map { $_->{description} } @{ $self->displayable_columns } ]);
    $file->fh->print("\r\n");
  }

  $file->fh->close;

  $self->send_file($file->file_name, name => $file_name);
}

sub action_report {
  my ($self, %params) = @_;

  my $report_id   = $params{report_id} || $::form->{id};
  $self->{report} = SL::DB::Manager::CsvImportReport->find_by(id => $report_id);

  if (!$self->{report}) {
    $::form->error(t8('No report with id #1', $report_id));
  }

  my $num_rows               = $self->{report}->numrows;

  # manual paginating, yuck
  my $page                   = $::form->{page} || 1;
  my $pages                  = {};
  $pages->{per_page}         = $::form->{per_page} || 20;
  $pages->{max}              = SL::DB::Helper::Paginated::ceil($num_rows, $pages->{per_page}) || 1;
  $pages->{page}             = $page < 1             ? 1
                             : $page > $pages->{max} ? $pages->{max}
                             : $                       page;
  $pages->{common}           = [ grep { $_->{visible} } @{ SL::DB::Helper::Paginated::make_common_pages($pages->{page}, $pages->{max}) } ];

  $self->{report_numheaders} = $self->{report}->numheaders;
  my $first_row_header       = 0;
  my $last_row_header        = $self->{report_numheaders} - 1;
  my $first_row_data         = $pages->{per_page} * ($pages->{page}-1) + $self->{report_numheaders};
  my $last_row_data          = min($pages->{per_page} * $pages->{page}, $num_rows) + $self->{report_numheaders} - 1;
  $self->{display_rows}      = [
    $first_row_header
      ..
    $last_row_header,
    $first_row_data
      ..
    $last_row_data
  ];

  my @query = (
    csv_import_report_id => $report_id,
    or => [
      and => [
        row => { ge => $first_row_header },
        row => { le => $last_row_header },
      ],
      and => [
        row => { ge => $first_row_data },
        row => { le => $last_row_data },
      ]
    ]
  );

  my $rows               = SL::DB::Manager::CsvImportReportRow   ->get_all(query => \@query);
  my $status             = SL::DB::Manager::CsvImportReportStatus->get_all(query => \@query);

  $self->{report_rows}   = $self->{report}->folded_rows(rows => $rows);
  $self->{report_status} = $self->{report}->folded_status(status => $status);
  $self->{pages}         = $pages;
  $self->{base_url}      = $self->url_for(action => 'report', id => $report_id, no_layout => $params{no_layout} || $::form->{no_layout} );

  $self->render('csv_import/report', { layout => !($params{no_layout} || $::form->{no_layout}) });
}

sub action_add_empty_mapping_line {
  my ($self) = @_;

  $self->profile_from_form;
  $self->setup_help;

  $self->js
    ->append('#csv_import_mappings', $self->render('csv_import/_mapping_item', { layout => 0, output => 0 }))
    ->hide('#mapping_empty')
    ->render;
}

sub action_add_mapping_from_upload {
  my ($self) = @_;

  if ($::form->{tmp_profile_id}) {
    $self->profile_from_form(SL::DB::CsvImportProfile->new(id => $::form->{tmp_profile_id})->load);
  } else {
    $self->profile_from_form;
  }
  $self->setup_help;

  my $file_name;
  if ($self->profile->get('file_name')) {
    $file_name = $self->profile->get('file_name');
  } else {
    $self->js
      ->flash('error', t8('No file has been uploaded yet.'))
      ->render;
    return;
  }

  my $file = SL::SessionFile->new($file_name, mode => '<', encoding => $self->profile->get('charset'));
  if (!$file->fh) {
    $self->js
      ->flash('error', t8('No file has been uploaded yet.'))
      ->render;
    return;
  }

  my $csv = SL::Helper::Csv->new(
    file => $file->file_name,
    map { $_ => $self->profile->get($_) } qw(sep_char escape_char quote_char),
  );

  $csv->_open_file;
  my $header = $csv->check_header;

  for my $field (@$header) {
    next if $self->mappings_for_profile->{$field};
    $self->js->append(
      '#csv_import_mappings',
      $self->render('csv_import/_mapping_item', { layout => 0, output => 0 }, item => { from => $field }),
    );
  }

  $self->js
    ->hide('#mapping_empty')
    ->render;
}


#
# filters
#

sub check_auth {
  $_[0]->check_type;
  $_[0]->worker->check_auth;
}

sub check_type {
  my ($self) = @_;

  die "Invalid CSV import type" if none { $_ eq $::form->{profile}->{type} } qw(parts inventories customers_vendors addresses contacts projects orders bank_transactions ar_transactions);
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

  if ($self->profile->get('file_name')) {
    $self->file(SL::SessionFile->new($self->profile->get('file_name')));
  }

  my $title = $self->type eq 'customers_vendors' ? $::locale->text('CSV import: customers and vendors')
            : $self->type eq 'addresses'         ? $::locale->text('CSV import: shipping addresses')
            : $self->type eq 'contacts'          ? $::locale->text('CSV import: contacts')
            : $self->type eq 'parts'             ? $::locale->text('CSV import: parts and services')
            : $self->type eq 'inventories'       ? $::locale->text('CSV import: inventories')
            : $self->type eq 'projects'          ? $::locale->text('CSV import: projects')
            : $self->type eq 'orders'            ? $::locale->text('CSV import: orders')
            : $self->type eq 'bank_transactions' ? $::locale->text('CSV import: bank transactions')
            : $self->type eq 'ar_transactions'   ? $::locale->text('CSV import: ar transactions')
            : die;

  if ($self->{type} eq 'customers_vendors' or $self->{type} eq 'orders' or $self->{type} eq 'ar_transactions' ) {
    $self->all_taxzones(SL::DB::Manager::TaxZone->get_all_sorted(query => [ obsolete => 0 ]));
  };

  if ($self->{type} eq 'parts') {
    $self->all_buchungsgruppen(SL::DB::Manager::Buchungsgruppe->get_all_sorted);
    $self->all_units(SL::DB::Manager::Unit->get_all_sorted);
  }

  $self->setup_help;

  $self->setup_render_inputs_action_bar;

  $self->render('csv_import/form', title => $title);
}

sub test_and_import_deferred {
  my ($self, %params) = @_;

  if ( $::form->{force_profile} && ($::form->{tmp_profile_id} || $::form->{profile}->{id}) ) {
    $::form->{profile}->{id} = $::form->{tmp_profile_id} if $::form->{tmp_profile_id};
    $self->load_default_profile;
  } elsif ($::form->{tmp_profile_id}) {
    $self->profile_from_form(SL::DB::CsvImportProfile->new(id => $::form->{tmp_profile_id})->load);
  } else {
    $self->profile_from_form;
  };

  my $file_name;
  if ($::form->{file}) {
    my $file = SL::SessionFile::Random->new(mode => '>');
    $file->fh->print($::form->{file});
    $file->fh->close;
    $file_name = $file->file_name;
    $self->profile->set('file_name', $file_name);
  } elsif ($self->profile->get('file_name')) {
    $file_name = $self->profile->get('file_name');
  } else {
    flash('error', $::locale->text('No file has been uploaded yet.'));
    return $self->action_new;
  }

  my $file = SL::SessionFile->new($file_name, mode => '<', encoding => $self->profile->get('charset'));
  if (!$file->fh) {
    flash('error', $::locale->text('No file has been uploaded yet.'));
    return $self->action_new;
  }

  # save tempory profile
  $self->profile($self->profile->clone_and_reset_deep)->save;

  $self->{background_job} = SL::BackgroundJob::CsvImport->create_job(
    profile_id  => $self->profile->id,
    type        => $self->profile->type,
    test        => $params{test},
    employee_id => SL::DB::Manager::Employee->current->id,
  )->save;

  if ($self->task_server->is_running) {
    $self->task_server->wake_up;
  } else {
    $self->task_server->start;
  }

  flash('info', $::locale->text('Your import is being processed.'));

  $self->{deferred} = 1;

  if ($::request->type eq 'json') {
    $self->render(\ SL::JSON::to_json($self->{background_job}->as_tree), { type => 'json' })
  } else {
    $self->render_inputs;
  }
}

sub test_and_import {
  my ($self, %params) = @_;

  my $file = SL::SessionFile->new(
    $self->profile->get('file_name'),
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
    $profile = SL::DB::Manager::CsvImportProfile->find_by(id => $::form->{profile}->{id});
  }
  $profile ||= SL::DB::Manager::CsvImportProfile->find_by(type => $self->{type}, is_default => 1, login => $::myconfig{login});
  $profile ||= SL::DB::CsvImportProfile->new(type => $self->{type}, login => $::myconfig{login});

  $self->profile($profile);
  $self->mappings(SL::JSON::from_json($self->profile->get('json_mappings'))) if $self->profile->get('json_mappings');
  $self->worker->set_profile_defaults;
  $self->profile->set_defaults;
}

sub load_all_profiles {
  my ($self, %params) = @_;

  $self->all_profiles(SL::DB::Manager::CsvImportProfile->get_all(
    where => [
      type  => $self->type,
      login => $::myconfig{login},
      '!name'  => '',
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

  if ($self->type eq 'orders') {
    $::form->{settings}->{max_amount_diff} = $::form->parse_amount(\%::myconfig, $::form->{settings}->{max_amount_diff});
  }

  $self->profile($existing_profile || SL::DB::CsvImportProfile->new(login => $::myconfig{login}));
  $self->profile->assign_attributes(%{ $::form->{profile} });

  # save settings for file_name, as this is not in form, but maybe in existing_profile
  push @settings, { key => 'file_name', value => $self->profile->get('file_name') } if $self->profile->get('file_name');

  $self->profile->settings(map({ { key => $_, value => $::form->{settings}->{$_} } } keys %{ $::form->{settings} }),
                           @settings);
  $self->profile->set('json_mappings', JSON::to_json($self->mappings));
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
  my ($self, %params) = @_;

  if ($self->worker->is_multiplexed) {
    return $self->save_report_multi(%params);
  } else {
    return $self->save_report_single(%params);
  }
}

sub save_report_single {
  my ($self, %params) = @_;

  $self->track_progress(phase => 'building report', progress => 0);

  my $report = SL::DB::CsvImportReport->new(
    session_id => $params{session_id},
    profile_id => $self->profile->id,
    type       => $self->type,
    file       => '',
    numrows    => scalar @{ $self->data },
    numheaders => 1,
    test_mode  => $params{test} ? 1 : 0,
  );

  $report->save(cascade => 1) or die $report->db->error;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

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

    do_statement($::form, $sth, $query, $report->id, $_, 0, $headers[$_]) for 0 .. $#headers;

    # col offsets
    my $o1 =       @info_methods;
    my $o2 = $o1 + @methods;

    for my $row (0 .. $#{ $self->data }) {
      $self->track_progress(progress => $row / @{ $self->data } * 100) if $row % 1000 == 0;
      my $data_row = $self->{data}[$row];

      do_statement($::form, $sth, $query, $report->id,       $_, $row + 1, $data_row->{info_data}{ $info_methods[$_] }) for 0 .. $#info_methods;
      do_statement($::form, $sth, $query, $report->id, $o1 + $_, $row + 1, $data_row->{object}->${ \ $methods[$_] })    for 0 .. $#methods;
      do_statement($::form, $sth, $query, $report->id, $o2 + $_, $row + 1, $data_row->{raw_data}{ $raw_methods[$_] })   for 0 .. $#raw_methods;

      do_statement($::form, $sth2, $query2, $report->id, $row + 1, 'information', $_) for @{ $data_row->{information} || [] };
      do_statement($::form, $sth2, $query2, $report->id, $row + 1, 'errors', $_)      for @{ $data_row->{errors}      || [] };
    }
    1;
  }) or do { die SL::DB->client->error };

  return $report->id;
}

sub save_report_multi {
  my ($self, %params) = @_;

  $self->track_progress(phase => 'building report', progress => 0);

  my $report = SL::DB::CsvImportReport->new(
    session_id => $params{session_id},
    profile_id => $self->profile->id,
    type       => $self->type,
    file       => '',
    numrows    => scalar @{ $self->data },
    numheaders => scalar @{ $self->worker->profile },
    test_mode  => $params{test} ? 1 : 0,
  );

  $report->save(cascade => 1) or die $report->db->error;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    my $query  = 'INSERT INTO csv_import_report_rows (csv_import_report_id, col, row, value) VALUES (?, ?, ?, ?)';
    my $query2 = 'INSERT INTO csv_import_report_status (csv_import_report_id, row, type, value) VALUES (?, ?, ?, ?)';

    my $sth = $dbh->prepare($query);
    my $sth2 = $dbh->prepare($query2);

    # save headers
    my ($headers, $info_methods, $raw_methods, $methods);

    for my $i (0 .. $#{ $self->worker->profile }) {
      my $row_ident = $self->worker->profile->[$i]->{row_ident};

      for my $i (0 .. $#{ $self->info_headers->{$row_ident}->{headers} }) {
        next unless                            $self->info_headers->{$row_ident}->{used}->{ $self->info_headers->{$row_ident}->{methods}->[$i] };
        push @{ $headers->{$row_ident} },      $self->info_headers->{$row_ident}->{headers}->[$i];
        push @{ $info_methods->{$row_ident} }, $self->info_headers->{$row_ident}->{methods}->[$i];
      }
      for my $i (0 .. $#{ $self->headers->{$row_ident}->{headers} }) {
        next unless                       $self->headers->{$row_ident}->{used}->{ $self->headers->{$row_ident}->{headers}->[$i] };
        push @{ $headers->{$row_ident} }, $self->headers->{$row_ident}->{headers}->[$i];
        push @{ $methods->{$row_ident} }, $self->headers->{$row_ident}->{methods}->[$i];
      }

      for my $i (0 .. $#{ $self->raw_data_headers->{$row_ident}->{headers} }) {
      next unless                           $self->raw_data_headers->{$row_ident}->{used}->{ $self->raw_data_headers->{$row_ident}->{headers}->[$i] };
      push @{ $headers->{$row_ident} },     $self->raw_data_headers->{$row_ident}->{headers}->[$i];
      push @{ $raw_methods->{$row_ident} }, $self->raw_data_headers->{$row_ident}->{headers}->[$i];
    }

    }

    for my $i (0 .. $#{ $self->worker->profile }) {
      my $row_ident = $self->worker->profile->[$i]->{row_ident};
      do_statement($::form, $sth, $query, $report->id, $_, $i, $headers->{$row_ident}->[$_]) for 0 .. $#{ $headers->{$row_ident} };
    }

    # col offsets
    my ($off1, $off2);
    for my $i (0 .. $#{ $self->worker->profile }) {
      my $row_ident = $self->worker->profile->[$i]->{row_ident};
      my $n_info_methods = $info_methods->{$row_ident} ? scalar @{ $info_methods->{$row_ident} } : 0;
      my $n_methods      = $methods->{$row_ident} ?      scalar @{ $methods->{$row_ident} }      : 0;

      $off1->{$row_ident} = $n_info_methods;
      $off2->{$row_ident} = $off1->{$row_ident} + $n_methods;
    }

    my $n_header_rows = scalar @{ $self->worker->profile };

    for my $row (0 .. $#{ $self->data }) {
      $self->track_progress(progress => $row / @{ $self->data } * 100) if $row % 1000 == 0;
      my $data_row = $self->{data}[$row];
      my $row_ident = $data_row->{raw_data}{datatype};

      my $o1 = $off1->{$row_ident};
      my $o2 = $off2->{$row_ident};

      do_statement($::form, $sth, $query, $report->id,       $_, $row + $n_header_rows, $data_row->{info_data}{ $info_methods->{$row_ident}->[$_] }) for 0 .. $#{ $info_methods->{$row_ident} };
      do_statement($::form, $sth, $query, $report->id, $o1 + $_, $row + $n_header_rows, $data_row->{object}->${ \ $methods->{$row_ident}->[$_] })    for 0 .. $#{ $methods->{$row_ident} };
      do_statement($::form, $sth, $query, $report->id, $o2 + $_, $row + $n_header_rows, $data_row->{raw_data}{ $raw_methods->{$row_ident}->[$_] })   for 0 .. $#{ $raw_methods->{$row_ident} };

      do_statement($::form, $sth2, $query2, $report->id, $row + $n_header_rows, 'information', $_) for @{ $data_row->{information} || [] };
      do_statement($::form, $sth2, $query2, $report->id, $row + $n_header_rows, 'errors', $_)      for @{ $data_row->{errors}      || [] };
    }
    1;
  }) or do { die SL::DB->client->error };

  return $report->id;
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
       : $self->{type} eq 'inventories'       ? SL::Controller::CsvImport::Inventory->new(@args)
       : $self->{type} eq 'projects'          ? SL::Controller::CsvImport::Project->new(@args)
       : $self->{type} eq 'orders'            ? SL::Controller::CsvImport::Order->new(@args)
       : $self->{type} eq 'bank_transactions' ? SL::Controller::CsvImport::BankTransaction->new(@args)
       : $self->{type} eq 'ar_transactions'   ? SL::Controller::CsvImport::ARTransaction->new(@args)
       :                                        die "Program logic error";
}

sub init_num_imported { 0 }

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
  if (!$::auth->client->{task_server_user_id}) {
    flash('error', t8('The task server is required for this module but not enabled for the current client. Please enable it for the client "#1" in the administration section.', $::auth->client->{name}));
  }

  return 1 if $_[0]->task_server->is_running;

  flash('warning', t8('The task server is not running at the moment but needed for this module'));

  1;
}

sub mappings_for_profile {
  +{ map { $_->{from} => $_->{to} } @{ $_[0]->mappings } }
}

sub init_mappings {
  [ grep { $_->{from} } @{ $::form->{mappings} || [] } ]
}

sub setup_render_inputs_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Preview'),
        submit    => [ '#form', { action => 'CsvImport/test' } ],
        accesskey => 'enter',
        not_if    => ($self->profile && $self->profile->get('dont_edit_profile')),
      ],
      action => [
        t8('Import'),
        submit    => [ '#form', { action => 'CsvImport/import' } ],
        disabled  => t8('The test import has not been executed yet.'),
        id        => 'action_import',
      ],
    );
  }
}

1;
