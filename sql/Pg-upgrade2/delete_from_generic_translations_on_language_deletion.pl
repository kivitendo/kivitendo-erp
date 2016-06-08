# @tag: delete_from_generic_translations_on_language_deletion
# @description: Übersetzungen automatisch löschen, wenn die dazugehörige Sprache gelöscht wird
# @depends: release_3_4_0
package SL::DBUpgrade2::delete_from_generic_translations_on_language_deletion;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->drop_constraints(table => 'generic_translations');

  $self->db_query(<<SQL);
    ALTER TABLE generic_translations
    ADD CONSTRAINT generic_translations_language_id_fkey
      FOREIGN KEY (language_id)
      REFERENCES language (id)
      ON DELETE CASCADE
SQL

  $self->db_query(<<SQL);
    DELETE FROM generic_translations
    WHERE language_id NOT IN (
      SELECT id
      FROM language
    )
SQL

  return 1;
}

1;
