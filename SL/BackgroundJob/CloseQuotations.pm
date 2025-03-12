package SL::BackgroundJob::CloseQuotations;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::Manager::Order;
use SL::DB::Order::TypeData qw(:types);


sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;
  my $data = $job_obj->data_as_hash;

  my $dry_run = ($data->{dry_run}) ? 1 : 0;
  my $today   = DateTime->today;
  my $years   = $data->{years} // 1;
  my $end     = $today->subtract(years => $years);

  my $quotations = SL::DB::Manager::Order->get_all(where => [
    and => [
      or => [
        record_type => REQUEST_QUOTATION_TYPE(),
        record_type => SALES_QUOTATION_TYPE(),
      ],
      transdate => { le => $end },
      or => [ closed => 0, closed => undef],
    ]
  ]);

  my (@req_quos, @sal_quos);

  my %dispatch = (
    REQUEST_QUOTATION_TYPE() => \@req_quos,
    SALES_QUOTATION_TYPE()   => \@sal_quos,
  );

  foreach my $quotation (@{ $quotations }) {
    push @{ $dispatch{$quotation->record_type} }, $quotation->quonumber;

    next if $dry_run;

    $quotation->closed(1);
    $quotation->save();
  }

  return 'Preisanfragen ' . ($dry_run ? 'noch nicht geschlossen' : 'geschlossen') . ': '
    . join(', ', @req_quos)
    . ' Angebote ' . ($dry_run ? 'noch nicht geschlossen' : 'geschlossen') . ': '
    . join(', ', @sal_quos);
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::CloseQuotations —
Background job for closing all request and sales quotations older than a given number of years

=head1 SYNOPSIS

=head1 AUTHOR


=cut

