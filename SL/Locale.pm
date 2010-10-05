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

use DateTime;
use Encode;
use List::Util qw(first);
use List::MoreUtils qw(any);

use SL::LXDebug;
use SL::Common;
use SL::Iconv;
use SL::Inifile;

use strict;

my %locales_by_country;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $country) = @_;

  $country ||= $::language;
  $country   =~ s|.*/||;
  $country   =~ s|\.||g;

  if (!$locales_by_country{$country}) {
    my $self = {};
    bless $self, $type;

    $self->_init($country);

    $locales_by_country{$country} = $self;
  }

  $main::lxdebug->leave_sub();

  return $locales_by_country{$country}
}

sub _init {
  my $self     = shift;
  my $country  = shift;

  $self->{charset}     = Common::DEFAULT_CHARSET;
  $self->{countrycode} = $country;

  if ($country && -d "locale/$country") {
    local *IN;
    if (open(IN, "<", "locale/$country/all")) {
      my $code = join("", <IN>);
      eval($code);
      close(IN);
    }

    if (open IN, "<", "locale/$country/charset") {
      $self->{charset} = <IN>;
      close IN;

      chomp $self->{charset};
    }
  }

  my $db_charset            = $main::dbcharset || Common::DEFAULT_CHARSET;
  $self->{is_utf8}          = (any { lc($::dbcharset || '') eq $_ } qw(utf8 utf-8 unicode)) ? 1 : 0;

  if ($self->{is_utf8}) {
    binmode STDOUT, ":utf8";
    binmode STDERR, ":utf8";
  }

  $self->{iconv}            = SL::Iconv->new($self->{charset}, $db_charset);
  $self->{iconv_reverse}    = SL::Iconv->new($db_charset,      $self->{charset});
  $self->{iconv_english}    = SL::Iconv->new('ASCII',          $db_charset);
  $self->{iconv_iso8859}    = SL::Iconv->new('ISO-8859-15',    $db_charset);
  $self->{iconv_to_iso8859} = SL::Iconv->new($db_charset,      'ISO-8859-15');
  $self->{iconv_utf8}       = SL::Iconv->new('UTF-8',          $db_charset);

  $self->_read_special_chars_file($country);

  push @{ $self->{LONG_MONTH} },
    ("January",   "February", "March",    "April",
     "May ",      "June",     "July",     "August",
     "September", "October",  "November", "December");
  push @{ $self->{SHORT_MONTH} },
    (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec));
}

sub is_utf8 {
  my $self   = shift;
  my $handle = shift;
  return $self->{is_utf8} && (!$handle || $handle->is_utf8);
}

sub _handle_markup {
  my $self    = shift;
  my $str     = shift;

  my $escaped = 0;
  my $new_str = '';

  for (my $i = 0; $i < length $str; $i++) {
    my $char = substr $str, $i, 1;

    if ($escaped) {
      if ($char eq 'n') {
        $new_str .= "\n";

      } elsif ($char eq 'r') {
        $new_str .= "\r";

      } elsif ($char eq 's') {
        $new_str .= ' ';

      } elsif ($char eq 'x') {
        $new_str .= chr(hex(substr($str, $i + 1, 2)));
        $i       += 2;

      } else {
        $new_str .= $char;
      }

      $escaped  = 0;

    } elsif ($char eq '\\') {
      $escaped  = 1;

    } else {
      $new_str .= $char;
    }
  }

  return $new_str;
}

sub _read_special_chars_file {
  my $self    = shift;
  my $country = shift;

  if (! -f "locale/$country/special_chars") {
    $self->{special_chars_map} = {};
    return;
  }

  $self->{special_chars_map} = Inifile->new("locale/$country/special_chars", 'verbatim' => 1);

  foreach my $format (keys %{ $self->{special_chars_map} }) {
    next if (($format eq 'FILE') || ($format eq 'ORDER') || (ref $self->{special_chars_map}->{$format} ne 'HASH'));

    if ($format ne lc $format) {
      $self->{special_chars_map}->{lc $format} = $self->{special_chars_map}->{$format};
      delete $self->{special_chars_map}->{$format};
      $format = lc $format;
    }

    my $scmap = $self->{special_chars_map}->{$format};
    my $order = $self->{iconv}->convert($scmap->{order});
    delete $scmap->{order};

    foreach my $key (keys %{ $scmap }) {
      $scmap->{$key} = $self->_handle_markup($self->{iconv}->convert($scmap->{$key}));

      my $new_key    = $self->_handle_markup($self->{iconv}->convert($key));

      if ($key ne $new_key) {
        $scmap->{$new_key} = $scmap->{$key};
        delete $scmap->{$key};
      }
    }

    $self->{special_chars_map}->{"${format}-reverse"}          = { reverse %{ $scmap } };

    $scmap->{order}                                            = [ map { $self->_handle_markup($_) } split m/\s+/, $order ];
    $self->{special_chars_map}->{"${format}-reverse"}->{order} = [ grep { $_ } map { $scmap->{$_} } reverse @{ $scmap->{order} } ];
  }
}

