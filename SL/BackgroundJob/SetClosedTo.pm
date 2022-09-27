package SL::BackgroundJob::SetClosedTo;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::Helper::DateTime;

sub create_job {
  $_[0]->create_standard_job('1 0 10 * *'); # always the 10th of the month
}


sub run {
  my ($self, $db_obj) = @_;
  my $data       = $db_obj->data_as_hash;

  my $subtract_month = $data->{subtract_month} || 1;
  my $subtract_days  = $data->{subtract_days}  || 10;

  die "No integer number for days or month" unless ($subtract_month =~ m/^\d+\z/
                                                 && $subtract_days  =~ m/^\d+\z/);

  # new closedto
  my $new_closedto->subtract(months => $subtract_month, days => $subtract_days);

  my $defaults   = SL::DB::Default->get;

  # dont accidently open the books
  return 1 if ($defaults->closedto && $defaults->closedto >= $new_closedto);

  $defaults->closedto($new_closedto);
  $defaults->save || die "Cannot save closedto!";

  return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::SetClosedTo - Background job for
periodically setting closedto (books closed until).
Defaults to the end of the second last month.

=cut
