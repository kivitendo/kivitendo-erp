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
use SL::Locale;

use SL::SessionFile;
use SL::Locale::String qw(t8);
use SL::DB::EmailImport;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;

use SL::DB::Order;

sub new {
  my ($class, %params) = @_;
  my $config = $::lx_office_conf{imap_client} || {};
  my $server_locale = Locale->new($::lx_office_conf{server}->{language});
  my %record_type_to_folder = (
    sales_quotation => $server_locale->text('Sales Quotations'),
    sales_order     => $server_locale->text('Sales Orders'),
  );
  my %record_folder_to_type = reverse %record_type_to_folder;
  my $self = bless {
    enabled     => $config->{enabled},
    hostname    => $config->{hostname},
    port        => $config->{port},
    ssl         => $config->{ssl},
    username    => $config->{username},
    password    => $config->{password},
    base_folder => $config->{base_folder} || 'INBOX',
    record_type_to_folder => \%record_type_to_folder,
    record_folder_to_type => \%record_folder_to_type,
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

sub store_email_in_email_folder {
  my ($self, $email_string, $folder_path) = @_;
  $folder_path ||= $self->{base_folder};

  my $folder_string = $self->get_folder_string_from_path($folder_path);
  $self->{imap_client}->append_string($folder_string, $email_string)
    or die "Could not store email in folder '$folder_string': "
           . $self->{imap_client}->LastError() . "\n";
}

sub set_flag_for_email {
  my ($self, $email_journal, $imap_flag) = @_;
  return unless $imap_flag;

  my $folder_string = $email_journal->folder;

  $self->{imap_client}->select($folder_string)
    or die "Could not select IMAP folder '$folder_string': $@\n";

  my $folder_uidvalidity = $self->{imap_client}->uidvalidity($folder_string)
    or die "Could not get UIDVALIDITY for folder '$folder_string': $@\n";

  if ($folder_uidvalidity != $email_journal->folder_uidvalidity) {
    die "Folder has changed: $folder_string\n"
  }

  my $uid = $email_journal->uid;
  $self->{imap_client}->set_flag($imap_flag, [$uid])
    or die "Could not add flag '$imap_flag' to message '$uid': "
           . $self->{imap_client}->LastError() . "\n";
}

sub update_emails_from_folder {
  my ($self, $folder_path, $params) = @_;
  $folder_path ||= $self->{base_folder};

  my $folder_string = $self->get_folder_string_from_path($folder_path);
  my $email_import =
    _update_emails_from_folder_strings($self, $folder_path, [$folder_string], $params);

  return $email_import;
}

sub update_emails_from_subfolders {
  my ($self, $base_folder_path, $params) = @_;
  $base_folder_path ||= $self->{base_folder};
  my $base_folder_string = $self->get_folder_string_from_path($base_folder_path);

  my @subfolder_strings = $self->{imap_client}->folders($base_folder_string)
    or die "Could not get subfolders via IMAP: $@\n";
  @subfolder_strings = grep { $_ ne $base_folder_string } @subfolder_strings;

  my $email_import =
    _update_emails_from_folder_strings($self, $base_folder_path, \@subfolder_strings, $params);

  return $email_import;
}

sub _update_emails_from_folder_strings {
  my ($self, $base_folder_path, $folder_strings, $params) = @_;

  my $dbh = SL::DB->client->dbh;

  my $email_import;
  SL::DB->client->with_transaction(sub {
    foreach my $folder_string (@$folder_strings) {
      $self->{imap_client}->select($folder_string)
        or die "Could not select IMAP folder '$folder_string': $@\n";

      my $folder_uidvalidity = $self->{imap_client}->uidvalidity($folder_string)
        or die "Could not get UIDVALIDITY for folder '$folder_string': $@\n";

      my $msg_uids = $self->{imap_client}->messages
        or die "Could not get messages via IMAP: $@\n";

      my $query = <<SQL;
        SELECT uid
        FROM email_imports ei
        LEFT JOIN email_journal ej
          ON ej.email_import_id = ei.id
        WHERE ei.host_name = ?
          AND ei.user_name = ?
          AND ej.folder = ?
          AND ej.folder_uidvalidity = ?
SQL

      my $existing_uids = $dbh->selectall_hashref($query, 'uid', undef,
        $self->{hostname}, $self->{username}, $folder_string, $folder_uidvalidity);

      my @new_msg_uids = grep { !$existing_uids->{$_} } @$msg_uids;

      next unless @new_msg_uids;

      $email_import ||= $self->_create_email_import($base_folder_path)->save();

      foreach my $new_uid (@new_msg_uids) {
        my $new_email_string = $self->{imap_client}->message_string($new_uid);
        my $email = Email::MIME->new($new_email_string);
        my $email_journal = $self->_create_email_journal(
          $email, $email_import, $new_uid, $folder_string, $folder_uidvalidity, $params->{email_journal}
        );
        $email_journal->save();
      }
    }
  });

  return $email_import;
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
  my ($self, $email, $email_import, $uid, $folder_string, $folder_uidvalidity, $params) = @_;

  if ($email->content_type) { # decode header
    my $charset = $email->content_type =~ /charset="(.+)"/ ? $1 : undef;
    if ($charset) {
      map { $email->header_str_set($_ => decode($charset, $email->header($_))) }
        $email->header_names;
    }
  }

  my @email_parts = $email->parts; # get parts or self
  my $text_part = $email_parts[0];
  my $body_text = $text_part->body_str;

  my %header_map = map { $_ => $email->header_str($_) } $email->header_names;
  # We need to store the Content-Type header for the text part
  $header_map{'Content-Type'} = $text_part->content_type;
  my $header_string = join "\r\n",
    (map { $_ . ': ' . $header_map{$_} } keys %header_map);

  my $date = $self->_parse_date($email->header_str('Date'));

  my $recipients = $email->header_str('To');
  $recipients .= ', ' . $email->header_str('Cc')  if ($email->header_str('Cc'));
  $recipients .= ', ' . $email->header_str('Bcc') if ($email->header_str('Bcc'));

  my @attachments = ();
  $email->walk_parts(sub {
    my ($part) = @_;
    my $filename = $part->filename;
    if ($filename) {
      my $mime_type = $part->content_type;
      $mime_type =~ s/;.*//; # clean up mime_type
      my $content = $part->body;
      my $attachment = SL::DB::EmailJournalAttachment->new(
        name      => $filename,
        content   => $content,
        mime_type => $mime_type,
      );
      push @attachments, $attachment;
    }
  });

  my $email_journal = SL::DB::EmailJournal->new(
    email_import_id    => $email_import->id,
    folder             => $folder_string,
    folder_uidvalidity => $folder_uidvalidity,
    uid                => $uid,
    status             => 'imported',
    extended_status    => '',
    from               => $email->header_str('From') || '',
    recipients         => $recipients,
    sent_on            => $date,
    subject            => $email->header_str('Subject') || '',
    body               => $body_text,
    headers            => $header_string,
    attachments        => \@attachments,
    %$params,
  );

  return $email_journal;
}

sub _parse_date {
  my ($self, $date) = @_;
  return '' unless $date;
  my $parse_date = $date;
  # replace whitespaces with single space
  $parse_date =~ s/\s+/ /g;
  # remove leading and trailing whitespaces
  $parse_date =~ s/^\s+|\s+$//g;
  # remove day-name
  $parse_date =~ s/^[A-Z][a-z][a-z], //;
  # add missing seconds
  $parse_date =~ s/( \d\d:\d\d) /$1:00 /;
  my $strp = DateTime::Format::Strptime->new(
    pattern   => '%d %b %Y %H:%M:%S %z',
    time_zone => 'UTC',
  );
  my $dt = $strp->parse_datetime($parse_date)
    or die "Could not parse date: $date\n";
  return $dt->strftime('%Y-%m-%d %H:%M:%S');
}

sub update_email_files_for_record {
  my ($self, $record) = @_;

  my $folder_string = $self->_get_folder_string_for_record($record);
  return unless $self->{imap_client}->exists($folder_string);
  $self->{imap_client}->select($folder_string)
    or die "Could not select IMAP folder '$folder_string': $@\n";

  my $msg_uids = $self->{imap_client}->messages
    or die "Could not get messages via IMAP: $@\n";

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

sub update_email_subfolders_and_files_for_records {
  my ($self) = @_;
  my $base_folder_path = $self->{base_folder};
  my $base_folder_string = $self->get_folder_string_from_path($base_folder_path);

  my $folder_strings = $self->{imap_client}->folders($base_folder_string)
    or die "Could not get folders via IMAP: $@\n";
  my @subfolder_strings = grep { $_ ne $base_folder_string } @$folder_strings;

  # Store the emails to the records
  foreach my $subfolder_string (@subfolder_strings) {
    my $ilike_folder_path = $self->get_ilike_folder_path_from_string($subfolder_string);
    my (
      $ilike_record_folder_path, # is greedily matched
      $ilike_customer_number, # no spaces allowed
      $ilike_customer_name,
      $record_folder,
      $ilike_record_number
    ) = $ilike_folder_path =~ m|^(.+)/([^\s]+) (.+)/(.+)/(.+)|;

    my $record_type = $self->{record_folder_to_type}->{$record_folder};
    next unless $record_type;

    # TODO make it generic for all records
    my $is_quotation = $record_type eq 'sales_quotation' ? 1 : 0;
    my $number_field = $is_quotation ? 'quonumber' : 'ordnumber';
    my $record = SL::DB::Manager::Order->get_first(
      query => [
        and => [
          vendor_id => undef,
          quotation => $is_quotation,
          $number_field => { ilike => $ilike_record_number },
        ],
    ]);
    next unless $record;
    $self->update_email_files_for_record($record);
  }

  return \@subfolder_strings;
}

sub create_folder {
  my ($self, $folder_name) = @_;
  return if $self->{imap_client}->exists($folder_name);
  $self->{imap_client}->create($folder_name)
    or die "Could not create IMAP folder '$folder_name': $@\n";
  $self->{imap_client}->subscribe($folder_name)
    or die "Could not subscribe to IMAP folder '$folder_name': $@\n";
  return;
}

sub get_folder_string_from_path {
  my ($self, $folder_path) = @_;
  my $separator = $self->{imap_client}->separator();
  if ($separator ne '/') {
    my $replace_sep = $separator ne '_' ? '_' : '-';
    $folder_path =~ s|\Q${separator}|$replace_sep|g; # \Q -> escape special chars
    $folder_path =~ s|/|${separator}|g; # replace / with separator
  }
  my $folder_string = encode('IMAP-UTF-7', $folder_path);
  return $folder_string;
}

sub get_ilike_folder_path_from_string {
  my ($self, $folder_string) = @_;
  my $separator = $self->{imap_client}->separator();
  my $folder_path = decode('IMAP-UTF-7', $folder_string);
  $folder_path =~ s|\Q${separator}|/|g; # \Q -> escape special chars
  $folder_path =~ s|-|_|g; # for ilike matching
  return $folder_path;
}

sub create_folder_for_record {
  my ($self, $record) = @_;
  my $folder_string = $self->_get_folder_string_for_record($record);
  $self->create_folder($folder_string);
  return;
}

sub clean_up_imported_emails_from_folder {
  my ($self, $folder_path) = @_;
  $folder_path ||= $self->{base_folder};

  my $folder_string = $self->get_folder_string_from_path($folder_path);
  $self->_clean_up_imported_emails_from_folder_strings([$folder_string]);
}


sub _clean_up_imported_emails_from_folder_strings {
  my ($self, $folder_strings) = @_;
  my $dbh = SL::DB->client->dbh;

  foreach my $folder_string (@$folder_strings) {
    $self->{imap_client}->select($folder_string)
      or die "Could not select IMAP folder '$folder_string': $@\n";

    my $folder_uidvalidity = $self->{imap_client}->uidvalidity($folder_string)
      or die "Could not get UIDVALIDITY for folder '$folder_string': $@\n";

    my $msg_uids = $self->{imap_client}->messages
      or die "Could not get messages via IMAP: $@\n";

    my $query = <<SQL;
      SELECT uid
      FROM email_imports ei
      LEFT JOIN email_journal ej
        ON ej.email_import_id = ei.id
      WHERE ei.host_name = ?
        AND ei.user_name = ?
        AND ej.folder = ?
        AND ej.folder_uidvalidity = ?
SQL

    my $existing_uids = $dbh->selectall_hashref($query, 'uid', undef,
      $self->{hostname}, $self->{username}, $folder_string, $folder_uidvalidity);

    my @imported_msg_uids = grep { $existing_uids->{$_} } @$msg_uids;

    next unless scalar @imported_msg_uids;

    $self->{imap_client}->delete_message(\@imported_msg_uids)
      or die "Could not delete messages via IMAP: $@\n";
  }
}

sub clean_up_record_subfolders {
  my ($self, $active_records) = @_;

  my $subfolder_strings =
    $self->update_email_subfolders_and_files_for_records();

  my @active_folder_strings = map { $self->_get_folder_string_for_record($_) }
    @$active_records;

  my %keep_folder = map { $_ => 1 } @active_folder_strings;
  my @folders_to_delete = grep { !$keep_folder{$_} } @$subfolder_strings;

  foreach my $folder (@folders_to_delete) {
    $self->{imap_client}->delete($folder)
      or die "Could not delete IMAP folder '$folder': $@\n";
  }
}

sub _get_folder_string_for_record {
  my ($self, $record) = @_;

  my $customer_vendor = $record->customervendor;

  #repalce / with _
  my %string_parts = ();
  $string_parts{cv_number}     = $customer_vendor->number;
  $string_parts{cv_name}       = $customer_vendor->name;
  $string_parts{record_number} = $record->number;
  foreach my $key (keys %string_parts) {
    $string_parts{$key} =~ s|/|_|g;
  }

  my $record_folder_path =
    $self->{base_folder} . '/' .
    $string_parts{cv_number} . ' ' . $string_parts{cv_name} . '/' .
    $self->{record_type_to_folder}->{$record->type} . '/' .
    $string_parts{record_number};
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
  $imap_client->update_email_files_for_record($record);

=head1 OVERVIEW

Mail can be sent from kivitendo via the sendmail command or the smtp protocol.


=head1 INTERNAL DATA TYPES

=over 2

=item C<%$self->{record_type_to_folder}>

  Due to the lack of a single global mapping for $record->type,
  type is mapped to the corresponding translation. All types which
  use this module are currently mapped and should be mapped.

=item C<%$self->record_folder_to_type>

  The reverse mapping of C<%$self->{record_type_to_folder}>.

=back

=head1 FUNCTIONS

=over 4

=item C<new>

  Creates a new SL::IMAPClient object. If no config is passed, the config
  from config/kivitendo.conf is used. If a config is passed, the global
  config is overridden.

=item C<DESTROY>

  Destructor. Disconnects from the IMAP server.

=item C<update_emails_from_folder>

  Updates the emails for a folder. Checks which emails are missing and
  fetches these from the IMAP server. Returns the created email import object.

=item C<update_emails_from_subfolders>

  Updates the emails for all subfolders of a folder. Checks which emails are
  missing and fetches these from the IMAP server. Returns the created email
  import object.

=item C<_update_emails_from_folder_strings>

  Updates the emails for a list of folder strings. Checks which emails are
  missing and fetches these from the IMAP server. Returns the created
  email import object.

=item C<update_email_files_for_record>

  Updates the email files for a record. Checks which emails are missing and
  fetches these from the IMAP server.

=item C<update_email_subfolders_and_files_for_records>

    Updates all subfolders and the email files for all records.

=item C<create_folder>

  Creates a folder on the IMAP server. If the folder already exists, nothing
  happens.

=item C<get_folder_string_from_path>

  Converts a folder path to a folder string. The folder path is like path
  on unix filesystem. The folder string is the path on the IMAP server.
  The folder string is encoded in IMAP-UTF-7.

=item C<get_ilike_folder_path_from_string>

  Converts a folder string to a folder path. The folder path is like path
  on unix filesystem. The folder string is the path on the IMAP server.
  The folder string is encoded in IMAP-UTF-7. It can happend that
  C<get_folder_string_from_path> and C<get_ilike_folder_path_from_string>
  don't cancel each other out. This is because the IMAP server can has a
  different Ieparator than the unix filesystem. The changes are made so that a
  ILIKE query on the database works.

=item C<create_folder_for_record>

  Creates a folder for a record on the IMAP server. The folder structure
  is like this: base_folder/customer_vendor_number customer_vendor_name/type/record_number
  e.g. INBOX/1234 Testkunde/Angebot/123
  If the folder already exists, nothing happens.

=item C<clean_up_record_subfolders>

  Gets a list of acitve records. Syncs all subfolders and add email files to
  the records. Then deletes all subfolders which are not corresponding to an
  active record.

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

The mapping from record to email folder is not bijective. If the record or
customer number has special characters, the mapping can fail. Read
C<get_ilike_folder_path_from_string> for more information.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
