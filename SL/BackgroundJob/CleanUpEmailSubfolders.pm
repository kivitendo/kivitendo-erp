package SL::BackgroundJob::CleanUpEmailSubfolders;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::IMAPClient;

sub clean_up_record_subfolders {
  my ($self) = @_;
  my $imap_client = SL::IMAPClient->new(%{$::lx_office_conf{imap_client}});

  my $open_sales_orders = SL::DB::Manager::Order->get_all(
    query => [
      vendor_id => undef,
      closed => 0,
    ],
  );

  $imap_client->clean_up_record_subfolders(active_records => $open_sales_orders);
}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;

  $self->clean_up_record_subfolders();

  return;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::CleanUpEmailSubfolders - Background job for removing all email
subfolders except open records.

=head1 SYNOPSIS

This background job syncs all emails in subfolders and adds emails files to the
corresponding record. After that is removes all subfolders except for open
records.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
