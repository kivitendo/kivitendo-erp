package SL::Helper::EmailProcessing;

use strict;
use warnings;

use Carp;

use XML::LibXML;

use SL::ZUGFeRD;

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

sub can_function {
  my ($self, $function_name) = @_;
  $self->can("process_attachments_$function_name")
}

sub process_attachments_zugferd {
  my ($self, $email_journal, $attachment, %params) = @_;

  my $content = $attachment->content; # scalar ref
  my $name = $attachment->name;

  return 0 unless $content =~ m/^%PDF|<\?xml/;

  my %res;
  if ( $content =~ m/^%PDF/ ) {
    %res = %{SL::ZUGFeRD->extract_from_pdf($content)};
  } else {
    %res = %{SL::ZUGFeRD->extract_from_xml($content)};
  }

  unless ($res{'result'} == SL::ZUGFeRD::RES_OK()) {
    my $error = $res{'message'};
    $email_journal->extended_status(
      join "\n", $email_journal->extended_status,
      "Error processing ZUGFeRD attachment $name: $error"
    )->save;
    return 0;
  }

  my $purchase_invoice;
  eval {
    $purchase_invoice = SL::DB::PurchaseInvoice->create_from_zugferd_data(\%res)->save();
    1;
  } or do {
    my $error = $@;
    $email_journal->update_attributes(
      extended_status =>
        join "\n", $email_journal->extended_status,
        "Error processing ZUGFeRD attachment $name: $error"
    );
    return 0;
  };

  $self->_add_attachment_to_record($email_journal, $attachment, $purchase_invoice);

  return 1;
}

sub _add_attachment_to_record {
  my ($self, $email_journal, $attachment, $record) = @_;

  $attachment->add_file_to_record($record);

  $email_journal->link_to_record($record);
}

1;
