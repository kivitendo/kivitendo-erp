# @tag: clean_tax_18_19
# @description: Vorbereitung für neue Steuerschlüssel 18,19
# @depends: release_3_6_0 tax_reverse_charge
# @ignore: 0
package SL::DBUpgrade2::clean_tax_18_19;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub delete_alter_tax {
  my $self = shift;

  my $query = <<SQL;
    SELECT id from tax
    where taxkey = ?
    and reverse_charge_chart_id is null
SQL
  my $q_fetch = <<SQL;
    SELECT trans_id
    FROM acc_trans where tax_id = ?
    LIMIT 1
SQL

  my $delete_taxkey = <<SQL;
    DELETE from taxkeys where tax_id = ?
SQL

  my $delete_tax = <<SQL;
    DELETE from tax where         id = ?
SQL


  my $edit_tax = <<SQL;
    UPDATE tax set chart_id = NULL
    WHERE id = ?
SQL


  my $h_fetch   = $self->dbh->prepare($query);
  my $acc_fetch = $self->dbh->prepare($q_fetch);
  my $delete_tk = $self->dbh->prepare($delete_taxkey);
  my $delete_t  = $self->dbh->prepare($delete_tax);
  my $edit_q    = $self->dbh->prepare($edit_tax);


  my $tax_id;
  foreach ( qw(18 19) ) {
    $h_fetch->execute($_) || $::form->dberror($query);
    while (my $entry = $h_fetch->fetchrow_hashref) {
      $tax_id = $entry->{id};
      next unless $tax_id;
      $edit_q->execute($tax_id)    || $::form->dberror($edit_tax);
      $acc_fetch->execute($tax_id) || $::form->dberror($q_fetch);
      if (!$acc_fetch->fetchrow_hashref) {
        $delete_tk->execute($tax_id) || $::form->dberror($delete_tk);
        $delete_t ->execute($tax_id) || $::form->dberror($delete_t);
      }
    }
  }
}

sub run {
  my ($self) = @_;

  return 1 unless ($self->check_coa('Germany-DATEV-SKR03EU') ||$self->check_coa('Germany-DATEV-SKR04EU'));

  $self->delete_alter_tax;

  return 1;
}

1;
