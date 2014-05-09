# @tag: requirement_spec_edit_html
# @description: Pflichtenhefte: diverse Text-Felder in HTML umwandeln
# @depends: requirement_spec_items_update_trigger_fix2 requirement_spec_items_update_trigger_fix requirement_specs_orders requirement_specs_section_templates requirement_specs
package SL::DBUpgrade2::requirement_spec_edit_html;

use strict;
use utf8;

use SL::DBUtils;

use parent qw(SL::DBUpgrade2::Base);

sub convert_column {
  my ($self, $table, $column) = @_;

  my $sth = $self->dbh->prepare(qq|UPDATE $table SET $column = ? WHERE id = ?|) || $self->dberror;

  foreach my $row (selectall_hashref_query($::form, $self->dbh, qq|SELECT id, $column FROM $table WHERE $column IS NOT NULL|)) {
    next if !$row->{$column} || (($row->{$column} =~ m{^<[a-z]+>}) && ($row->{$column} =~ m{</[a-z]+>$}));

    my $new_content = "" . $::request->presenter->escape($row->{$column});
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

  my %tables = (
    requirement_spec_predefined_texts => 'text',
    requirement_spec_text_blocks      => 'text',
    requirement_spec_items            => 'description',
    parts                             => 'notes',
    map({ ($_ => 'longdescription') } qw(translation orderitems invoice delivery_order_items)),
  );

  $self->convert_column($_, $tables{$_}) for keys %tables;

  return 1;
}

1;
