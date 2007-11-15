#====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
# Contributors: Thomas Bayen <bayen@gmx.de>
#               Antti Kaihola <akaihola@siba.fi>
#               Moritz Bunkus (tex code)
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
#
# Translations and number/date formatting
#
#======================================================================

package Locale;

use Text::Iconv;

use SL::LXDebug;
use SL::Common;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $country, $NLS_file) = @_;
  my $self = {};

  $country  =~ s|.*/||;
  $country  =~ s|\.||g;
  $NLS_file =~ s|.*/||;

  if ($country && -d "locale/$country") {
    local *IN;
    $self->{countrycode} = $country;
    if (open(IN, "<", "locale/$country/$NLS_file")) {
      my $code = join("", <IN>);
      eval($code);
      close(IN);
    }

    if (open IN, "<", "locale/$country/charset") {
      $self->{charset} = <IN>;
      close IN;

      chomp $self->{charset};

    } else {
      $self->{charset} = Common::DEFAULT_CHARSET;
    }

    my $db_charset         = $main::dbcharset || Common::DEFAULT_CHARSET;

    $self->{iconv}         = Text::Iconv->new($self->{charset}, $db_charset);
    $self->{iconv_english} = Text::Iconv->new('ASCII',          $db_charset);
    $self->{iconv_iso8859} = Text::Iconv->new('ISO-8859-15',    $db_charset);
  }

  $self->{NLS_file} = $NLS_file;

  push @{ $self->{LONG_MONTH} },
    ("January",   "February", "March",    "April",
     "May ",      "June",     "July",     "August",
     "September", "October",  "November", "December");
  push @{ $self->{SHORT_MONTH} },
    (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec));

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

sub text {
  my $self = shift;
  my $text = shift;

  if (exists $self->{texts}->{$text}) {
    $text = $self->{iconv}->convert($self->{texts}->{$text});
  } else {
    $text = $self->{iconv_english}->convert($text);
  }

  if (@_) {
    $text = Form->format_string($text, @_);
  }

  return $text;
}

sub findsub {
  $main::lxdebug->enter_sub();

  my ($self, $text) = @_;

  if (exists $self->{subs}{$text}) {
    $text = $self->{subs}{$text};
  } else {
    if ($self->{countrycode} && $self->{NLS_file}) {
      Form->error(
         "$text not defined in locale/$self->{countrycode}/$self->{NLS_file}");
    }
  }

  $main::lxdebug->leave_sub();

  return $text;
}

sub date {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $date, $longformat) = @_;

  my $longdate  = "";
  my $longmonth = ($longformat) ? 'LONG_MONTH' : 'SHORT_MONTH';

  if ($date) {

    # get separator
    $spc = $myconfig->{dateformat};
    $spc =~ s/\w//g;
    $spc = substr($spc, 1, 1);

    if ($date =~ /\D/) {
      if ($myconfig->{dateformat} =~ /^yy/) {
        ($yy, $mm, $dd) = split /\D/, $date;
      }
      if ($myconfig->{dateformat} =~ /^mm/) {
        ($mm, $dd, $yy) = split /\D/, $date;
      }
      if ($myconfig->{dateformat} =~ /^dd/) {
        ($dd, $mm, $yy) = split /\D/, $date;
      }
    } else {
      $date = substr($date, 2);
      ($yy, $mm, $dd) = ($date =~ /(..)(..)(..)/);
    }

    $dd *= 1;
    $mm--;
    $yy = ($yy < 70) ? $yy + 2000 : $yy;
    $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

    if ($myconfig->{dateformat} =~ /^dd/) {
      if (defined $longformat && $longformat == 0) {
        $mm++;
        $dd = "0$dd" if ($dd < 10);
        $mm = "0$mm" if ($mm < 10);
        $longdate = "$dd$spc$mm$spc$yy";
      } else {
        $longdate = "$dd";
        $longdate .= ($spc eq '.') ? ". " : " ";
        $longdate .= &text($self, $self->{$longmonth}[$mm]) . " $yy";
      }
    } elsif ($myconfig->{dateformat} eq "yyyy-mm-dd") {

      # Use German syntax with the ISO date style "yyyy-mm-dd" because
      # Lx-Office is mainly used in Germany or German speaking countries.
      if (defined $longformat && $longformat == 0) {
        $mm++;
        $dd = "0$dd" if ($dd < 10);
        $mm = "0$mm" if ($mm < 10);
        $longdate = "$yy-$mm-$dd";
      } else {
        $longdate = "$dd. ";
        $longdate .= &text($self, $self->{$longmonth}[$mm]) . " $yy";
      }
    } else {
      if (defined $longformat && $longformat == 0) {
        $mm++;
        $dd = "0$dd" if ($dd < 10);
        $mm = "0$mm" if ($mm < 10);
        $longdate = "$mm$spc$dd$spc$yy";
      } else {
        $longdate = &text($self, $self->{$longmonth}[$mm]) . " $dd, $yy";
      }
    }

  }

  $main::lxdebug->leave_sub();

  return $longdate;
}

sub parse_date {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $date, $longformat) = @_;

  unless ($date) {
    $main::lxdebug->leave_sub();
    return ();
  }

  # get separator
  $spc = $myconfig->{dateformat};
  $spc =~ s/\w//g;
  $spc = substr($spc, 1, 1);

  if ($date =~ /\D/) {
    if ($myconfig->{dateformat} =~ /^yy/) {
      ($yy, $mm, $dd) = split /\D/, $date;
    } elsif ($myconfig->{dateformat} =~ /^mm/) {
      ($mm, $dd, $yy) = split /\D/, $date;
    } elsif ($myconfig->{dateformat} =~ /^dd/) {
      ($dd, $mm, $yy) = split /\D/, $date;
    }
  } else {
    $date = substr($date, 2);
    ($yy, $mm, $dd) = ($date =~ /(..)(..)(..)/);
  }

  $dd *= 1;
  $mm *= 1;
  $yy = ($yy < 70) ? $yy + 2000 : $yy;
  $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

  $main::lxdebug->leave_sub();
  return ($yy, $mm, $dd);
}

sub reformat_date {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $date, $output_format, $longformat) = @_;

  $main::lxdebug->leave_sub() and return "" unless ($date);

  my ($yy, $mm, $dd) = $self->parse_date($myconfig, $date);

  $output_format =~ /d+/;
  substr($output_format, $-[0], $+[0] - $-[0]) =
    sprintf("%0" . (length($&)) . "d", $dd);

  $output_format =~ /m+/;
  substr($output_format, $-[0], $+[0] - $-[0]) =
    sprintf("%0" . (length($&)) . "d", $mm);

  $output_format =~ /y+/;
  if (length($&) == 2) {
    $yy -= $yy >= 2000 ? 2000 : 1900;
  }
  substr($output_format, $-[0], $+[0] - $-[0]) =
    sprintf("%0" . (length($&)) . "d", $yy);

  $main::lxdebug->leave_sub();

  return $output_format;
}

1;
