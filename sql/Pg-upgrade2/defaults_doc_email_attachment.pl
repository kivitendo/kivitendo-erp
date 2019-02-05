# @tag: defaults_doc_email_attachment
# @description: Einstellen der Haken für Anhänge beim Belegversand für E-Mails (Standard alle angehakt)
# @depends: release_3_5_3
package SL::DBUpgrade2::defaults_doc_email_attachment;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN email_attachment_vc_files_checked boolean DEFAULT true|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN email_attachment_part_files_checked boolean DEFAULT true|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN email_attachment_record_files_checked boolean DEFAULT true|);
  return 1;
}

1;
