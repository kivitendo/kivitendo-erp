package SL::Presenter::Reclamation;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(html_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(sales_reclamation purchase_reclamation);

use Carp;

sub sales_reclamation {
  my ($reclamation, %params) = @_;

  return _reclamation_record($reclamation, 'sales_reclamation', %params);
}

sub purchase_reclamation {
  my ($reclamation, %params) = @_;

  return _reclamation_record($reclamation, 'purchase_reclamation', %params);
}

sub _reclamation_record {
  my ($reclamation, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($reclamation->record_number);
  unless ($params{no_link}) {
    my $id = $reclamation->id;
    $text =  html_tag('a', $text, href => escape("controller.pl?action=Reclamation/edit&type=${type}&id=${id}"));
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
  my $html   = SL::Presenter::Reclamation::sales_reclamation(
    $object, display => 'inline'
  );

  # Purchase reclamations:
  my $object = SL::DB::Manager::Reclamation->get_first(
    where => [ SL::DB::Manager::Reclamation->type_filter('purchase_reclamation') ]
  );
  my $html   = SL::Presenter::Reclamation::purchase_reclamation(
    $object, display => 'inline'
  );

=head1 FUNCTIONS

=over 4

=item C<sales_reclamation $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the sales reclamation object C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the objects's
reclamation number linked to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the  reclamation number will be linked to the
"edit reclamation" dialog from the sales menu.

=back

=item C<purchase_reclamation $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the purchase reclamation object C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the objects's reclamation number
linked to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the  reclamation number will be linked to the
"edit reclamation" dialog from the purchase menu.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
