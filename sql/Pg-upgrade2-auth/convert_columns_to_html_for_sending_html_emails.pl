# @tag: convert_columns_to_html_for_sending_html_emails
# @description: Versand von E-Mails in HTML: mehrere Text-Spalten nach HTML umwandeln
# @depends: release_3_5_8
package SL::DBUpgrade2::Auth::convert_columns_to_html_for_sending_html_emails;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::HTML::Util;

sub run {
  my ($self) = @_;

  my $q_fetch = <<SQL;
    SELECT user_id, cfg_key, cfg_value
    FROM auth.user_config
    WHERE (cfg_key = 'signature')
SQL

  my $q_update = <<SQL;
    UPDATE auth.user_config
    SET cfg_value = ?
    WHERE (user_id = ?)
      AND (cfg_key = 'signature')
SQL

  my $h_fetch = $self->dbh->prepare($q_fetch);
  $h_fetch->execute || $::form->dberror($q_fetch);

  my $h_update = $self->dbh->prepare($q_update);

  while (my $entry = $h_fetch->fetchrow_hashref) {
    $entry->{cfg_value} //= '';
    my $new_value = SL::HTML::Util->plain_text_to_html($entry->{cfg_value});

    next if $entry->{cfg_value} eq $new_value;

    $h_update->execute($new_value, $entry->{user_id}) || $::form->dberror($q_update);
  }

  return 1;
}

1;
