#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================

package Mailer;

use IO::Socket::INET;
use IO::Socket::SSL;
use Mail::IMAPClient;
use Email::Address;
use Email::MIME::Creator;
use Encode;
use File::MimeInfo::Magic;
use File::Slurp;
use List::UtilsBy qw(bundle_by);
use List::Util qw(sum);

use SL::Common;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::DB::Employee;
use SL::Locale::String qw(t8);
use SL::Template;
use SL::Version;

use strict;

my $num_sent = 0;

my %mail_delivery_modules = (
  sendmail => 'SL::Mailer::Sendmail',
  smtp     => 'SL::Mailer::SMTP',
);

my %type_to_table = (
  sales_quotation         => 'oe',
  request_quotation       => 'oe',
  sales_order             => 'oe',
  purchase_order          => 'oe',
  invoice                 => 'ar',
  credit_note             => 'ar',
  purchase_invoice        => 'ap',
  letter                  => 'letter',
  purchase_delivery_order => 'delivery_orders',
  sales_delivery_order    => 'delivery_orders',
  dunning                 => 'dunning',
);
my %type_to_email = (
  sales_quotation         => sub { $::instance_conf->get_email_sender_sales_quotation         },
  request_quotation       => sub { $::instance_conf->get_email_sender_request_quotation       },
  sales_order             => sub { $::instance_conf->get_email_sender_sales_order             },
  purchase_order          => sub { $::instance_conf->get_email_sender_purchase_order          },
  invoice                 => sub { $::instance_conf->get_email_sender_invoice                 },
  credit_note             => sub { $::instance_conf->get_email_sender_invoice                 },
  purchase_invoice        => sub { $::instance_conf->get_email_sender_purchase_invoice        },
  letter                  => sub { $::instance_conf->get_email_sender_letter                  },
  purchase_delivery_order => sub { $::instance_conf->get_email_sender_purchase_delivery_order },
  sales_delivery_order    => sub { $::instance_conf->get_email_sender_sales_delivery_order    },
  dunning                 => sub { $::instance_conf->get_email_sender_dunning                 },
);


sub new {
  my ($type, %params) = @_;
  my $self = { %params };

  bless $self, $type;
}

sub _create_driver {
  my ($self) = @_;

  my %params = (
    mailer   => $self,
    form     => $::form,
    myconfig => \%::myconfig,
  );

  my $module = $mail_delivery_modules{ $::lx_office_conf{mail_delivery}->{method} };
  eval "require $module" or return undef;

  return $module->new(%params);
}

sub _cleanup_addresses {
  my ($self) = @_;

  foreach my $item (qw(to cc bcc)) {
    next unless $self->{$item};

    $self->{$item} =~ s/\&lt;/</g;
    $self->{$item} =~ s/\$<\$/</g;
    $self->{$item} =~ s/\&gt;/>/g;
    $self->{$item} =~ s/\$>\$/>/g;
  }
}

sub _create_message_id {
  my ($self) = @_;

  $num_sent  +=  1;
  my $domain  =  $self->{from};
  $domain     =~ s/.*\@//;
  $domain     =~ s/>.*//;

  return  "kivitendo-" . SL::Version->get_version . "-" . time() . "-${$}-${num_sent}\@$domain";
}

