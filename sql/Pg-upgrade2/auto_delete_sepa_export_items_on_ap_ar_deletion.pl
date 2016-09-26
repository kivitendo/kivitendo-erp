# @tag: auto_delete_sepa_export_items_on_ap_ar_deletion
# @description: Automatisch Einträge aus reconciliation_links entfernen, wenn referenzierte Einträge gelöscht werden
# @depends: sepa_in
package SL::DBUpgrade2::auto_delete_sepa_export_items_on_ap_ar_deletion;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->drop_constraints(table => $_) for qw(sepa_export_items);

  my @queries = (
    q|ALTER TABLE sepa_export_items ADD CONSTRAINT sepa_export_items_ar_id_fkey FOREIGN KEY (ar_id) REFERENCES ar (id) ON DELETE CASCADE|,
    q|ALTER TABLE sepa_export_items ADD CONSTRAINT sepa_export_items_ap_id_fkey FOREIGN KEY (ap_id) REFERENCES ap (id) ON DELETE CASCADE|,
  );

  $self->db_query($_) for @queries;

  return 1;
}

1;
