package SL::Presenter::RequirementSpec;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(requirement_spec);

use Carp;

sub requirement_spec {
  my ($self, $requirement_spec, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=RequirementSpec/show&amp;id=' . $self->escape($requirement_spec->id) . '">',
    $self->escape($requirement_spec->id),
    $params{no_link} ? '' : '</a>',
  );
  return $self->escaped_text($text);
}

1;
