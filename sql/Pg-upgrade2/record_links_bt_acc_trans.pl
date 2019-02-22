# @tag: record_links_bt_acc_trans
# @description: RecordLinks von bt nach acc_trans
# @depends: release_3_5_3
package SL::DBUpgrade2::record_links_bt_acc_trans;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;
use SL::RecordLinks;


sub run {
  my ($self) = @_;

  my $query_table =
    qq|

      CREATE SEQUENCE bank_transaction_acc_trans_id_seq;
      CREATE TABLE bank_transaction_acc_trans (
        id                      integer NOT NULL DEFAULT nextval('bank_transaction_acc_trans_id_seq'),
        bank_transaction_id     integer NOT NULL,
        acc_trans_id            bigint  NOT NULL,
        ar_id                   integer,
        ap_id                   integer,
        gl_id                   integer,
        itime                   TIMESTAMP      DEFAULT now(),
        mtime                   TIMESTAMP,
        PRIMARY KEY (bank_transaction_id, acc_trans_id),
        FOREIGN KEY (bank_transaction_id)      REFERENCES bank_transactions (id),
        FOREIGN KEY (acc_trans_id)             REFERENCES acc_trans (acc_trans_id),
        FOREIGN KEY (ar_id)                    REFERENCES ar (id),
        FOREIGN KEY (ap_id)                    REFERENCES ap (id),
        FOREIGN KEY (gl_id)                    REFERENCES gl (id));|;

  $self->db_query($query_table);


  my $query = qq|SELECT to_id, itime, from_id, to_table
                 FROM record_links
                 WHERE from_table='bank_transactions'|;

  my $sth = $self->dbh->prepare($query);

  my $sql       = <<SQL;
    SELECT
     acc_trans_id
    FROM acc_trans
    WHERE trans_id = ?
    AND itime = ?
    AND (chart_link='AR' OR chart_link='AP' OR chart_link ilike '%paid%');
SQL

  my $sth_acc_trans_ids = $self->dbh->prepare($sql) or die $self->dbh->errstr;

  my $sql_insert       = <<SQL;
  INSERT INTO bank_transaction_acc_trans (bank_transaction_id, acc_trans_id, ar_id, ap_id, gl_id)
  VALUES ( ?, ?, ?, ?, ?);
SQL

  my $sth_insert = $self->dbh->prepare($sql_insert) or die $self->dbh->errstr;


  # get all current record links from bank to arap
  $sth->execute() or die $self->dbh->errstr;

  while (my $rl_ref = $sth->fetchrow_hashref("NAME_lc")) {

    # get all concurrent acc_trans entries (payment) for this transaction
    $sth_acc_trans_ids->execute($rl_ref->{to_id}, $rl_ref->{itime}) or die $self->dbh->errstr;
    while (my $ac_ref = $sth_acc_trans_ids->fetchrow_hashref("NAME_lc")) {
      my $ar_id = $rl_ref->{to_table} eq 'ar' ? $rl_ref->{to_id} : undef;
      my $ap_id = $rl_ref->{to_table} eq 'ap' ? $rl_ref->{to_id} : undef;
      my $gl_id = $rl_ref->{to_table} eq 'gl' ? $rl_ref->{to_id} : undef;
      $sth_insert->execute($rl_ref->{from_id},$ac_ref->{acc_trans_id},
                           $ar_id, $ap_id, $gl_id) or die $self->dbh->errstr;
    }
  }
  return 1;
}

1;
