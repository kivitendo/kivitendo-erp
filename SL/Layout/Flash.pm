package SL::Layout::Flash;

use strict;
use parent qw(SL::Layout::Base);
use SL::Presenter::EscapedText qw(escape_js);
use SL::Helper::Flash;

sub pre_content {
  '<div style="position:relative"><div id="layout_flash_container"></div></div>'
}

sub javascripts_inline {
  my ($self) = @_;

  my $js = '';

  for (SL::Helper::Flash::flash_contents()) {
    next if $_->[3] + 60 < time(); # ignore entries from more than one minute ago
    $js .= defined $_->[2]
      ? sprintf("kivi.Flash.display_flash('%s', '%s', '%s');", map { escape_js($_) } @$_[0,1,2] )
      : sprintf("kivi.Flash.display_flash('%s', '%s');", map { escape_js($_) } @$_[0,1] );
  }

  $js;
}

sub static_javascripts {
  'kivi.Flash.js'
}


1;
