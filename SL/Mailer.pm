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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================

package Mailer;

use Email::Address;
use Email::MIME::Creator;
use File::Slurp;

use SL::Common;
use SL::MIME;
use SL::Template;

use strict;

my $num_sent = 0;

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

  my $module = ($::lx_office_conf{mail_delivery}->{method} || 'smtp') ne 'smtp' ? 'SL::Mailer::Sendmail' : 'SL::Mailer::SMTP';
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

  my $source_file_name;

  my %attributes = (
    disposition  => 'attachment',
    encoding     => 'base64',
  );

  if (ref($attachment) eq "HASH") {
    $attributes{filename} = $attachment->{name};
    $source_file_name     = $attachment->{filename};

  } else {
    # strip path
    $attributes{filename} =  $attachment;
    $attributes{filename} =~ s:.*\Q$self->{fileid}\E:: if $self->{fileid};
    $attributes{filename} =~ s:.*/::g;
    $source_file_name     =  $attachment;
  }

  my $attachment_content = eval { read_file($source_file_name) };
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
    $::lxdebug->leave_sub();
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

  # Clean up To/Cc/Bcc address fields
  $self->_cleanup_addresses;
  $self->_create_address_headers;

  my $email = $self->_create_message;

  # $::lxdebug->message(0, "message: " . $email->as_string);
  # return "boom";

  $self->{driver}->start_mail(from => $self->{from}, to => [ map { @{ $self->{addresses}->{$_} } } qw(to cc bcc) ]);
  $self->{driver}->print($email->as_string);
  $self->{driver}->send;

  return '';
}

1;
