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

use Email::Address;
use Email::MIME::Creator;
use File::MimeInfo::Magic;
use File::Slurp;
use List::UtilsBy qw(bundle_by);

use SL::Common;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::DB::Employee;
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

    foreach my $addr_obj (Email::Address->parse($self->{$item})) {
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

  $::lxdebug->message(LXDebug->DEBUG2(), "mail5 att=" . $attachment . " email_journal=" . $email_journal . " id=" . $attachment->{id});

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

  $::lxdebug->message(LXDebug->DEBUG2(), "mail6 mtype=" . $attributes{content_type} . " filename=" . $attributes{filename});

  my $ent;
  if ( $attributes{content_type} eq 'message/rfc822' ) {
    $ent = Email::MIME->new($attachment_content);
    $ent->header_str_set('Content-disposition' => 'attachment; filename='.$attributes{filename});
  } else {
    $ent = Email::MIME->create(
      attributes => \%attributes,
      body       => $attachment_content,
    );
  }

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

  push @{ $self->{headers} }, (Type => "multipart/mixed");

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
    $self->_store_in_journal('failed', 'driver could not be created; check your configuration & log files');
    $::lxdebug->message(LXDebug::WARN(), "Mailer error during 'send': $error");

    return $error;
  }

  # Set defaults & headers
  $self->{charset}        =  'UTF-8';
  $self->{content_type} ||=  "text/plain";
  $self->{headers}        =  [
    Subject               => $self->{subject},
    'Message-ID'          => '<' . $self->_create_message_id . '>',
    'X-Mailer'            => "kivitendo " . SL::Version->get_version,
  ];
  $self->{mail_attachments} = [];
  $self->{content_by_name}  = $::instance_conf->get_email_journal == 1 && $::instance_conf->get_doc_files;

  my $error;
  my $ok = eval {
    # Clean up To/Cc/Bcc address fields
    $self->_cleanup_addresses;
    $self->_create_address_headers;

    my $email = $self->_create_message;

    #$::lxdebug->message(0, "message: " . $email->as_string);
    # return "boom";

    $::lxdebug->message(LXDebug->DEBUG2(), "mail1 from=".$self->{from}." to=".$self->{to});
    my $from_obj = (Email::Address->parse($self->{from}))[0];

    $self->{driver}->start_mail(from => $from_obj->address, to => [ $self->_all_recipients ]);
    $self->{driver}->print($email->as_string);
    $self->{driver}->send;

    1;
  };

  $error = $@ if !$ok;

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

sub _store_in_journal {
  my ($self, $status, $extended_status) = @_;

  my $journal_enable = $::instance_conf->get_email_journal;

  return if $journal_enable == 0;

  $status          //= $self->{driver}->status if $self->{driver};
  $status          //= 'failed';
  $extended_status //= $self->{driver}->extended_status if $self->{driver};
  $extended_status //= 'unknown error';

  my $headers = join "\r\n", (bundle_by { join(': ', @_) } 2, @{ $self->{headers} || [] });

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
  my $record_type = $self->{record_type} || $::form->{type};
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

Mail can be send from kivitendo via the sendmail command or the smtp protocol.


=head1 INTERNAL DATA TYPES


=over 2

=item C<%mail_delivery_modules>

  Currently two modules are supported either smtp or sendmail.

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

  If a mail was send successfully the internal functions _store_in_journal
  is called if email journaling is enabled. If _store_in_journal was executed
  successfully and the calling form is already persistent (database id) a
  record_link will be created.

=item C<_all_recipients>

=item C<_store_in_journal>

=item C<_create_record_link $self->{journalentry}, $::form->{id}, $self->{record_id}>


  If $self->{journalentry} and either $self->{record_id} or $::form->{id} (checked in
  this order) exists a record link from record to email journal is created.
  Will fail silently if record_link creation wasn't successful (same behaviour as
  _store_in_journal).

=item C<validate>

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

=cut
