# @tag: requirement_spec_edit_html
# @description: Pflichtenhefte: diverse Text-Felder in HTML umwandeln
# @depends: requirement_spec_items_update_trigger_fix2 requirement_spec_items_update_trigger_fix requirement_specs_orders requirement_specs_section_templates requirement_specs
package SL::DBUpgrade2::requirement_spec_edit_html;

use strict;
use utf8;

use SL::DBUtils;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my %tables = (
    requirement_spec_predefined_texts => 'text',
    requirement_spec_text_blocks      => 'text',
    requirement_spec_items            => 'description',
    parts                             => 'notes',
    map({ ($_ => 'longdescription') } qw(translation orderitems invoice delivery_order_items)),
  );

  $self->convert_column_to_html($_, $tables{$_}) for keys %tables;

  return 1;
}

1;
