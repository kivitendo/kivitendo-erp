package SL::Controller::PayPostingImport;
use strict;
use parent qw(SL::Controller::Base);

use SL::File;
use SL::Helper::DateTime;
use SL::Helper::Flash qw(flash_later);
use SL::Locale::String qw(t8);

use Carp;
use Text::CSV_XS;

__PACKAGE__->run_before('check_auth');


sub action_upload_pay_postings {
  my ($self, %params) = @_;

  $self->setup_pay_posting_action_bar;
  $self->render('pay_posting_import/form', title => $::locale->text('Import Pay Postings'));
}

sub action_import_datev_pay_postings {
  my ($self, %params) = @_;

  die t8("missing file for action import") unless ($::form->{file});

  my $filename= $::form->{ATTACHMENTS}{file}{filename};

  # check name and first fields of CSV data
  die t8("Wrong file name, expects name like: DTVF_*_LOHNBUCHUNG*.csv") unless $filename =~ /^DTVF_.*_LOHNBUCHUNGEN_LUG.*\.csv$/;
  die t8("not a valid DTVF file, expected first field in A1 'DTVF'")   unless ($::form->{file} =~ m/^"DTVF";/);
  die t8("not a valid DTVF file, expected field header start with 'Umsatz; (..) ;Konto;Gegenkonto'")
    unless ($::form->{file} =~ m/Umsatz;S\/H;;;;;Konto;Gegenkonto.*;;Belegdatum;Belegfeld 1;Belegfeld 2;;Buchungstext/);

  # check if file is already imported
  my $acc_trans_doc = SL::DB::Manager::AccTransaction->get_first(source => $filename);
  die t8("Already imported") if ref $acc_trans_doc eq 'SL::DB::AccTransaction';

  if (parse_and_import($::form->{file}, $filename)) {
    flash_later('info', t8("All pay postings successfully imported."));
  }
  # $self->redirect_to("gl.pl?action=search", source => $filename);
}

sub parse_and_import {
  my $doc      = shift;

  my $csv = Text::CSV_XS->new ({ binary => 0, auto_diag => 1, sep_char => ";" });
  open my $fh, "<:encoding(cp1252)", \$doc;
  # Read/parse CSV
  # Umsatz S/H Konto Gegenkonto (ohne BU-Schlüssel) Belegdatum Belegfeld 1 Belegfeld 2 Buchungstext
  my $year = substr($csv->getline($fh)->[12], 0, 4);

  # whole import or nothing
  my $current_transaction;
  SL::DB->client->with_transaction(sub {
    while (my $row = $csv->getline($fh)) {
      next unless $row->[0] =~ m/\d/;
      my ($credit, $debit, $dt_to_kivi, $length, $accno_credit, $accno_debit,
          $department_name, $department);

      # check valid soll/haben kennzeichen
      croak("No valid debit/credit sign") unless $row->[1] =~ m/^(S|H)$/;

      # check transaction date can be 4 or 3 digit (leading 0 omitted)
      $length = length $row->[9] == 4 ? 2 : 1;
      $dt_to_kivi = DateTime->new(year  => $year,
                                  month => substr ($row->[9], -2),
                                  day   => substr($row->[9],0, $length))->to_kivitendo;

      croak("Something wrong with date conversion") unless $dt_to_kivi;

      $accno_credit = $row->[1] eq 'S' ? $row->[7] : $row->[6];
      $accno_debit  = $row->[1] eq 'S' ? $row->[6] : $row->[7];
      $credit   = SL::DB::Manager::Chart->find_by(accno => $accno_credit);
      $debit    = SL::DB::Manager::Chart->find_by(accno => $accno_debit);

      croak("No such Chart $accno_credit") unless ref $credit eq 'SL::DB::Chart';
      croak("No such Chart $accno_debit")  unless ref $debit  eq 'SL::DB::Chart';

      # optional KOST1 - KOST2 ?
      $department_name = $row->[36];
      $department    = SL::DB::Manager::Department->get_first(description => { like =>  $department_name . '%' });

      my $amount = $::form->parse_amount({ numberformat => '1000,00' }, $row->[0]);

      $current_transaction = SL::DB::GLTransaction->new(
          employee_id    => $::form->{employee_id},
          transdate      => $dt_to_kivi,
          description    => $row->[13],
          reference      => $row->[13],
          department_id  => ref $department eq 'SL::DB::Department' ?  $department->id : undef,
          imported       => 1,
          taxincluded    => 1,
        )->add_chart_booking(
          chart  => $credit,
          credit => $amount,
          source => $::form->{ATTACHMENTS}{file}{filename},
        )->add_chart_booking(
          chart  => $debit,
          debit  => $amount,
          source => $::form->{ATTACHMENTS}{file}{filename},
      )->post;

      # push @rows, $current_transaction->id;

      if ($::instance_conf->get_doc_storage) {
        my $file = SL::File->save(object_id   => $current_transaction->id,
                       object_type => 'gl_transaction',
                       mime_type   => 'text/csv',
                       source      => 'uploaded',
                       file_type   => 'attachment',
                       file_name   => $::form->{ATTACHMENTS}{file}{filename},
                       file_contents   => $doc
                      );
      }
    }

    1;

  }) or do { die t8("Cannot add Booking, reason: #1 DB: #2 ", $@, SL::DB->client->error) };
}

sub check_auth {
  $::auth->assert('general_ledger');
}

sub setup_pay_posting_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $::locale->text('Import'),
        submit    => [ '#form', { action => 'PayPostingImport/import_datev_pay_postings' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::PayPostingImport
Controller for importing pay postings.
Currently only DATEV format is supported.


=head1 FUNCTIONS

=over 2

=item C<action_upload_pay_postings>

Simple upload form. HTML Form allows only CSV files.


=item C<action_import_datev_pay_postings>

Does some sanity checks for the CSV file according to the expected DATEV data structure
If successful calls the parse_and_import function

=item C<parse_and_import>

Internal function for parsing and importing every line of the CSV data as a GL Booking.
Adds the attribute imported for the GL Booking.
If a chart which uses a tax automatic is assigned the tax will be calculated with the
'tax_included' option, which defaults to the DATEV format.

Furthermore adds the original CSV filename for every AccTransaction and puts the CSV in every GL Booking
if the feature DMS is active.
If a Chart is missing or any kind of different error occurs the whole import including the DMS addition
will be aborted

=back