sub _create_address_headers {
  my ($self) = @_;

  # $self->{addresses} collects the recipients for use in e.g. the
  # SMTP 'RCPT TO:' envelope command. $self->{headers} collects the
  # headers that make up the actual email. 'BCC' should not be
  # included there for certain transportation methods (SMTP).

  $self->{addresses} = {};

  foreach my $item (qw(from to cc bcc)) {
    $self->{addresses}->{$item} = [];
    next if !$self->{$item};

    my @header_addresses;
    my @addresses = Email::Address->parse($self->{$item});

    # if either no address was parsed or
    # there are more than 3 characters per parsed email extra, assume the the user has entered bunk
    if (!@addresses) {
       die t8('"#1" seems to be a faulty list of email addresses. No addresses could be extracted.',
         $self->{$item},
       );
    } elsif ((length($self->{$item}) - sum map { length $_->original } @addresses) / @addresses > 3) {
       die t8('"#1" seems to be a faulty list of email addresses. After extracing addresses (#2) too many characters are left.',
         $self->{$item}, join ', ', map { $_->original } @addresses,
       );
    }

    foreach my $addr_obj (@addresses) {
      push @{ $self->{addresses}->{$item} }, $addr_obj->address;
      next if $self->{driver}->keep_from_header($item);

      my $phrase = $addr_obj->phrase();
      if ($phrase) {
        $phrase =~ s/^\"//;
        $phrase =~ s/\"$//;
        $addr_obj->phrase($phrase);
      }

      push @header_addresses, $addr_obj->format;
    }

    push @{ $self->{headers} }, ( ucfirst($item) => join(', ', @header_addresses) ) if @header_addresses;
  }
}

sub _create_attachment_part {
  my ($self, $attachment) = @_;

  my %attributes = (
    disposition  => 'attachment',
    encoding     => 'base64',
  );

  my $attachment_content;
  my $file_id       = 0;
  my $email_journal = $::instance_conf->get_email_journal;

  if (ref($attachment) eq "HASH") {
    $attributes{filename}     = $attachment->{name};
    $file_id                  = $attachment->{id}   || '0';
    $attributes{content_type} = $attachment->{type} || 'application/pdf';
    $attachment_content       = $attachment->{content};
    $attachment_content       = eval { read_file($attachment->{path}) } if !$attachment_content;

  } else {
    $attributes{filename} =  $attachment;
    $attributes{filename} =~ s:.*\Q$self->{fileid}\E:: if $self->{fileid};
    $attributes{filename} =~ s:.*/::g;

    my $application             = ($attachment =~ /(^\w+$)|\.(html|text|txt|sql)$/) ? 'text' : 'application';
    $attributes{content_type}   = File::MimeInfo::Magic::magic($attachment);
    $attributes{content_type} ||= "${application}/$self->{format}" if $self->{format};
    $attributes{content_type} ||= 'application/octet-stream';
    $attachment_content         = eval { read_file($attachment) };
  }

  return undef if $email_journal > 1 && !defined $attachment_content;

  $attachment_content ||= ' ';
  $attributes{charset}  = $self->{charset} if $self->{charset} && ($attributes{content_type} =~ m{^text/});

  my $ent;
  if ( $attributes{content_type} eq 'message/rfc822' ) {
    $ent = Email::MIME->new($attachment_content);
  } else {
    $ent = Email::MIME->create(
      attributes => \%attributes,
      body       => $attachment_content,
    );
  }

  # Due to a bug in Email::MIME it's not enough to hand over the encoded file name in the "attributes" hash in the
  # "create" call. Email::MIME iterates over the keys in the hash, and depending on which key it has already seen during
  # the iteration it might revert the encoding. As Perl's hash key order is randomized for each Perl run, this means
  # that the file name stays unencoded sometimes.
  # Setting the header manually after the "create" call circumvents this problem.
  $ent->header_set('Content-disposition' => 'attachment; filename="' . encode('MIME-Q', $attributes{filename}) . '"');

  push @{ $self->{mail_attachments}} , SL::DB::EmailJournalAttachment->new(
    name      => $attributes{filename},
    mime_type => $attributes{content_type},
    content   => ( $email_journal > 1 ? $attachment_content : ' '),
    file_id   => $file_id,
  );

  return $ent;
}

sub _create_message {
  my ($self) = @_;

  my @parts;

  if ($self->{message}) {
    push @parts, Email::MIME->create(
      attributes => {
        content_type => $self->{content_type},
        charset      => $self->{charset},
        encoding     => 'quoted-printable',
      },
      body_str => $self->{message},
    );

    push @{ $self->{headers} }, (
      'Content-Type' => qq|$self->{content_type}; charset="$self->{charset}"|,
    );
  }

  push @parts, grep { $_ } map { $self->_create_attachment_part($_) } @{ $self->{attachments} || [] };

  return Email::MIME->create(
      header_str => $self->{headers},
      parts      => \@parts,
  );
}

