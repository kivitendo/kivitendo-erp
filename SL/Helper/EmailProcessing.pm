package SL::Helper::EmailProcessing;

use strict;
use warnings;

use Carp;

use XML::LibXML;

use SL::ZUGFeRD;
use SL::Webdav;
use SL::File;

use SL::DB::PurchaseInvoice;

sub process_attachments {
  my ($self, $function_name, $email_journal, %params) = @_;

  unless ($self->can("process_attachments_$function_name")) {
    croak "Function not implemented for: $function_name";
  }
  $function_name = "process_attachments_$function_name";

  my $processed_count = 0;
  foreach my $attachment (@{$email_journal->attachments_sorted}) {
    my $processed = $self->$function_name($email_journal, $attachment, %params);
    $processed_count += $processed;
  }
  return $processed_count;
}

sub process_attachments_zugferd {
  my ($self, $email_journal, $attachment, %params) = @_;

  my $content = $attachment->content; # scalar ref

  return 0 unless $content =~ m/^%PDF/;

  my $zugferd_info = SL::ZUGFeRD->extract_from_pdf($content);
  return 0 unless $zugferd_info->{result} == SL::ZUGFeRD::RES_OK();

  my $zugferd_xml = XML::LibXML->load_xml(string => $zugferd_info->{invoice_xml});

  my $purchase_invoice = SL::DB::PurchaseInvoice->create_from_zugferd_xml($zugferd_xml)->save();

  $self->_add_attachment_to_record($email_journal, $attachment, $purchase_invoice);

  return 1;
}

sub _add_attachment_to_record {
  my ($self, $email_journal, $attachment, $record) = @_;

  # link to email journal
  $email_journal->link_to_record($record);

  # copy file to webdav folder
  if ($::instance_conf->get_webdav_documents) {
    my $record_type = $record->record_type;
    # TODO: file and webdav use different types for ap_transaction
    $record_type = 'accounts_payable' if $record_type eq 'ap_transaction';
    my $webdav = SL::Webdav->new(
      type     => $record_type,
      number   => $record->record_number,
    );
    my $webdav_file = SL::Webdav::File->new(
      webdav => $webdav,
      filename => $attachment->name,
    );
    eval {
      $webdav_file->store(data => \$attachment->content);
      1;
    } or do {
      die 'Storing the attachment file to the WebDAV folder failed: ' . $@;
    };
  }
  # copy file to doc storage
  if ($::instance_conf->get_doc_storage) {
    my $record_type = $record->record_type;
    # TODO: file and webdav use different types for ap_invoice
    $record_type = 'purchase_invoice' if $record_type eq 'ap_transaction';
    eval {
      SL::File->save(
        object_id     => $record->id,
        object_type   => $record_type,
        source        => 'uploaded',
        file_type     => 'document',
        file_name     => $attachment->name,
        file_contents => $attachment->content,
        mime_type     => $attachment->mime_type,
      );
      1;
    } or do {
      die 'Storing the ZUGFeRD file in the storage backend failed: ' . $@;
    };
  }

  my $new_ext_status = join(' ', $email_journal->extended_status,
    'created_record_' . $record->record_type);
  $email_journal->update_attributes(extended_status => $new_ext_status);

  # TODO: hardlink in db to email_journal
}

1;
