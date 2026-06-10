package SL::Layout::Title;

use strict;
use parent qw(SL::Layout::Base);
use SL::Presenter::EscapedText qw(escape);
use SL::Presenter::Tag qw(html_tag);

sub pre_content {
  my $title = escape($::locale->text($::form->{title} || ""));

  html_tag('h1', $title, id => 'title-headline', 'data-base-title' => $title)
}

1;