sub send {
  my ($self) = @_;

  # Create driver for delivery method (sendmail/SMTP)
  $self->{driver} = eval { $self->_create_driver };
  if (!$self->{driver}) {
    my $error = $@;
    $self->_store_in_journal('send_failed', 'driver could not be created; check your configuration & log files');
    $::lxdebug->message(LXDebug::WARN(), "Mailer error during 'send': $error");

    return $error;
  }
  $self->_default_from;  # set from for records if configured in client config
  # Set defaults & headers
  $self->{charset}        =  'UTF-8';
  $self->{content_type} ||=  "text/plain";
  $self->{headers}      ||=  [];
  push @{ $self->{headers} }, (
    Subject               => $self->{subject},
    'Message-ID'          => '<' . $self->_create_message_id . '>',
    'X-Mailer'            => "kivitendo " . SL::Version->get_version,
  );
  $self->{mail_attachments} = [];

  my $email_as_string;
  my $error;
  my $ok = eval {
    # Clean up To/Cc/Bcc address fields
    $self->_cleanup_addresses;
    $self->_create_address_headers;

    my $email = $self->_create_message;

    my $from_obj = (Email::Address->parse($self->{from}))[0];

    $self->{driver}->start_mail(from => $from_obj->address, to => [ $self->_all_recipients ]);
    $self->{driver}->print($email->as_string);
    $self->{driver}->send;

    $email_as_string = $email->as_string;
    1;
  };

  $error = $@ if !$ok;

  # TODO: Error is not for sending emial
  # in SL::Form->send_email error is treated as error for sending email
  if ($ok) {
    eval {$self->_store_in_imap_sent_folder($email_as_string); 1} or do {
      $ok = 0;
      $error = $@;
    };
  }

  # create journal and link to record
  $self->{journalentry} = $self->_store_in_journal;
  $self->_create_record_link if $self->{journalentry};

  return $ok ? '' : ($error || "undefined error");
}

sub _all_recipients {
  my ($self) = @_;
  $self->{addresses} ||= {};
  return map { @{ $self->{addresses}->{$_} || [] } } qw(to cc bcc);
}

sub _get_header_string {
  my ($self) = @_;
  my $header_string =
    join "\r\n",
      (bundle_by { join(': ', @_) } 2, @{ $self->{headers} || [] });
  return $header_string;
}

sub _store_in_imap_sent_folder {
  my ($self, $email_as_string) = @_;

  my $from_email = $self->{from};
  my $user_email = $::myconfig{email};
  my $config =
       $::lx_office_conf{"sent_emails_in_imap/email/$from_email"}
    || $::lx_office_conf{"sent_emails_in_imap/email/$user_email"}
    || $::lx_office_conf{sent_emails_in_imap}
    || {};
  return unless ($config->{enabled} && $config->{hostname});

  my $socket;
  if ($config->{ssl}) {
    $socket = IO::Socket::SSL->new(
      Proto    => 'tcp',
      PeerAddr => $config->{hostname},
      PeerPort => $config->{port} || 993,
    );
  } else {
    $socket = IO::Socket::INET->new(
      Proto    => 'tcp',
      PeerAddr => $config->{hostname},
      PeerPort => $config->{port} || 143,
    );
  }
  if (!$socket) {
    die "Failed to create socket for IMAP client: $@\n";
  }

  my $imap = Mail::IMAPClient->new(
    Socket   => $socket,
    User     => $config->{username},
    Password => $config->{password},
  ) or do {
    die "Failed to create IMAP Client: $@\n"
  };

  $imap->IsAuthenticated() or do {
    die "IMAP Client login failed: " . $imap->LastError() . "\n";
  };

  my $separator =  $imap->separator();
  my $folder    =  $config->{folder} || 'Sent/Kivitendo';
  $folder       =~ s|/|${separator}|g;

  $imap->append_string($folder, $email_as_string) or do {
    my $last_error = $imap->LastError();
    $imap->logout();
    die "IMAP Client append failed: $last_error\n";
  };

  $imap->logout();
  return 1;
}

