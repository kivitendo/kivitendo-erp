package SL::Presenter::ItemsList;

use strict;

use File::Spec;
use Template;

use SL::Presenter;
use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(items_list);

sub items_list {
  my ($items, %params) = @_;

  my $text_mode = !!delete $params{as_text};

  my $output = SL::Presenter->get->render('presenter/items_list/items_list', { type => $text_mode ? 'text' : 'html' }, %params, items => $items);

  $output =~ s{\n$}{}x if $text_mode;

  return $output;
}
