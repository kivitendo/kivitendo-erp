package SL::IMAPClient;

use strict;
use warnings;
use utf8;

use IO::Socket::INET;
use IO::Socket::SSL;
use Mail::IMAPClient;
use Email::MIME;
use File::MimeInfo::Magic;
use Encode qw(encode decode);
use Encode::IMAPUTF7;

use SL::SessionFile;
use SL::Locale::String qw(t8);
use SL::DB::EmailImport;
use SL::DB::EmailJournal;

my %TYPE_TO_FOLDER = (
  sales_quotation             => t8('Sales Quotations'),
  sales_order                 => t8('Sales Orders'),
);

sub new {
  my ($class, %params) = @_;
  my $config = $::lx_office_conf{imap_client} || {};
  my $self = bless {
    enabled     => $config->{enabled},
    hostname    => $config->{hostname},
    port        => $config->{port},
    ssl         => $config->{ssl},
    username    => $config->{username},
    password    => $config->{password},
    base_folder => $config->{base_folder} || 'INBOX',
    %params,
  }, $class;
  return unless $self->{enabled};
  $self->_create_imap_client();
  return $self;
}

sub DESTROY {
  my ($self) = @_;
  if ($self->{imap_client}) {
    $self->{imap_client}->logout();
  }
}

sub update_emails_from_folder {
  my ($self, $folder_path) = @_;

  my $folder_string = $self->get_folder_string_from_path($folder_path);

  $self->{imap_client}->select($folder_string)
    or die "Could not select IMAP folder '$folder_string': $@\n";

  my $msg_uids = $self->{imap_client}->messages
    or die "Could not messages via IMAP: $@\n";

  my $query = <<SQL;
    SELECT uid
    FROM email_imports ei
    LEFT JOIN email_journal ej
      ON ej.email_import_id = ei.id
    WHERE ei.host_name = ?
      AND ei.user_name = ?
      AND ej.folder = ?
SQL
  my $dbh = SL::DB->client->dbh;
  my $existing_uids = $dbh->selectall_hashref($query, 'uid', undef,
    $self->{hostname}, $self->{username}, $folder_path);

  my @new_msg_uids = grep { !$existing_uids->{$_} } @$msg_uids;

  return unless @new_msg_uids;

  SL::DB->client->with_transaction(sub {
    my $email_import = $self->_create_email_import($folder_path);
    $email_import->save(); # save to get id

    foreach my $new_uid (@new_msg_uids) {
      my $new_email_string = $self->{imap_client}->message_string($new_uid);
      my $email = Email::MIME->new($new_email_string);
      my $email_journal = $self->_create_email_journal(
        $email, $email_import, $new_uid, $folder_path
      );
      $email_journal->save();
    }
  });

  return;
}

sub _create_email_import {
  my ($self, $folder_path) = @_;
  my $email_import = SL::DB::EmailImport->new(
    host_name => $self->{hostname},
    user_name => $self->{username},
    folder    => $folder_path,
  );
  return $email_import;
}

sub _create_email_journal {
  my ($self, $email, $email_import, $uid, $folder_path) = @_;

  my @email_parts = $email->parts; # get parts or self
  my $text_part = $email_parts[0]; # TODO: check if its allways the first part
  my $body = $text_part->body;

  my $header_string = join "\r\n",
    (map { $_ . ': ' . $email->header($_) } $email->header_names);

  my $date = $self->_parse_date($email->header('Date'));

  my $recipients = $email->header('To');
  $recipients .= ', ' . $email->header('Cc') if ($email->header('Cc'));
  $recipients .= ', ' . $email->header('Bcc') if ($email->header('Bcc'));

  my @attachments = ();
  $email->walk_parts(sub {
    my ($part) = @_;
    my $filename = $part->filename;
    if ($filename) {
      my $content_type = $part->content_type;
      my $content = $part->body;
      my $attachment = SL::DB::EmailJournalAttachment->new(
        name      => $filename,
        content   => $content,
        mime_type => $content_type,
      );
      push @attachments, $attachment;
    }
  });

  my $email_journal = SL::DB::EmailJournal->new(
    email_import_id => $email_import->id,
    folder          => $folder_path,
    uid             => $uid,
    status          => 'imported',
    extended_status => '',
    from            => $email->header('From') || '',
    recipients      => $recipients,
    sent_on         => $date,
    subject         => $email->header('Subject') || '',
    body            => $body,
    headers         => $header_string,
    attachments     => \@attachments,
  );

  return $email_journal;
}

