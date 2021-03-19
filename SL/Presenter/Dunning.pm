package SL::Presenter::Dunning;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(dunning);

use Carp;

sub dunning {
  my ($dunning, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($dunning->dunning_config->dunning_description);

  if (! delete $params{no_link}) {
    my $href = 'dn.pl?action=show_dunning&showold=1&dunning_id=' . $dunning->dunning_id;
    $text    = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

1;
