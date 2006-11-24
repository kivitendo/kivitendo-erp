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

sub new {
  $main::lxdebug->enter_sub();

  my ($type) = @_;
  my $self = {};

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

sub send {
  $main::lxdebug->enter_sub();

  my ($self, $out) = @_;

  my $boundary = time;
  $boundary = "LxOffice-$self->{version}-$boundary";
  my $domain = $self->{from};
  $domain =~ s/(.*?\@|>)//g;
  my $msgid = "$boundary\@$domain";

  $self->{charset} = "ISO-8859-1" unless $self->{charset};

  if ($out) {
    if (!open(OUT, $out)) {
      $main::lxdebug->leave_sub();
      return "$out : $!";
    }
  } else {
    if (!open(OUT, ">-")) {
      $main::lxdebug->leave_sub();
      return "STDOUT : $!";
    }
  }

  $self->{contenttype} = "text/plain" unless $self->{contenttype};

  my ($cc, $bcc);
  $cc  = "Cc: $self->{cc}\n"   if $self->{cc};
  $bcc = "Bcc: $self->{bcc}\n" if $self->{bcc};

  foreach my $item (qw(to cc bcc)) {
    $self->{$item} =~ s/\&lt;/</g;
    $self->{$item} =~ s/\$<\$/</g;
    $self->{$item} =~ s/\&gt;/>/g;
    $self->{$item} =~ s/\$>\$/>/g;
  }

  print OUT qq|From: $self->{from}
To: $self->{to}
${cc}${bcc}Subject: $self->{subject}
Message-ID: <$msgid>
X-Mailer: Lx-Office $self->{version}
MIME-Version: 1.0
|;

  if ($self->{attachments}) {
    print OUT qq|Content-Type: multipart/mixed; boundary="$boundary"

|;
    if ($self->{message}) {
      print OUT qq|--${boundary}
Content-Type: $self->{contenttype}; charset="$self->{charset}"

$self->{message}

|;
    }

    foreach my $attachment (@{ $self->{attachments} }) {

      my $application =
        ($attachment =~ /(^\w+$)|\.(html|text|txt|sql)$/)
        ? "text"
        : "application";

      open(IN, $attachment);
      if ($?) {
        close(OUT);
        $main::lxdebug->leave_sub();
        return "$attachment : $!";
      }

      my $filename = $attachment;

      # strip path
      $filename =~ s/(.*\/|$self->{fileid})//g;

      print OUT qq|--${boundary}
Content-Type: $application/$self->{format}; name="$filename"; charset="$self->{charset}"
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

$self->{message}
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

1;

