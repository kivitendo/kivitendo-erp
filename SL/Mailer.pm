#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
# Contributors:
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
use Encode;

use SL::Common;
use SL::MIME;
use SL::Template;

use strict;

my $num_sent = 0;

sub new {
  $main::lxdebug->enter_sub();

  my ($type) = @_;
  my $self = {};

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

sub mime_quote_text {
  $main::lxdebug->enter_sub();

  my ($self, $text, $chars_left) = @_;

  my $q_start = "=?$self->{charset}?Q?";
  my $l_start = length($q_start);

  my $new_text = "$q_start";
  $chars_left -= $l_start if (defined $chars_left);

  for (my $i = 0; $i < length($text); $i++) {
    my $char = ord(substr($text, $i, 1));

    if (($char < 32) || ($char > 127) || ($char == ord('?')) || ($char == ord('_'))) {
      if ((defined $chars_left) && ($chars_left < 5)) {
        $new_text .= "?=\n $q_start";
        $chars_left = 75 - $l_start;
      }

      $new_text .= sprintf("=%02X", $char);
      $chars_left -= 3 if (defined $chars_left);

    } else {
      $char = ord('_') if ($char == ord(' '));
      if ((defined $chars_left) && ($chars_left < 5)) {
        $new_text .= "?=\n $q_start";
        $chars_left = 75 - $l_start;
      }

      $new_text .= chr($char);
      $chars_left-- if (defined $chars_left);
    }
  }

  $new_text .= "?=";

  $main::lxdebug->leave_sub();

  return $new_text;
}

sub send {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  local (*IN, *OUT);

  $num_sent++;
  my $boundary    = time() . "-$$-${num_sent}";
  $boundary       =  "LxOffice-$self->{version}-$boundary";
  my $domain      =  $self->recode($self->{from});
  $domain         =~ s/(.*?\@|>)//g;
  my $msgid       =  "$boundary\@$domain";

  my $form        =  $main::form;
  my $myconfig    =  \%main::myconfig;

  my $email       =  $self->recode($myconfig->{email});
  $email          =~ s/[^\w\.\-\+=@]//ig;

  my %temp_form   = ( %{ $form }, 'myconfig_email' => $email );
  my $template    = SL::Template::create(type => 'PlainText', form => \%temp_form);
  my $sendmail    = $template->parse_block($::lx_office_conf{applications}->{sendmail});

  if (!open(OUT, "|$sendmail")) {
    $main::lxdebug->leave_sub();
    return "$sendmail : $!";
  }

  $self->{charset}     ||= Common::DEFAULT_CHARSET;
  $self->{contenttype} ||= "text/plain";

  foreach my $item (qw(to cc bcc)) {
    next unless ($self->{$item});
    $self->{$item} =  $self->recode($self->{$item});
    $self->{$item} =~ s/\&lt;/</g;
    $self->{$item} =~ s/\$<\$/</g;
    $self->{$item} =~ s/\&gt;/>/g;
    $self->{$item} =~ s/\$>\$/>/g;
  }

  $self->{from} = $self->recode($self->{from});

  my $headers = '';
  foreach my $item (qw(from to cc bcc)) {
    next unless ($self->{$item});
    my (@addr_objects) = Email::Address->parse($self->{$item});
    next unless (scalar @addr_objects);

    foreach my $addr_obj (@addr_objects) {
      my $phrase = $addr_obj->phrase();
      if ($phrase) {
        $phrase =~ s/^\"//;
        $phrase =~ s/\"$//;
        $addr_obj->phrase($self->mime_quote_text($phrase));
      }

      $headers .= sprintf("%s: %s\n", ucfirst($item), $addr_obj->format());
    }
  }

  $headers .= sprintf("Subject: %s\n", $self->mime_quote_text($self->recode($self->{subject}), 60));

  print OUT qq|${headers}Message-ID: <$msgid>
X-Mailer: Lx-Office $self->{version}
MIME-Version: 1.0
|;

  if ($self->{attachments}) {
    print OUT qq|Content-Type: multipart/mixed; boundary="$boundary"

|;
    if ($self->{message}) {
      print OUT qq|--${boundary}
Content-Type: $self->{contenttype}; charset="$self->{charset}"

| . $self->recode($self->{message}) . qq|

|;
    }

    foreach my $attachment (@{ $self->{attachments} }) {

      my $filename;

      if (ref($attachment) eq "HASH") {
        $filename = $attachment->{"name"};
        $attachment = $attachment->{"filename"};
      } else {
        $filename = $attachment;
        # strip path
        $filename =~ s/(.*\/|\Q$self->{fileid}\E)//g;
      }

      my $application    = ($attachment =~ /(^\w+$)|\.(html|text|txt|sql)$/) ? "text" : "application";
      my $content_type   = SL::MIME->mime_type_from_ext($filename);
      $content_type      = "${application}/$self->{format}" if (!$content_type && $self->{format});
      $content_type    ||= 'application/octet-stream';

      open(IN, $attachment);
      if ($?) {
        close(OUT);
        $main::lxdebug->leave_sub();
        return "$attachment : $!";
      }

      # only set charset for attachements of type text. every other type should not have this field
      # refer to bug 883 for detailed information
      my $attachment_charset;
      if (lc $application eq 'text' && $self->{charset}) {
        $attachment_charset = qq|; charset="$self->{charset}" |;
      }

      print OUT qq|--${boundary}
Content-Type: ${content_type}; name="$filename"$attachment_charset
Content-Transfer-Encoding: BASE64
Content-Disposition: attachment; filename="$filename"\n\n|;

      my $msg = "";
      while (<IN>) {
        ;
        $msg .= $_;
      }
      print OUT &encode_base64($msg);

      close(IN);

    }
    print OUT qq|--${boundary}--\n|;

  } else {
    print OUT qq|Content-Type: $self->{contenttype}; charset="$self->{charset}"

| . $self->recode($self->{message}) . qq|
|;
  }

  close(OUT);

  $main::lxdebug->leave_sub();

  return "";
}

sub encode_base64 ($;$) {
  $main::lxdebug->enter_sub();

  # this code is from the MIME-Base64-2.12 package
  # Copyright 1995-1999,2001 Gisle Aas <gisle@ActiveState.com>

  my $res = "";
  my $eol = $_[1];
  $eol = "\n" unless defined $eol;
  pos($_[0]) = 0;    # ensure start at the beginning

  $res = join '', map(pack('u', $_) =~ /^.(\S*)/, ($_[0] =~ /(.{1,45})/gs));

  $res =~ tr|` -_|AA-Za-z0-9+/|;    # `# help emacs
                                    # fix padding at the end
  my $padding = (3 - length($_[0]) % 3) % 3;
  $res =~ s/.{$padding}$/'=' x $padding/e if $padding;

  # break encoded string into lines of no more than 60 characters each
  if (length $eol) {
    $res =~ s/(.{1,60})/$1$eol/g;
  }

  $main::lxdebug->leave_sub();

  return $res;
}

sub recode {
  my $self = shift;
  my $text = shift;

  return $::locale->is_utf8 ? Encode::encode('utf-8-strict', $text) : $text;
}

1;

