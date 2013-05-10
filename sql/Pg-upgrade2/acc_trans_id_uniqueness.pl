# @tag: acc_trans_id_uniqueness
# @description: Sorgt dafür, dass acc_trans.acc_trans_id eindeutig ist
# @depends: release_2_6_1
package SL::DBUpgrade2::acc_trans_id_uniqueness;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $query = <<SQL;
    SELECT acc_trans_id, trans_id, itime, mtime
    FROM acc_trans
    WHERE acc_trans_id IN (
      SELECT acc_trans_id FROM acc_trans GROUP BY acc_trans_id HAVING COUNT(*) > 1
    )
    ORDER BY trans_id, itime, mtime NULLS FIRST
SQL

  my @entries = selectall_hashref_query($::form, $self->dbh, $query);

  return 1 unless @entries;

  $query = <<SQL;
    SELECT setval('acc_trans_id_seq', (
      SELECT COALESCE(MAX(acc_trans_id), 0) + 1
      FROM acc_trans
    ))
SQL

  $self->db_query($query);

  my %skipped_acc_trans_ids;
  foreach my $entry (@entries) {
    if (!$skipped_acc_trans_ids{ $entry->{acc_trans_id} }) {
      $skipped_acc_trans_ids{ $entry->{acc_trans_id} } = 1;
    } else {
      my $mtime = $entry->{mtime} ? "= '$entry->{mtime}'" : 'IS NULL';
      $query    = <<SQL;
        UPDATE acc_trans
        SET acc_trans_id = nextval('acc_trans_id_seq')
        WHERE (acc_trans_id = $entry->{acc_trans_id})
          AND (trans_id     = $entry->{trans_id})
          AND (itime        = '$entry->{itime}')
          AND (mtime $mtime)
SQL

      $self->db_query($query);
    }
  }

  return 1;
}

1;
