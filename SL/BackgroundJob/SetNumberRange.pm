package SL::BackgroundJob::SetNumberRange;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::PrefixedNumber;

use DateTime::Format::Strptime;

sub create_job {
  $_[0]->create_standard_job('59 23 31 12 *'); # one minute before new year
}


sub run {
  my ($self, $db_obj) = @_;
  my $data       = $db_obj->data_as_hash;

  if ($data->{digits_year} && !($data->{digits_year} == 2 || $data->{digits_year} == 4)) {
    die "No valid input for digits_year should be 2 or 4.";
  }
  if ($data->{multiplier}  && !($data->{multiplier} % 10 == 0)) {
    die "No valid input for multiplier should be 10, 100, .., 1000000";
  }
  my $next_year  = DateTime->today_local->truncate(to => 'year')->add(years => 1)->year();
  $next_year     = ($data->{digits_year} == 2) ? substr($next_year, 2, 2) : $next_year;
  my $multiplier = $data->{multiplier} || 100;

  my $defaults   = SL::DB::Default->get;

  foreach (qw(invnumber cnnumber sonumber ponumber sqnumber rfqnumber sdonumber pdonumber)) {
    my $current_number = SL::PrefixedNumber->new(number => $defaults->{$_});
    $current_number->set_to($next_year * $multiplier);
    $defaults->{$_} = $current_number->get_current;
  }
  $defaults->save() || die "Could not change number ranges";

  return exists $data->{result} ? $data->{result} : 1;
}

1;
