# @tag: phone_notes_convert_to_html
# @description: Telefonnotizen zu html konvertieren
# @depends: release_3_6_1
package SL::DBUpgrade2::phone_notes_convert_to_html;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::HTML::Util;

sub run {
  my ($self) = @_;

  my $q_fetch = <<SQL;
    SELECT id, body FROM notes WHERE trans_module LIKE 'oe'
SQL

  my $q_update_column = <<SQL;
    UPDATE notes SET body = ? WHERE id = ?
SQL

  my $h_fetch = $self->dbh->prepare($q_fetch);
  $h_fetch->execute || $::form->dberror($q_fetch);

  my $h_update_column = $self->dbh->prepare($q_update_column);

  while (my $entry = $h_fetch->fetchrow_hashref) {
    $entry->{body} //= '';
    my $html_value = SL::HTML::Util->plain_text_to_html($entry->{body});
    $h_update_column->execute($html_value, $entry->{id}) || $::form->dberror($q_update_column);
  }
  $h_update_column->finish;
  $h_fetch->finish;

  return 1;
}

1;
