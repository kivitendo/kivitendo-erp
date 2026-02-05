package SL::Layout::Title;

use strict;
use parent qw(SL::Layout::Base);
use SL::Presenter::EscapedText qw(escape);

sub pre_content {
  my $title = escape($::locale->text($::form->{title} || ""));

  "<h1>${title}</h1>\n";
}

1;
