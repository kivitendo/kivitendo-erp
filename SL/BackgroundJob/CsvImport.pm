package SL::BackgroundJob::CsvImport;

use strict;

use parent qw(SL::BackgroundJob::Base);

use REST::Client qw();
use Text::CSV_XS;
use SL::JSON;
use SL::YAML;
use SL::DB::CsvImportProfile;
use SL::DB::Employee;
use SL::SessionFile::Random;

sub create_job {
  my ($self_or_class, %params) = @_;

  my $package       = ref($self_or_class) || $self_or_class;
  $package          =~ s/SL::BackgroundJob:://;

  my %data = (
    %params,
    session_id => $::auth->get_session_id,
  );

  my $job = SL::DB::BackgroundJob->new(
    type         => 'once',
    active       => 1,
    package_name => $package,
    data         => SL::YAML::Dump(\%data),
  );

  return $job;
}

sub profile {
  my ($self) = @_;

  if (!$self->{profile}) {
    my $data = SL::YAML::Load($self->{db_obj}->data);
    $self->{profile} = SL::DB::Manager::CsvImportProfile->find_by(id => $data->{profile_id});
  }

  return $self->{profile};
}

sub run {
  my $self        = shift;
  $self->{db_obj} = shift;

  my $job           = $self->{db_obj};
  my $result        = '';
  my $http_json_url = $job->data_as_hash->{http_json_url};

  if ($http_json_url) {
    $job->set_data(
      employee_id => SL::DB::Manager::Employee->current->id,
      errors      => [],
    )->save;

    die 'CSV import profile does not exist' unless $self->profile;
    my $client = REST::Client->new({ timeout => 300 });

    my $headers_hash = $job->data_as_hash->{http_headers} // {};
    $client->addHeader($_, $headers_hash->{$_}) for keys %$headers_hash;

    my $resp   = $client->GET($http_json_url);
    die('HTTP ' . $resp->responseCode()) unless _http_status_code_ok($resp->responseCode());
    my $decoded_response = SL::JSON::decode_json($resp->responseContent());

    die 'Downloaded JSON is not an array'                if ref($decoded_response) ne 'ARRAY';
    die 'Downloaded JSON array is empty'                 if scalar(@$decoded_response) == 0;
    die 'Downloaded JSON array elements are not objects' if ref($decoded_response->[0]) ne 'HASH';

    my @keys = sort keys %{$decoded_response->[0]};

    my $sfile = SL::SessionFile::Random->new(mode => ">", encoding => 'UTF-8');

    # JSON to CSV

    my $eol         = "\n";
    my $sep_char    = $self->profile->get('sep_char');
    my $escape_char = $self->profile->get('escape_char');
    my $quote_char  = $self->profile->get('quote_char');

    my $csv = Text::CSV_XS->new({ 'binary'      => 1,
                                  'sep_char'    => $sep_char,
                                  'escape_char' => $escape_char,
                                  'quote_char'  => $quote_char,
                                  'eol'         => $eol, });

    $csv->print($sfile->fh, [@keys]);
    foreach my $row (@$decoded_response) {
      foreach my $k (@keys) {
        die 'JSON field value is not a string or number: ' . $k if ref($row->{$k});
      }
      $csv->print($sfile->fh, [map { ($row->{$_} =~ s{[\r\n]+}{ }gr) } @keys]);
    }
    $sfile->fh->close;

    my $csv_filename = $sfile->file_name;
    $result .= "Downloaded JSON and converted to CSV: " . $sfile->file_name . "\n";

    # Set CSV file in profile

    $job->set_data(session_id => $::auth->get_session_id)->save;

    $self->profile->set('file_name', $csv_filename);

    $result .= "Loaded CSV: $csv_filename\n";

    my $report_id = $job->data_as_hash->{report_id};
    $result .= "Report: controller.pl?action=CsvImport/report&id=$report_id\n";
  }

  $result .= $self->do_import;

  return $result;
}

sub do_import {
  my ($self) = @_;

  require SL::Controller::CsvImport;
  my $c = SL::Controller::CsvImport->new;
  my $job = $self->{db_obj};

  $c->profile($self->profile);
  $c->mappings(SL::JSON::from_json($self->profile->get('json_mappings'))) if $self->profile->get('json_mappings');
  $c->type($job->data_as_hash->{type});
  $c->{employee_id} = $job->data_as_hash->{employee_id};

  my $test = $job->data_as_hash->{test};


  # $::locale->text('parsing csv')
  # $::locale->text('building data')
  # $::locale->text('saving data')
  # $::locale->text('building report')
  $self->track_progress(
    progress => 0,
    plan => {
      'parsing csv'     => 1,
      'building data'   => 2,
    ( 'saving data'     => 3, )x!$test,
      'building report' => ($test ? 3 : 4),
    },
    num_phases => ($test ? 3 : 4),
  );
  $c->add_progress_tracker($self);

  my $session_id = $job->data_as_hash->{session_id};

  $c->test_and_import(test => $test, session_id => $session_id);
  my $result;
  if ($c->errors) {
    $job->set_data(
      errors   => $c->errors,
    )->save;
    $result = $::locale->text('Import finished with errors.');
  } else {

    my $report_id = $c->save_report(session_id => $session_id, test => $test);
    $job->set_data(report_id => $report_id)->save;

    $c->track_progress(finished => 1);
    $result = $::locale->text('Import finished without errors.');
  }

  return $result;
}

sub track_progress {
  my ($self, %params) = @_;

  my $data = $self->{db_obj}->data_as_hash;
  my $progress = $data->{progress} || {};

  $progress->{$_} = $params{$_} for keys %params;
  $self->{db_obj}->set_data(progress => $progress);
  $self->{db_obj}->save;
}

sub _http_status_code_ok { $_[0] >= 200 && $_[0] <= 299 }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Background::CsvImport - backend for automatic imports of csv data

=head1 SYNOPSIS


use SL::BackgroundJob::CsvImport;


From a controller or external source:

  my $job = SL::BackgroundJob::CsvImport->create_job(
    file => $file,
    %import_options
  );

=head1 DESCRIPTION

=head1 FUNCTIONS

=head1 BUGS

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
