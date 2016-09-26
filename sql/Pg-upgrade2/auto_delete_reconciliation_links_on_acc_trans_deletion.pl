# @tag: auto_delete_reconciliation_links_on_acc_trans_deletion
# @description: Automatisch Einträge aus reconciliation_links entfernen, wenn referenzierte Einträge gelöscht werden
# @depends: automatic_reconciliation
package SL::DBUpgrade2::auto_delete_reconciliation_links_on_acc_trans_deletion;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->drop_constraints(table => $_) for qw(reconciliation_links);

  my @queries = (
    q|ALTER TABLE reconciliation_links ADD CONSTRAINT reconciliation_links_acc_trans_id_fkey   FOREIGN KEY (acc_trans_id)        REFERENCES acc_trans         (acc_trans_id) ON DELETE CASCADE|,
    q|ALTER TABLE reconciliation_links ADD CONSTRAINT reconciliation_links_bank_transaction_id FOREIGN KEY (bank_transaction_id) REFERENCES bank_transactions (id)           ON DELETE CASCADE|,
  );

  $self->db_query($_) for @queries;

  return 1;
}

1;
