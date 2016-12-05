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
use File::Slurp;
use List::UtilsBy qw(bundle_by);

use SL::Common;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::DB::Employee;
use SL::MIME;
use SL::Template;

use strict;

my $num_sent = 0;

my %mail_delivery_modules = (
  sendmail => 'SL::Mailer::Sendmail',
  smtp     => 'SL::Mailer::SMTP',
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

  if (ref($attachment) eq "HASH") {
    $attributes{filename} = $attachment->{name};
    $attachment_content   = $attachment->{content} // eval { read_file($attachment->{filename}) };

  } else {
    # strip path
    $attributes{filename} =  $attachment;
    $attributes{filename} =~ s:.*\Q$self->{fileid}\E:: if $self->{fileid};
    $attributes{filename} =~ s:.*/::g;
    $attachment_content   =  eval { read_file($attachment) };
  }

  return undef if !defined $attachment_content;

  my $application             = ($attachment =~ /(^\w+$)|\.(html|text|txt|sql)$/) ? 'text' : 'application';
  $attributes{content_type}   = SL::MIME->mime_type_from_ext($attributes{filename});
  $attributes{content_type} ||= "${application}/$self->{format}" if $self->{format};
  $attributes{content_type} ||= 'application/octet-stream';
  $attributes{charset}        = $self->{charset} if lc $application eq 'text' && $self->{charset};

  return Email::MIME->create(
    attributes => \%attributes,
    body       => $attachment_content,
  );
}

sub _create_message {
  my ($self) = @_;

  my @parts;

  if ($self->{message}) {
    push @parts, Email::MIME->create(
      attributes => {
        content_type => $self->{contenttype},
        charset      => $self->{charset},
        encoding     => 'quoted-printable',
      },
      body_str => $self->{message},
    );

    push @{ $self->{headers} }, (
      'Content-Type' => qq|$self->{contenttype}; charset="$self->{charset}"|,
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
    $self->_store_in_journal('failed', 'driver could not be created; check your configuration');
    return "send email : $@";
  }

  # Set defaults & headers
  $self->{charset}       =  'UTF-8';
  $self->{contenttype} ||=  "text/plain";
  $self->{headers}       =  [
    Subject              => $self->{subject},
    'Message-ID'         => '<' . $self->_create_message_id . '>',
    'X-Mailer'           => "kivitendo $self->{version}",
  ];

  my $error;
  my $ok = eval {
    # Clean up To/Cc/Bcc address fields
    $self->_cleanup_addresses;
    $self->_create_address_headers;

    my $email = $self->_create_message;

    # $::lxdebug->message(0, "message: " . $email->as_string);
    # return "boom";

    $self->{driver}->start_mail(from => $self->{from}, to => [ $self->_all_recipients ]);
    $self->{driver}->print($email->as_string);
    $self->{driver}->send;

    1;
  };

  $error = $@ if !$ok;

  $self->_store_in_journal;

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

  my @attachments;

  @attachments = grep { $_ } map {
    my $part = $self->_create_attachment_part($_);
    if ($part) {
      SL::DB::EmailJournalAttachment->new(
        name      => $part->filename,
        mime_type => $part->content_type,
        content   => $part->body,
      )
    }
  } @{ $self->{attachments} || [] } if $journal_enable > 1;

  my $headers = join "\r\n", (bundle_by { join(': ', @_) } 2, @{ $self->{headers} || [] });

  SL::DB::EmailJournal->new(
    sender          => SL::DB::Manager::Employee->current,
    from            => $self->{from}    // '',
    recipients      => join(', ', $self->_all_recipients),
    subject         => $self->{subject} // '',
    headers         => $headers,
    body            => $self->{message} // '',
    sent_on         => DateTime->now_local,
    attachments     => \@attachments,
    status          => $status,
    extended_status => $extended_status,
  )->save;
}

1;
