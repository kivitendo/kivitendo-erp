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

  my $output;
  if (delete $params{as_text}) {
    my $template = Template->new({ INTERPOLATE => 1,
                                   EVAL_PERL   => 0,
                                   ABSOLUTE    => 1,
                                   CACHE_SIZE  => 0,
                                   ENCODING    => 'utf8',
                                 });
    die "Could not create Template instance" if !$template;
    my $filename = File::Spec->catfile($::request->layout->webpages_path, qw(presenter items_list items_list.txt));
    $template->process($filename, {%params, items => $items}, \$output) || die $template->error;
    # Remove last newline because it can cause problems when rendering pdf.
    $output =~ s{\n$}{}x;

  } else {
    $output = SL::Presenter->get->render('presenter/items_list/items_list', %params, items => $items);
  }

  return $output;
}
