# @tag: acc_trans_constraints
# @description: Fügt NOT-NULL-Constraints ein für die Spalten
# @depends:
package SL::DBUpgrade2::acc_trans_constraints;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my $query = qq|SELECT count(*) FROM acc_trans WHERE chart_id IS NULL|;
  my ($no_chart_id) = $self->dbh->selectrow_array($query);
  $query = qq|SELECT count(*) FROM acc_trans WHERE trans_id IS NULL|;
  my ($no_trans_id) = $self->dbh->selectrow_array($query);

  $::form->{no_chart_id}=$no_chart_id;
  $::form->{no_trans_id}=$no_trans_id;

  if ($no_chart_id > 0 or $no_trans_id > 0){
    #list all invalid transactions where only chart_id is null:
    $query = qq|SELECT acc.acc_trans_id,
                  acc.gldate,
                  acc.transdate,
                  ABS(acc.amount) AS amount,
                  acc.trans_id,
                  acc.source,
                  gl.reference,
                  gl.description,
                  gl.notes,
                  e.name,
                  e.login AS user,
                  p.projectnumber,
                  p.description AS projectdescription
                FROM acc_trans acc
                JOIN gl ON (gl.id=acc.trans_id)
                LEFT JOIN employee e ON (gl.employee_id=e.id)
                LEFT JOIN project p ON (p.id=acc.project_id)
                WHERE acc.chart_id IS NULL

                UNION

                SELECT acc.acc_trans_id,
                  acc.gldate,
                  acc.transdate,
                  ABS(acc.amount) AS amount,
                  acc.trans_id,
                  acc.source,
                  a.invnumber AS reference,
                  c.name AS description,
                  a.notes,
                  e.name,
                  e.login AS user,
                  p.projectnumber,
                  p.description AS projectdescription
                FROM acc_trans acc
                JOIN ar a ON (a.id=acc.trans_id)
                LEFT JOIN employee e ON (a.employee_id=e.id)
                LEFT JOIN customer c ON (a.customer_id=c.id)
                LEFT JOIN project p ON (p.id=acc.project_id)
                WHERE acc.chart_id IS NULL

                UNION

                SELECT acc.acc_trans_id,
                  acc.gldate,
                  acc.transdate,
                  ABS(acc.amount) AS amount,
                  acc.trans_id,
                  acc.source,
                  a.invnumber AS reference,
                  v.name AS description,
                  a.notes,
                  e.name,
                  e.login AS user,
                  p.projectnumber,
                  p.description AS projectdescription
                FROM acc_trans acc
                JOIN ap a ON (a.id=acc.trans_id)
                LEFT JOIN employee e ON (a.employee_id=e.id)
                LEFT JOIN vendor v ON (a.vendor_id=v.id)
                LEFT JOIN project p ON (p.id=acc.project_id)
                WHERE acc.chart_id IS NULL;|;

    my $sth = $self->dbh->prepare($query);
    $sth->execute || $::form->dberror($query);

    $::form->{NO_CHART_ID} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      push @{ $::form->{NO_CHART_ID} }, $ref;
    }
    $sth->finish;

    #List all invalid transactions where trans_id is null:
    $query = qq|SELECT acc.acc_trans_id,
                  acc.gldate,
                  acc.transdate,
                  ABS(acc.amount) AS amount,
                  acc.source,
                  c.accno,
                  c.description,
                  c.category,
                  p.projectnumber,
                  p.description AS projectdescription
                FROM acc_trans acc
                LEFT JOIN chart c ON (c.id=acc.chart_id)
                LEFT JOIN project p ON (p.id=acc.project_id)
                WHERE acc.trans_id IS NULL;|;

    $sth = $self->dbh->prepare($query);
    $sth->execute || $::form->dberror($query);

    $::form->{NO_TRANS_ID} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      $ref->{category} = ($ref->{category} eq 'A') ? $::locale->text('Account Category A')
        : ($ref->{category} eq 'E') ? $::locale->text('Account Category E')
        : ($ref->{category} eq 'L') ? $::locale->text('Account Category L')
        : ($ref->{category} eq 'I') ? $::locale->text('Account Category I')
        : ($ref->{category} eq 'Q') ? $::locale->text('Account Category Q')
        : ($ref->{category} eq 'C') ? $::locale->text('Account Category C')
        : ($ref->{category} eq 'G') ? $::locale->text('Account Category G')
        : $::locale->text('Unknown Category') . ': ' . $ref->{category};
      push @{ $::form->{NO_TRANS_ID} }, $ref;
    }
    $sth->finish;

    print_error_message();
    return 0;
  }

  $query = qq|ALTER TABLE acc_trans ALTER COLUMN chart_id SET NOT NULL;|;
  $query .= qq|ALTER TABLE acc_trans ALTER COLUMN trans_id SET NOT NULL;|;

  $self->db_query($query);
  return 1;
}

sub print_error_message {
  print $::form->parse_html_template("dbupgrade/acc_trans_constraints");
}

1;
