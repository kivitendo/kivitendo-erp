package SL::Presenter::SepaExportItem;

use strict;
use utf8;

use SL::Locale::String qw(t8);
use SL::Presenter::EscapedText qw(escape);

use Exporter qw(import);
our @EXPORT_OK = qw(show sepa_export_item);

use Carp;

sub show {goto &sepa_export_item};

sub sepa_export_item {
  my ($sepa_export_item) = @_;

  my ($title, $source, $destination) = $sepa_export_item->ap_id ?
      (t8('Bank transfer via SEPA'), 'our', 'vc')
    : (t8('Bank collections via SEPA'), 'vc', 'our')
  ;

  my $source_bic       = "${source}_bic";
  my $source_iban      = "${source}_iban";
  my $destination_bic  = "${destination}_bic";
  my $destination_iban = "${destination}_iban";

  escape(join ' ', (
     $title,
     $sepa_export_item->sepa_export_id . ":",
     t8('Execution date'), $sepa_export_item->execution_date,
     "-",
     t8('Export date'), $sepa_export_item->sepa_export->itime->to_kivitendo,
     "-",
     $sepa_export_item->$source_bic,
     $sepa_export_item->$source_iban,
     "→",
     $sepa_export_item->$destination_bic,
     $sepa_export_item->$destination_iban,
     "-",
     t8('Amount'), $sepa_export_item->amount,
  ));
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::SepaExportItem - Presenter module for SL::DB::SepaExportItem objects

=head1 SYNOPSIS

  my $object = SL::DB::Manager::SepaExportItem->get_first();
  my $html   = SL::Presenter::SepaExportItem::sepa_export_item($object);
  # or
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object>

Alias for C<sepa_export_item $object>.

=item C<sepa_export_item $object>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the sepa export item object
C<$object>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
