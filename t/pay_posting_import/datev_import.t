use strict;
use Test::More;
use Test::Exception;

use lib 't';

use_ok 'Support::TestSetup';

use SL::Controller::PayPostingImport;

use utf8;
use Data::Dumper;
use File::Slurp;
use Text::CSV_XS qw (csv);

Support::TestSetup::login();

my $dbh = SL::DB->client->dbh;
my @charts = qw(379000 136900 372000 372500 373000 374000 377000 494700);
local $::locale = Locale->new('en');
diag("init csv");
clear_up();

# datev naming convention and expected filename entry in $::form
$::form->{ATTACHMENTS}{file}{filename} = 'DTVF_44979_43392_LOHNBUCHUNGEN_LUG_202106_20210623_0946';
$::form->{file}                        = read_file('t/pay_posting_import/datev.csv');
my $source                             = $::form->{ATTACHMENTS}{file}{filename};

# get data as aoa datev encodes always CP1252
my $csv_array = csv (in        => "t/pay_posting_import/datev.csv",
                     binary    => 0,
                     auto_diag => 1, sep_char => ";", encoding=> "cp1252");

# probably no correct charts in test db
throws_ok{
  SL::Controller::PayPostingImport::parse_and_import();
 } qr/No such Chart 379000/, "Importing Pay Postings without correct charts";

# create charts
foreach my $accno (@charts) {
  SL::DB::Chart->new(
    accno          => $accno,
    description    => 'Löhne mit Gestöhne',
    charttype      => 'A',
    category       => 'Q',
    link           => '',
    taxkey_id      => '0',
    datevautomatik => 'f',
  )->save;
}

# and add department (KOST1 description)
  SL::DB::Department->new(
    description => 'Wisavis'
  )->save;

SL::Controller::PayPostingImport::parse_and_import();

# get all gl imported bookings
my $gl_bookings = SL::DB::Manager::GLTransaction->get_all(where => [imported => 1] );

# $i number of real data entries in the array (first two rows are headers)
my $i = 2;
is(scalar @{ $csv_array } - $i, scalar @{ $gl_bookings }, "Correct number of imported Pay Posting Bookings");

# check all imported bookings
foreach my $booking (@{ $gl_bookings }) {
  my $current_row = $csv_array->[$i];

  my $accno_credit = $current_row->[1] eq 'S' ? $current_row->[7] : $current_row->[6];
  my $accno_debit  = $current_row->[1] eq 'S' ? $current_row->[6] : $current_row->[7];
  my $amount       = $::form->parse_amount({ numberformat => '1000,00' }, $current_row->[0]);

  # gl
  is ($current_row->[13], $booking->reference, "Buchungstext correct");
  is ("Wisavis", $booking->department->description, "Department correctly assigned");
  is ($source, $booking->transactions->[0]->source, "Source 0 correctly assigned");
  is ($source, $booking->transactions->[1]->source, "Source 1 correctly assigned");

  # acc_trans
  cmp_ok ($amount,      '==',  $booking->transactions->[0]->amount, "Correct amount Soll");
  cmp_ok ($amount * -1, '==',  $booking->transactions->[1]->amount, "Correct amount Haben");
  is (ref $booking->transdate, 'DateTime', "Booking has a Transdate");
  is ($accno_credit, $booking->transactions->[0]->chart->accno, "Sollkonto richtig");
  is ($accno_debit, $booking->transactions->[1]->chart->accno, "Habenkonto richtig");

  $i++;
}

clear_up();


done_testing();

1;

sub clear_up {
  SL::DB::Manager::AccTransaction->delete_all( all => 1);
  SL::DB::Manager::GLTransaction->delete_all(  all => 1);
  foreach my $accno (@charts) {
    SL::DB::Manager::Chart->delete_all(where => [ accno => $accno ] );
  }
};
