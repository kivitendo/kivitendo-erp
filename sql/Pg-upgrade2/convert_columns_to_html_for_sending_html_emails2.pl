# @tag: convert_columns_to_html_for_sending_html_emails2
# @description: Versand von E-Mails in HTML: weitere Text-Spalten nach HTML umwandeln
# @depends: convert_columns_to_html_for_sending_html_emails
package SL::DBUpgrade2::convert_columns_to_html_for_sending_html_emails2;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::HTML::Util;

sub convert_column {
  my ($self, $table, $id_column, $column_to_convert, $condition) = @_;

  $condition = $condition ? "WHERE $condition" : "";

  my $q_fetch = <<SQL;
    SELECT ${id_column}, ${column_to_convert}
    FROM ${table}
    ${condition}
SQL

  my $q_update = <<SQL;
    UPDATE ${table}
    SET ${column_to_convert} = ?
    WHERE ${id_column} = ?
SQL

  my $h_fetch = $self->dbh->prepare($q_fetch);
  $h_fetch->execute || $::form->dberror($q_fetch);

  my $h_update = $self->dbh->prepare($q_update);

  while (my $entry = $h_fetch->fetchrow_hashref) {
    $entry->{$column_to_convert} //= '';
    my $new_value = SL::HTML::Util->plain_text_to_html($entry->{$column_to_convert});

    next if $entry->{$column_to_convert} eq $new_value;

    $h_update->execute($new_value, $entry->{id}) || $::form->dberror($q_update);
  }
}

sub run {
  my ($self) = @_;

  $self->convert_column('dunning_config', 'id', 'email_body');

  return 1;
}

1;
