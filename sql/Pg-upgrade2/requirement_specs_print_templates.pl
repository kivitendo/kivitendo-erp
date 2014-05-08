# @tag: requirement_specs_print_templates
# @description: requirement_specs_print_templates
# @depends: requirement_specs clients
package SL::DBUpgrade2::requirement_specs_print_templates;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->add_print_templates(
    'templates/print/Standard',
    qw(images/draft.png images/hintergrund_seite1.png images/hintergrund_seite2.png images/schachfiguren.jpg kivitendo.sty requirement_spec.tex)
  );

  return 1;
}

1;
