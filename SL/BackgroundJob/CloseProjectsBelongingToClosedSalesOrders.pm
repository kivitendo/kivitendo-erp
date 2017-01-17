package SL::BackgroundJob::CloseProjectsBelongingToClosedSalesOrders;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::Project;
use SL::DB::ProjectStatus;

sub run {
  my ($self, $db_obj)     = @_;

  my $data                = $db_obj->data_as_hash;
  $data->{new_status}   ||= 'done';
  $data->{set_inactive}   = 1 if !exists $data->{set_inactive};

  my $new_status          = SL::DB::Manager::ProjectStatus->find_by(name => $data->{new_status}) || die "No project status named '$data->{new_status}' found!";

  my %attributes          = (project_status_id => $new_status->id);
  $attributes{active}     = 0 if $data->{set_inactive};

  my $sql                 = <<EOSQL;
    id IN (
      SELECT oe.globalproject_id
      FROM oe
      WHERE (oe.globalproject_id IS NOT NULL)
        AND (oe.customer_id      IS NOT NULL)
        AND NOT COALESCE(oe.quotation, FALSE)
        AND     COALESCE(oe.closed,    FALSE)
    )
EOSQL

  SL::DB::Manager::Project->update_all(
    set   => \%attributes,
    where => [
      '!project_status_id' => $new_status->id,
      \$sql,
    ],
  );

  return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::CloseProjectsBelongingToClosedSalesOrders —
Background job for closing all projects which are linked to a closed
sales order (via C<oe.globalproject_id>)

=head1 SYNOPSIS

This background job searches all closed sales orders for linked
projects. Those projects whose status is not C<done> will be modified:
their status will be set to C<done> and their C<active> flag will be
set to C<false>.

Both of these can be configured via the job's data hash: C<new_status>
is the new status' name (defaults to C<done>), and C<set_inactive>
determines whether or not the project will be set to inactive
(defaults to 1).

The job is deactivated by default. Administrators of installations
where such a feature is wanted have to create a job entry manually.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
