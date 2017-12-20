# @tag: oe_ar_ap_delivery_orders_edit_notes_as_html
# @description: Einkaufs- und Verkaufsbelege: Bemerkungsfeld in HTML umwandeln
# @depends: requirement_spec_edit_html
package SL::DBUpgrade2::oe_ar_ap_delivery_orders_edit_notes_as_html;

use strict;
use utf8;

use SL::DBUtils;
use SL::Presenter::EscapedText qw(escape);

use parent qw(SL::DBUpgrade2::Base);

sub convert_column {
  my ($self, $table, $column) = @_;

  my $sth = $self->dbh->prepare(qq|UPDATE $table SET $column = ? WHERE id = ?|) || $self->dberror;

  foreach my $row (selectall_hashref_query($::form, $self->dbh, qq|SELECT id, $column FROM $table WHERE $column IS NOT NULL|)) {
    next if !$row->{$column} || (($row->{$column} =~ m{^<[a-z]+>}) && ($row->{$column} =~ m{</[a-z]+>$}));

    my $new_content = "" . escape($row->{$column});
    $new_content    =~ s{\r}{}g;
    $new_content    =~ s{\n\n+}{</p><p>}g;
    $new_content    =~ s{\n}{<br />}g;
    $new_content    =  "<p>${new_content}</p>" if $new_content;

    $sth->execute($new_content, $row->{id}) if $new_content ne $row->{$column};
  }

  $sth->finish;
}

sub run {
  my ($self) = @_;

  $self->convert_column($_, 'notes') for qw(oe delivery_orders ar ap);

  return 1;
}

1;