sub text {
  my $self = shift;
  my $text = shift;

  if ($self->{texts}->{$text}) {
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
  my $text_rev      = lc $self->{iconv_reverse}->convert($text);

  if (!$self->{texts_reverse}) {
    $self->{texts_reverse} = { };
    while (my ($original, $translation) = each %{ $self->{texts} }) {
      $original    =  lc $original;
      $original    =~ s/[^a-z0-9]/_/g;
      $original    =~ s/_+/_/g;

      $translation =  lc $translation;
      $translation =~ s/[\s\-]+/_/g;

      $self->{texts_reverse}->{$translation} ||= [ ];
      push @{ $self->{texts_reverse}->{$translation} }, $original;
    }
  }

  my $sub_name;
  $sub_name   = first { defined(&{ "::${_}" }) } @{ $self->{texts_reverse}->{$text_rev} } if $self->{texts_reverse}->{$text_rev};
  $sub_name ||= $text_rev if ($text_rev =~ m/^[a-z][a-z0-9_]+$/) && defined &{ "::${text_rev}" };

  $main::form->error("$text not defined in locale/$self->{countrycode}/all") if !$sub_name;

  $main::lxdebug->leave_sub();

  return $sub_name;
}

sub date {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $date, $longformat) = @_;

  my $longdate  = "";
  my $longmonth = ($longformat) ? 'LONG_MONTH' : 'SHORT_MONTH';

  my ($spc, $yy, $mm, $dd);

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
  my ($spc, $yy, $mm, $dd);

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

sub parse_date_to_object {
  my $self           = shift;
  my ($yy, $mm, $dd) = $self->parse_date(@_);

  return $yy && $mm && $dd ? DateTime->new(year => $yy, month => $mm, day => $dd) : undef;
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
  substr($output_format, $-[0], $+[0] - $-[0]) = $yy;

  $main::lxdebug->leave_sub();

  return $output_format;
}

sub format_date {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my $myconfig = shift;
  my $yy       = shift;
  my $mm       = shift;
  my $dd       = shift;
  my $yy_len   = shift || 4;

  ($yy, $mm, $dd) = ($yy->year, $yy->month, $yy->day) if ref $yy eq 'DateTime';

  $main::lxdebug->leave_sub() and return "" unless $yy && $mm && $dd;

  $yy = $yy % 100 if 2 == $yy_len;

  my $format = ref $myconfig eq '' ? "$myconfig" : $myconfig->{dateformat};
  $format =~ s{ d+ }{ sprintf("%0" . (length($&)) . "d", $dd) }gex;
  $format =~ s{ m+ }{ sprintf("%0" . (length($&)) . "d", $mm) }gex;
  $format =~ s{ y+ }{ sprintf("%0${yy_len}d",            $yy) }gex;

  $main::lxdebug->leave_sub();

  return $format;
}

sub quote_special_chars {
  my $self   = shift;
  my $format = lc shift;
  my $string = shift;

  if ($self->{special_chars_map} && $self->{special_chars_map}->{$format} && $self->{special_chars_map}->{$format}->{order}) {
    my $scmap = $self->{special_chars_map}->{$format};

    map { $string =~ s/\Q${_}\E/$scmap->{$_}/g } @{ $scmap->{order} };
  }

  return $string;
}

sub unquote_special_chars {
  my $self    = shift;
  my $format  = shift;

  return $self->quote_special_chars("${format}-reverse", shift);
}

sub remap_special_chars {
  my $self       = shift;
  my $src_format = shift;
  my $dst_format = shift;

  return $self->quote_special_chars($dst_format, $self->quote_special_chars("${src_format}-reverse", shift));
}

sub raw_io_active {
  my $self = shift;

  return !!$self->{raw_io_active};
}

sub with_raw_io {
  my $self = shift;
  my $fh   = shift;
  my $code = shift;

  $self->{raw_io_active} = 1;
  binmode $fh, ":raw";
  $code->();
  binmode $fh, ":utf8" if $self->is_utf8;
  $self->{raw_io_active} = 0;
}

sub set_numberformat_wo_thousands_separator {
  my $self     = shift;
  my $myconfig = shift || \%::myconfig;

  $self->{saved_numberformat} = $myconfig->{numberformat};
  $myconfig->{numberformat}   =~ s/^1[,\.]/1/;
}

sub restore_numberformat {
  my $self     = shift;
  my $myconfig = shift || \%::myconfig;

  $myconfig->{numberformat} = $self->{saved_numberformat} if $self->{saved_numberformat};
}

1;