sub _parse_date {
  my ($self, $date) = @_;
  return '' unless $date;
  my $strp = DateTime::Format::Strptime->new(
    pattern   => '%a, %d %b %Y %H:%M:%S %z',
    time_zone => 'UTC',
  );
  my $dt = $strp->parse_datetime($date);
  return $dt->strftime('%Y-%m-%d %H:%M:%S');
}

sub update_emails_for_record {
  my ($self, $record) = @_;

  my $folder_string = $self->_get_folder_string_for_record($record);
  return unless $self->{imap_client}->exists($folder_string);
  $self->{imap_client}->select($folder_string)
    or die "Could not select IMAP folder '$folder_string': $@\n";

  my $msg_uids = $self->{imap_client}->messages
    or die "Could not messages via IMAP: $@\n";

  my $dbh = $record->dbh;
  my $query = <<SQL;
    SELECT uid
    FROM files
    WHERE object_id = ?
      AND object_type = ?
      AND source = 'uploaded'
      AND file_type = 'attachment'
SQL
  my $existing_uids = $dbh->selectall_hashref($query, 'uid', undef,
                                              $record->id, $record->type);
  my @new_msg_uids = grep { !$existing_uids->{$_} } @$msg_uids;

  foreach my $msg_uid (@new_msg_uids) {
    my $sess_fname = "mail_download_" . $record->type . "_" . $record->id . "_" . $msg_uid;

    my $file_name =
      decode('MIME-Header', $self->{imap_client}->subject($msg_uid)) . '.eml';
    my $sfile      = SL::SessionFile->new($sess_fname, mode => 'w');
    $self->{imap_client}->message_to_file($sfile->fh, $msg_uid)
      or die "Could not fetch message $msg_uid from IMAP: $@\n";
    $sfile->fh->close;

    my $mime_type = File::MimeInfo::Magic::magic($sfile->file_name);
    my $fileobj = SL::File->save(
      object_id        => $record->id,
      object_type      => $record->type,
      mime_type        => $mime_type,
      source           => 'uploaded',
      uid              => "$msg_uid",
      file_type        => 'attachment',
      file_name        => $file_name,
      file_path        => $sfile->file_name
    );
    unlink($sfile->file_name);
  }

}

sub create_folder {
  my ($self, $folder_name) = @_;
  return if $self->{imap_client}->exists($folder_name);
  $self->{imap_client}->create($folder_name)
    or die "Could not create IMAP folder '$folder_name': $@\n";
  return;
}

sub get_folder_string_from_path {
  my ($self, $folder_path) = @_;
  my $separator = $self->{imap_client}->separator();
  my $replace_sep = $separator eq '_' ? '-' : '_';
  $folder_path =~ s|\Q${separator}|$replace_sep|g; # \Q -> escape special chars
  $folder_path =~ s|/|${separator}|g; # replace / with separator
  my $folder_string = encode('IMAP-UTF-7', $folder_path);
  return $folder_string;
}

sub create_folder_for_record {
  my ($self, $record) = @_;
  my $folder_string = $self->_get_folder_string_for_record($record);
  $self->create_folder($folder_string);
  return;
}

sub _get_folder_string_for_record {
  my ($self, $record) = @_;

  my $customer_vendor = $record->customervendor;
  my $record_folder_path =
    $self->{base_folder} . '/' .
    $customer_vendor->number . ' ' . $customer_vendor->name . '/' .
    $TYPE_TO_FOLDER{$record->type} . '/' .
    $record->number;
  my $folder_string = $self->get_folder_string_from_path($record_folder_path);
  return $folder_string;
}

