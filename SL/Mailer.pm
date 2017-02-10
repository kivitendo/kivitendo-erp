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
use MIME::Entity;
use MIME::Parser;
use File::MimeInfo::Magic;
use File::Slurp;
use List::UtilsBy qw(bundle_by);

use SL::Common;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::DB::Employee;
use SL::Template;

use strict;
use Encode;

my $num_sent = 0;
my $parser;

my %mail_delivery_modules = (
  sendmail => 'SL::Mailer::Sendmail',
  smtp     => 'SL::Mailer::SMTP',
);

sub new {
  my ($type, %params) = @_;
  my $self = { %params };
  $parser = MIME::Parser->new;
  $parser->output_under("users");

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

  return  "kivitendo-$self->{version}-" . time() . "-${$}-${num_sent}\@$domain";
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

      push @header_addresses, encode('MIME-Header',$addr_obj->format);
    }

    push @{ $self->{headers} }, ( ucfirst($item) => join(', ', @header_addresses) ) if @header_addresses;
  }
}

sub _create_attachment_part {
  my ($self, $attachment) = @_;

  my %attributes = (
    Disposition  => 'attachment',
    Encoding     => 'base64',
  );

  my $attachment_content;
  my $file_id       = 0;
  my $email_journal = $::instance_conf->get_email_journal;

  $::lxdebug->message(LXDebug->DEBUG2(), "mail5 att=" . $attachment . " email_journal=" . $email_journal . " id=" . $attachment->{id});

  if (ref($attachment) eq "HASH") {
    $attributes{Path}     = $attachment->{path} || $attachment->{filename};
    $attributes{Filename} = $attachment->{name};
    $file_id              = $attachment->{id}   || '0';
    $attributes{Type}     = $attachment->{type} || 'application/pdf';
    $attachment_content   = eval { read_file($attachment->{path}) } if $email_journal > 1;

  } else {
    # strip path
    $attributes{Path}     =  $attachment;
    $attributes{Filename} =  $attachment;
    $attributes{Filename} =~ s:.*\Q$self->{fileid}\E:: if $self->{fileid};
    $attributes{Filename} =~ s:.*/::g;

    my $application     = ($attachment =~ /(^\w+$)|\.(html|text|txt|sql)$/) ? 'text' : 'application';
    $attributes{Type}   = File::MimeInfo::Magic::magic($attachment);
    $attributes{Type} ||= "${application}/$self->{format}" if $self->{format};
    $attributes{Type} ||= 'application/octet-stream';
    $attachment_content = eval { read_file($attachment) } if $email_journal > 1;
  }

  return undef if $email_journal > 1 && !defined $attachment_content;

  $attachment_content ||= ' ';
  $attributes{Charset}  = $self->{charset} if $self->{charset};

  $::lxdebug->message(LXDebug->DEBUG2(), "mail6 mtype=" . $attributes{Type} . " path=" . $attributes{Path} . " filename=" . $attributes{Filename});

  my $ent;
  if ( $attributes{Type} eq 'message/rfc822' ) {
    my $fh = IO::File->new($attributes{Path}, "r") or return undef;
    $ent   = $parser->parse($fh);

    $ent->head->replace('Content-disposition','attachment; filename='.$attributes{Filename});

  } else {
    $ent = MIME::Entity->build(%attributes);
  }

  push @{ $self->{mail_attachments}} , SL::DB::EmailJournalAttachment->new(
    name      => $attributes{Filename},
    mime_type => $attributes{Type},
    content   => ( $email_journal > 1 ? $attachment_content : ' '),
    file_id   => $file_id,
  );

  return $ent;
}

sub _create_message {
  my ($self) = @_;

  push @{ $self->{headers} }, (Type => "multipart/mixed");

  my $top = MIME::Entity->build(@{$self->{headers}});

  if ($self->{message}) {
    $top->attach(
      Data     => encode($self->{charset},$self->{message}),
      Charset  => $self->{charset},
      Type     => $self->{contenttype},
      Encoding => 'quoted-printable',
    );
  }

  $top->add_part($self->_create_attachment_part($_)) for @{ $self->{attachments} || [] };

  return $top;
}

sub send {
  my ($self) = @_;

  # Create driver for delivery method (sendmail/SMTP)
  $self->{driver} = eval { $self->_create_driver };
  if (!$self->{driver}) {
    $self->_store_in_journal('failed', 'driver could not be created; check your configuration');
    return "send email : $@";
  }

  # Set defaults & headers
  $self->{charset}       =  'UTF-8';
  $self->{contenttype} ||=  "text/plain";
  $self->{headers}       =  [
    Subject              => encode('MIME-Header',$self->{subject}),
    'Message-ID'         => '<' . $self->_create_message_id . '>',
    'X-Mailer'           => "kivitendo $self->{version}",
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

    my $from_obj = (Email::Address->parse($self->{from}))[0];

    $self->{driver}->start_mail(from => $from_obj->address, to => [ $self->_all_recipients ]);
    $self->{driver}->print($email->as_string);
    $self->{driver}->send;

    1;
  };

  $error = $@ if !$ok;

  $self->{journalentry} = $self->_store_in_journal;
  $parser->filer->purge;

  return $ok ? '' : "send email: $error";
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

1;
