package SL::Presenter::RequirementSpec;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(requirement_spec);

use Carp;

sub requirement_spec {
  my ($requirement_spec, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=RequirementSpec/show&amp;id=' . escape($requirement_spec->id) . '">',
    escape($requirement_spec->id),
    $params{no_link} ? '' : '</a>',
  );

  is_escaped($text);
}

1;
