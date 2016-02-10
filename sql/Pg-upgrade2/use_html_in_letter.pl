# @tag: use_html_in_letter
# @description: Briefe: HTML für Body nutzen können
# @depends: letter letter_draft
package SL::DBUpgrade2::use_html_in_letter;

use strict;
use utf8;

use SL::DBUtils;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->convert_column_to_html($_, 'body') for qw(letter letter_draft);

  return 1;
}

1;