sub _create_imap_client {
  my ($self) = @_;

  my $socket;
  if ($self->{ssl}) {
    $socket = IO::Socket::SSL->new(
      Proto    => 'tcp',
      PeerAddr => $self->{hostname},
      PeerPort => $self->{port} || 993,
    );
  } else {
    $socket = IO::Socket::INET->new(
      Proto    => 'tcp',
      PeerAddr => $self->{hostname},
      PeerPort => $self->{port} || 143,
    );
  }
  if (!$socket) {
    die "Failed to create socket for IMAP client: $@\n";
  }

  my $imap_client = Mail::IMAPClient->new(
    Socket   => $socket,
    User     => $self->{username},
    Password => $self->{password},
    Uid      => 1,
    peek     => 1, # Don't change the \Seen flag
  ) or do {
    die "Failed to create IMAP Client: $@\n"
  };

  $imap_client->IsAuthenticated() or do {
    die "IMAP Client login failed: " . $imap_client->LastError() . "\n";
  };

  $self->{imap_client} = $imap_client;
  return $imap_client;
}

1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::IMAPClient - Base class for interacting with email server from kivitendo

=head1 SYNOPSIS

  use SL::IMAPClient;

  # uses the config in config/kivitendo.conf
  my $imap_client = SL::IMAPClient->new();

  # can also be used with a custom config, overriding the global config
  my %config = (
    enabled     => 1,
    hostname    => 'imap.example.com',
    username    => 'test_user',
    password    => 'test_password',
    ssl         => 1,
    base_folder => 'INBOX',
  );
  my $imap_client = SL::IMAPClient->new(%config);

  # create email folder for record
  # folder structure: base_folder/customer_vendor_number customer_vendor_name/type/record_number
  # e.g. INBOX/1234 Testkunde/Angebot/123
  # if the folder already exists, nothing happens
  $imap_client->create_folder_for_record($record);

  # update emails for record
  # fetches all emails from the IMAP server and saves them as attachments
  $imap_client->update_emails_for_record($record);

=head1 OVERVIEW

Mail can be sent from kivitendo via the sendmail command or the smtp protocol.


=head1 INTERNAL DATA TYPES

=over 2

=item C<%TYPE_TO_FOLDER>

  Due to the lack of a single global mapping for $record->type,
  type is mapped to the corresponding translation. All types which
  use this module are currently mapped and should be mapped.

=back

=head1 FUNCTIONS

=over 4

=item C<new>

  Creates a new SL::IMAPClient object. If no config is passed, the config
  from config/kivitendo.conf is used. If a config is passed, the global
  config is overridden.

=item C<DESTROY>

  Destructor. Disconnects from the IMAP server.

=item C<update_emails_for_record>

  Updates the emails for a record. Checks which emails are missing and
  fetches these from the IMAP server.

=item C<create_folder>

  Creates a folder on the IMAP server. If the folder already exists, nothing
  happens.

=item C<get_folder_string_from_path>

  Converts a folder path to a folder string. The folder path is like path
  on unix filesystem. The folder string is the path on the IMAP server.
  The folder string is encoded in IMAP-UTF-7.

=item C<create_folder_for_record>

  Creates a folder for a record on the IMAP server. The folder structure
  is like this: base_folder/customer_vendor_number customer_vendor_name/type/record_number
  e.g. INBOX/1234 Testkunde/Angebot/123
  If the folder already exists, nothing happens.

=item C<_get_folder_string_for_record>

  Returns the folder string for a record. The folder structure is like this:
  base_folder/customer_vendor_number customer_vendor_name/type/record_number
  e.g. INBOX/1234 Testkunde/Angebot/123. This is passed through
  C<get_folder_string_from_path>.

=item C<_create_imap_client>

  Creates a new IMAP client and logs in. The IMAP client is stored in
  $self->{imap_client}.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
