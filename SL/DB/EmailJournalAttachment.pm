package SL::DB::EmailJournalAttachment;

use strict;

use XML::LibXML;

use SL::ZUGFeRD;

use SL::DB::PurchaseInvoice;
use SL::DB::MetaSetup::EmailJournalAttachment;
use SL::DB::Manager::EmailJournalAttachment;
use SL::DB::Helper::ActsAsList (group_by => [ qw(email_journal_id) ]);

__PACKAGE__->meta->initialize;

sub create_ap_invoice {
  my ($self) = @_;

  my $content = $self->content; # scalar ref

  return unless $content =~ m/^%PDF/;

  my $zugferd_info = SL::ZUGFeRD->extract_from_pdf($content);
  return unless $zugferd_info->{result} == SL::ZUGFeRD::RES_OK();

  my $zugferd_xml = XML::LibXML->load_xml(string => $zugferd_info->{invoice_xml});

  return SL::DB::PurchaseInvoice->create_from_zugferd_xml($zugferd_xml)->save();
}

1;
