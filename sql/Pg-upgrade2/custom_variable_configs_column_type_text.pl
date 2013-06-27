# @tag: custom_variable_configs_column_type_text
# @description: Spaltentypen in 'custom_varialbe_configs' anpassen & schärfere Restriktionen
# @depends: release_3_0_0
package SL::DBUpgrade2::custom_variable_configs_column_type_text;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  # Fix 'sortkey' column to not contain NULLs
  my $q_update = qq|UPDATE custom_variable_configs SET sortkey = ? WHERE id = ?|;
  my $h_update = $self->dbh->prepare($q_update) || die $self->dbh->errstr;

  my $q_select = <<SQL;
    SELECT id, module
    FROM custom_variable_configs
    ORDER BY module ASC, sortkey ASC NULLS LAST, id ASC
SQL

  my $previous_module = '';
  my $sortkey         = 0;
  foreach my $entry (@{ $self->dbh->selectall_arrayref($q_select) }) {
    $sortkey         = $previous_module eq $entry->[1] ? $sortkey + 1 : 1;
    $previous_module = $entry->[1];

    $h_update->execute($sortkey, $entry->[0]) || die $self->dbh->errstr;
  }

  $h_update->finish;

  # Apply structure upgrade
  my @statements = (
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN type   TYPE TEXT|,
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN module TYPE TEXT|,

    qq|UPDATE custom_variable_configs SET searchable          = FALSE WHERE searchable          IS NULL|,
    qq|UPDATE custom_variable_configs SET includeable         = FALSE WHERE includeable         IS NULL|,
    qq|UPDATE custom_variable_configs SET included_by_default = FALSE WHERE included_by_default IS NULL|,

    qq|ALTER TABLE custom_variable_configs ALTER COLUMN searchable          SET NOT NULL|,
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN includeable         SET NOT NULL|,
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN included_by_default SET NOT NULL|,
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN name                SET NOT NULL|,
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN description         SET NOT NULL|,
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN type                SET NOT NULL|,
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN module              SET NOT NULL|,
    qq|ALTER TABLE custom_variable_configs ALTER COLUMN sortkey             SET NOT NULL|,

    qq|ALTER TABLE custom_variable_configs
       ADD CONSTRAINT custom_variable_configs_name_description_type_module_not_empty
       CHECK (    type        <> ''
              AND module      <> ''
              AND name        <> ''
              AND description <> '')|,

    qq|ALTER TABLE custom_variable_configs
       ADD CONSTRAINT custom_variable_configs_options_not_empty_for_select
       CHECK ((type <> 'select') OR (COALESCE(options, '') <> ''))|,
  );

  $self->db_query($_) for @statements;

  return 1;
}

1;
