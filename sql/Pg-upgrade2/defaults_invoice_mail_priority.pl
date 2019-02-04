# @tag: defaults_invoice_mail_priority
# @description: Einstellen der Priorität der generischen E-Mail für Rechnungen (Verkauf)
# @depends: release_3_5_3
package SL::DBUpgrade2::defaults_invoice_mail_priority;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|CREATE TYPE invoice_mail_settings AS ENUM ('cp', 'invoice_mail', 'invoice_mail_cc_cp');
                     ALTER TABLE defaults ADD COLUMN invoice_mail_settings invoice_mail_settings default 'cp'|);
  return 1;
}

1;
