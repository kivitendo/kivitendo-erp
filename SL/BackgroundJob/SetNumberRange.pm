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

  my $running_year  =  $data->{current_year} ? DateTime->today_local->truncate(to => 'year')
                     : DateTime->today_local->truncate(to => 'year')->add(years => 1)->year();

  $running_year     = ($data->{digits_year} == 2) ? substr($running_year, 2, 2) : $running_year;

  my $multiplier = $data->{multiplier} || 100;

  my $defaults   = SL::DB::Default->get;

  foreach (qw(invnumber cnnumber soinumber pqinumber sonumber ponumber pocnumber
              sqnumber rfqnumber sdonumber pdonumber sudonumber rdonumber
              s_reclamation_record_number p_reclamation_record_number           )) {

    my $current_number = SL::PrefixedNumber->new(number => $defaults->{$_});
    $current_number->set_to($running_year * $multiplier);
    $defaults->{$_} = $current_number->get_current;
  }
  $defaults->save() || die "Could not change number ranges";

  return exists $data->{result} ? $data->{result} : 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::SetNumberRange —
Background job for setting all kivitendo number ranges for a new year

=head1 SYNOPSIS

The backgroud accepts the following optional json encoded parameters in the data field:

C<multiplier>: Multiplier to set the number range (defaults to 100)

C<digits_year>: Handles the encoding of the year (can be 2 or 4, ie 24 or 2024). Defaults to 4

C<current_year>: If set to 1 the current year will be used and not the next year.


The latter option is useful if the jobs runs on the 1st of the new year.

The job is deactivated by default. Administrators of installations
where such a feature is wanted have to create a job entry manually.

=head1 AUTHOR

Jan Büren E<lt>jan@kivitendo.deE<gt>

=cut
