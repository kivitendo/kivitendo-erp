package SL::Presenter::Reclamation;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(show sales_reclamation purchase_reclamation);

use Carp;

sub show {goto &reclamation};

sub sales_reclamation {goto &reclamation}
sub purchase_reclamation {goto &reclamation}

sub reclamation {
  my ($reclamation, %params) = @_;

  $params{display} ||= 'inline';

  my $text = escape($reclamation->record_number);
  unless ($params{no_link}) {
    my $href = 'controller.pl?action=Reclamation/edit&id=' . escape($reclamation->id);
    $text =  link_tag($href, $text, %params);
  }

  is_escaped($text);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Reclamation - Presenter module for Rose::DB objects for sales
reclamations and purchase reclamations

=head1 SYNOPSIS

  # Sales reclamations:
  my $object = SL::DB::Manager::Reclamation->get_first(
    where => [ SL::DB::Manager::Reclamation->type_filter('sales_reclamation') ]
  );
  my $html   = SL::Presenter::Reclamation::sales_reclamation($object);

  # Purchase reclamations:
  my $object = SL::DB::Manager::Reclamation->get_first(
    where => [ SL::DB::Manager::Reclamation->type_filter('purchase_reclamation') ]
  );
  my $html   = SL::Presenter::Reclamation::purchase_reclamation($object);

  # or for all types:
  my $html   = SL::Presenter::Reclamation::reclamation(
    $object, display => 'inline'
  );
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object %params>

Alias for C<reclamation $object %params>.

=item C<sales_reclamation $object, %params>

Alias for C<reclamation $object %params>.

=item C<purchase_reclamation $object, %params>

Alias for C<reclamation $object %params>.

=item C<reclamation $object %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the sales reclamation object C<$object>.

C<%params> can include:

=over 2

=item * no_link

If falsish (the default) then the  reclamation number will be linked to the
"edit reclamation" dialog.

=back

When C<$params{no_link}> is falsish, other C<%params> get passed to
L<SL::Presenter::Tag/link_tag> .

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
