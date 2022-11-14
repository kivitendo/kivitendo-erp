package SL::Presenter::RequirementSpec;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(requirement_spec);

use Carp;

sub requirement_spec {
  my ($requirement_spec, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($requirement_spec->id);
  if (! delete $params{no_link}) {
    my $href = 'controller.pl?action=RequirementSpec/show'
               . '&id=' . escape($requirement_spec->id);
    $text = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

1;
