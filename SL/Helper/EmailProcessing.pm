package SL::Helper::EmailProcessing;

use strict;
use warnings;

use Carp;

use XML::LibXML;

use SL::ZUGFeRD;
use SL::Locale::String qw(t8);

use SL::DB::PurchaseInvoice;

sub process_attachments {
  my ($self, $function_name, $email_journal, %params) = @_;

  my $full_function_name = "process_attachments_$function_name";
  unless ($self->can($full_function_name)) {
    croak "Function not implemented for: $function_name";
  }

  my @processed_files;
  my @errors;
  foreach my $attachment (@{$email_journal->attachments_sorted}) {
    my $attachment_name = $attachment->name;
    my $error = $self->$full_function_name($email_journal, $attachment, %params);
    if ($error) {
      push @errors, "$attachment_name: $error.";
    } else {
      push @processed_files, $attachment_name;
    }
  }
  my $extended_status = t8("Processed attachments with function '#1':", $function_name);
  if (scalar @processed_files) {
    $extended_status .= "\n" . t8("Processed successfully: ")
      . join(', ', @processed_files);
  }
  if (scalar @errors) {
    $extended_status .= "\n" . t8("Errors while processing: ")
      . "\n" . join("\n", @errors);
  }
  unless (scalar @processed_files || scalar @errors) {
    $extended_status .= "\n" . t8("No attachments.");
  }
  $email_journal->extended_status(
    join "\n", $email_journal->extended_status, $extended_status
  );
  $email_journal->save;
  return scalar @processed_files;
}

sub can_function {
  my ($self, $function_name) = @_;
  $self->can("process_attachments_$function_name")
}

sub process_attachments_zugferd {
  my ($self, $email_journal, $attachment, %params) = @_;

  my $content = $attachment->content; # scalar ref

  return t8("Not a PDF or XML file") unless $content =~ m/^%PDF|<\?xml/;

  my %res;
  if ( $content =~ m/^%PDF/ ) {
    %res = %{SL::ZUGFeRD->extract_from_pdf($content)};
  } else {
    %res = %{SL::ZUGFeRD->extract_from_xml($content)};
  }

  unless ($res{'result'} == SL::ZUGFeRD::RES_OK()) {
    # my $error = $res{'message'}; # technical error
    my $error = t8('No vaild Factur-X/ZUGFeRD file');
    return $error;
  }

  my $purchase_invoice;
  eval {
    $purchase_invoice = SL::DB::PurchaseInvoice->create_from_zugferd_data($res{invoice_xml})->save();
    1;
  } or do {
    my $error = $@;
    return $error;
  };

  $self->_add_attachment_to_record($email_journal, $attachment, $purchase_invoice);

  return 0;
}

sub _add_attachment_to_record {
  my ($self, $email_journal, $attachment, $record) = @_;

  $attachment->add_file_to_record($record);

  $email_journal->link_to_record($record);
}

1;


=encoding utf8

=head1 NAME

SL::Helper::EmailProcessing - Helper functions for processing email attachments

=head1 SYNOPSIS

This module provides helper functions for processing email attachments.

=head1 METHODS

=head2 process_attachments($function_name, $email_journal, %params)

Processes the attachments of an email journal. The function to be used for processing is determined by the first argument.

=head2 process_attachments_zugpferd($function_name, $email_journal, %params)

Processes the attachments of an email journal. If it is a Zugpferd Invoiue it creates the PurchaseInvoice and links it to the email_journal.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut

