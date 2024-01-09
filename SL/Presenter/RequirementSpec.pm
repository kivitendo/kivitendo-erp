package SL::Presenter::RequirementSpec;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(show requirement_spec);

use Carp;

sub show {goto &requirement_spec};

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

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::RequirementSpec - Presenter module for SL::DB::RequirementSpec objects

=head1 SYNOPSIS

  my $object = SL::DB::Manager::RequirementSpec->get_first();
  my $html   = SL::Presenter::RequirementSpec::requirement_spec($object);
  # or
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object>

Alias for C<requirement_spec $object %params>.

=item C<requirement_spec $object %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the bank transaction object
C<$object>. C<%params> gets passed to L<SL::Presenter::Tag/link_tag>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
