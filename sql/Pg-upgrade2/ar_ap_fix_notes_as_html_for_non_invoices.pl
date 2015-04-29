# @tag: ar_ap_fix_notes_as_html_for_non_invoices
# @description: Kreditoren-/Debitorenbuchungen: Bemerkungsfeld darf kein HTML sein
# @depends: oe_ar_ap_delivery_orders_edit_notes_as_html
package SL::DBUpgrade2::ar_ap_fix_notes_as_html_for_non_invoices;

use strict;
use utf8;

use SL::DBUtils;

use parent qw(SL::DBUpgrade2::Base);

sub fix_column {
  my ($self, $table) = @_;

  my $sth = $self->dbh->prepare(qq|UPDATE $table SET notes = ? WHERE id = ?|) || $self->dberror;

  my $query = <<SQL;
    SELECT id, notes
    FROM $table
    WHERE (notes IS NOT NULL)
      AND (NOT COALESCE(invoice, FALSE))
      AND (itime < (
        SELECT itime
        FROM schema_info
        WHERE tag = 'oe_ar_ap_delivery_orders_edit_notes_as_html'))
SQL

  foreach my $row (selectall_hashref_query($::form, $self->dbh, $query)) {
    next if !$row->{notes} || (($row->{notes} !~ m{^<[a-z]+>}) && ($row->{notes} !~ m{</[a-z]+>$}));

    my $new_content =  $row->{notes};
    $new_content    =~ s{^<p>|</p>$}{}gi;
    $new_content    =~ s{<br */>}{\n}gi;
    $new_content    =~ s{</p><p>}{\n\n}gi;
    $new_content    =  $::locale->unquote_special_chars('html', $new_content);

    $sth->execute($new_content, $row->{id}) if $new_content ne $row->{notes};
  }

  $sth->finish;
}

sub run {
  my ($self) = @_;

  $self->fix_column($_) for qw(ar ap);

  return 1;
}

1;
