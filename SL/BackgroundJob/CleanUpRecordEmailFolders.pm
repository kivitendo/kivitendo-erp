package SL::BackgroundJob::CleanUpRecordEmailFolders;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::IMAPClient;

sub clean_up_record_folders {
  my ($self) = @_;
  my $imap_client = SL::IMAPClient->new();

  my $open_sales_orders = SL::DB::Manager::Order->get_all(
    query => [
      vendor_id => undef,
      closed => 0,
    ],
  );

  $imap_client->clean_up_record_folders($open_sales_orders);
}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;

  $self->clean_up_record_folders();

  return;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::CleanUpRecordEmailFolders - Background job for removing email folders of closed records.

=head1 SYNOPSIS

This background job syncs all emails to emails files to the corresponding
record and than removes email folders of closed records.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
