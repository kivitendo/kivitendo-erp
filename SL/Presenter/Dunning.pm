package SL::Presenter::Dunning;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(dunning);

use Carp;

sub dunning {
  my ($dunning, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $invoice = SL::DB::Manager::Invoice->find_by( id => $dunning->trans_id );

  my $text = join '', (
    $params{no_link} ? '' : '<a href="dn.pl?action=print_dunning&amp;format=pdf&amp;media=screen&amp;dunning_id=' . $dunning->dunning_id . '&amp;language_id=' . $invoice->language_id . '">',
    escape($dunning->dunning_config->dunning_description),
    $params{no_link} ? '' : '</a>',
  );

  is_escaped($text);
}

1;
