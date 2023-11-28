package SL::DB::EmailJournalAttachment;

use strict;

use SL::DB::MetaSetup::EmailJournalAttachment;
use SL::DB::Manager::EmailJournalAttachment;
use SL::DB::Helper::ActsAsList (group_by => [ qw(email_journal_id) ]);

use SL::Webdav;
use SL::File;

__PACKAGE__->meta->initialize;

sub add_file_to_record {
  my ($self, $record) = @_;

  # copy file to webdav folder
  if ($::instance_conf->get_webdav_documents) {
    my $record_type = $record->record_type;
    # TODO: file and webdav use different types
    $record_type = 'accounts_payable' if $record_type eq 'ap_transaction';
    $record_type = 'general_ledger'   if $record_type eq 'ar_transaction';
    $record_type = 'general_ledger'   if $record_type eq 'gl_transaction';
    $record_type = 'invoice'          if $record_type eq 'invoice_storno';
    $record_type = 'purchase_invoice' if $record_type eq 'purchase_credit_note';
    my $webdav = SL::Webdav->new(
      type     => $record_type,
      number   => $record->record_number,
    );
    my $webdav_file = SL::Webdav::File->new(
      webdav => $webdav,
      filename => $self->name,
    );
    eval {
      $webdav_file->store(data => \$self->content);
      1;
    } or do {
      die 'Storing the attachment file to the WebDAV folder failed: ' . $@;
    };
  }
  # copy file to doc storage
  if ($::instance_conf->get_doc_storage) {
    my $record_type = $record->record_type;
    # TODO: file and webdav use different types
    $record_type = 'purchase_invoice' if $record_type eq 'ap_transaction';
    $record_type = 'purchase_invoice' if $record_type eq 'purchase_credit_note';
    $record_type = 'invoice'          if $record_type eq 'ar_transaction';
    $record_type = 'invoice'          if $record_type eq 'invoice_storno';
    eval {
      SL::File->save(
        object_id     => $record->id,
        object_type   => $record_type,
        source        => 'uploaded',
        file_type     => 'document',
        file_name     => $self->name,
        file_contents => $self->content,
        mime_type     => $self->mime_type,
      );
      1;
    } or do {
      die 'Storing the attachment file to the file management failed: ' . $@;
    };
  }

}

1;