sub _store_in_journal {
  my ($self, $status, $extended_status) = @_;

  my $journal_enable = $::instance_conf->get_email_journal;

  return if $journal_enable == 0;

  $status          //= $self->{driver}->status if $self->{driver};
  $status          //= 'send_failed';
  $extended_status //= $self->{driver}->extended_status if $self->{driver};
  $extended_status //= 'unknown error';

  my $headers = $self->_get_header_string;

  my $jentry = SL::DB::EmailJournal->new(
    sender          => SL::DB::Manager::Employee->current,
    from            => $self->{from}    // '',
    recipients      => join(', ', $self->_all_recipients),
    subject         => $self->{subject} // '',
    headers         => $headers,
    body            => $self->{message} // '',
    sent_on         => DateTime->now_local,
    attachments     => \@{ $self->{mail_attachments} },
    status          => $status,
    extended_status => $extended_status,
  )->save;
  return $jentry->id;
}


sub _create_record_link {
  my ($self) = @_;

  # check for custom/overloaded types and ids (form != controller)
  my $record_type = $self->{record_type} || $::form->{type} || '';
  my $record_id   = $self->{record_id}   || $::form->{id};

  # you may send mails for unsaved objects (no record_id => unlinkable case)
  if ($self->{journalentry} && $record_id && exists($type_to_table{$record_type})) {
    RecordLinks->create_links(
      mode       => 'ids',
      from_table => $type_to_table{$record_type},
      from_ids   => $record_id,
      to_table   => 'email_journal',
      to_id      => $self->{journalentry},
    );
  }
}


sub _default_from {
  my ($self) = @_;

  my $record_type  = $self->{record_type} || $::form->{type} || $self->{driver}{form}{formname} || '';
  my $record_email = exists $type_to_email{$record_type} ? $type_to_email{$record_type}->() : undef;
  $self->{from}    = $record_email if $record_email;
}

1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::Mailer - Base class for sending mails from kivitendo

=head1 SYNOPSIS

  package SL::BackgroundJob::CreatePeriodicInvoices;

  use SL::Mailer;

  my $mail              = Mailer->new;
  $mail->{from}         = $config{periodic_invoices}->{email_from};
  $mail->{to}           = $email;
  $mail->{subject}      = $config{periodic_invoices}->{email_subject};
  $mail->{content_type} = $filename =~ m/.html$/ ? 'text/html' : 'text/plain';
  $mail->{message}      = $output;

  $mail->send;

=head1 OVERVIEW

Mail can be sent from kivitendo via the sendmail command or the smtp protocol.


=head1 INTERNAL DATA TYPES


=over 2

=item C<%mail_delivery_modules>

  Currently two modules are supported: smtp or sendmail.

=item C<%type_to_table>

  Due to the lack of a single global mapping for $form->{type},
  type is mapped to the corresponding database table. All types which
  implement a mail action are currently mapped and should be mapped.
  Type is either the value of the old form or the newer controller
  based object type.

=back

=head1 FUNCTIONS

=over 4

=item C<new>

=item C<_create_driver>

=item C<_cleanup_addresses>

=item C<_create_address_headers>

=item C<_create_message_id>

=item C<_create_attachment_part>

=item C<_create_message>

=item C<send>

  If a mail was sent successfully the internal function _store_in_journal
  is called if email journaling is enabled. If _store_in_journal was executed
  successfully and the calling form is already persistent (database id) a
  record_link will be created.

=item C<_all_recipients>

=item C<_store_in_journal>

=item C<_create_record_link $self->{journalentry}, $::form->{id}, $self->{record_id}>


  If $self->{journalentry} and either $self->{record_id} or $::form->{id} (checked in
  this order) exist a record link from record to email journal is created.
  It is possible to provide an array reference with more than one id in
  $self->{record_id} or $::form->{id}. In this case all records are linked to
  the mail.
  Will fail silently if record_link creation wasn't successful (same behaviour as
  _store_in_journal).

=item C<validate>

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

=cut
