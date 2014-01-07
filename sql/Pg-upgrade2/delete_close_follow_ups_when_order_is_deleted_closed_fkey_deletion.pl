# @tag: delete_close_follow_ups_when_order_is_deleted_closed_fkey_deletion
# @description: Wiedervorlagen löschen/schließen, wenn dazugehörige Belege gelöscht/geschlossen werden Teil 1: Fremdschlüssel löschen
# @depends: release_3_0_0
package SL::DBUpgrade2::delete_close_follow_ups_when_order_is_deleted_closed_fkey_deletion;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->drop_constraints(table => "follow_up_links");

  return 1;
}

1;
