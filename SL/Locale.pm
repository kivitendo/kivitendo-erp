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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
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

  $country ||= $::lx_office_conf{system}->{language};
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

  $self->{countrycode} = $country;

  if ($country && -d "locale/$country") {
    if (open my $in, "<", "locale/$country/all") {
      local $/ = undef;
      my $code = <$in>;
      eval($code);
      close($in);
    }

    if (-d "locale/$country/more") {
      opendir my $dh, "locale/$country/more" or die "can't open locale/$country/more: $!";
      my @files = sort grep -f "locale/$country/more/$_", readdir $dh;
      close $dh;

      for my $file (@files) {
        if (open my $in, "<", "locale/$country/more/$file") {
          local $/ = undef;
          my $code = <$in>;
          eval($code);
          close($in);
          $self->{texts}{$_} = $self->{more_texts}{$_} for keys %{ $self->{more_texts} };
        }
      }
    }
  }

  binmode STDOUT, ":utf8";
  binmode STDERR, ":utf8";

  $self->{iconv}            = SL::Iconv->new('UTF-8',       'UTF-8');
  $self->{iconv_reverse}    = SL::Iconv->new('UTF-8',       'UTF-8');
  $self->{iconv_english}    = SL::Iconv->new('ASCII',       'UTF-8');
  $self->{iconv_iso8859}    = SL::Iconv->new('ISO-8859-15', 'UTF-8');
  $self->{iconv_to_iso8859} = SL::Iconv->new('UTF-8',       'ISO-8859-15');
  $self->{iconv_utf8}       = SL::Iconv->new('UTF-8',       'UTF-8');

  $self->_read_special_chars_file($country);

  push @{ $self->{LONG_MONTH} },
    ("January",   "February", "March",    "April",
     "May ",      "June",     "July",     "August",
     "September", "October",  "November", "December");
  push @{ $self->{SHORT_MONTH} },
    (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec));
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

  return $text->translated if (ref($text) || '') eq 'SL::Locale::String';

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

sub lang_to_locale {
  my ($self, $requested_lang) = @_;

  my $requested_locale;
  $requested_locale = 'de' if $requested_lang =~ m/^_(de|deu|ger)/i;
  $requested_locale = 'en' if $requested_lang =~ m/^_(en|uk|us|gr)/i;
  $requested_locale = 'fr' if $requested_lang =~ m/^_fr/i;
  $requested_locale ||= 'de';

  return $requested_locale;
}

sub findsub {
  $main::lxdebug->enter_sub();

  my ($self, $text) = @_;
  my $text_rev      = lc $self->{iconv_reverse}->convert($text);
  $text_rev         =~ s/[\s\-]+/_/g;

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

  if (!$date) {
    $main::lxdebug->leave_sub();
    return '';
  }

  my $longdate  = "";
  my $longmonth = ($longformat) ? 'LONG_MONTH' : 'SHORT_MONTH';

  my ($spc, $yy, $mm, $dd);

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
    # kivitendo is mainly used in Germany or German speaking countries.
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

  $main::lxdebug->leave_sub();

  return $longdate;
}

sub parse_date {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig, $date, $longformat) = @_;
  my ($spc, $yy, $mm, $dd);

  unless ($date) {
    $main::lxdebug->leave_sub(2);
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

  $_ ||= 0 for ($dd, $mm, $yy);
  $_ *= 1  for ($dd, $mm, $yy);
  $yy = ($yy < 70) ? $yy + 2000 : $yy;
  $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

  $main::lxdebug->leave_sub(2);
  return ($yy, $mm, $dd);
}

sub parse_date_to_object {
  my ($self, $string, %params) = @_;

  return undef if !defined $string;

  return DateTime->today_local                      if lc($string) eq 'today';
  return DateTime->today_local->subtract(days => 1) if lc($string) eq 'yesterday';

  $params{dateformat}        ||= $::myconfig{dateformat}   || 'yy-mm-dd';
  $params{numberformat}      ||= $::myconfig{numberformat} || '1,000.00';
  my $num_separator            = $params{numberformat} =~ m{,\d+$} ? ',' : '.';

  my ($date_str, $time_str)    = split m{\s+}, $string, 2;
  my ($yy, $mm, $dd)           = $self->parse_date(\%params, $date_str);

  my ($hour, $minute, $second) = split m/:/, ($time_str || '');
  $second ||= '0';

  ($second, my $millisecond)   = split quotemeta($num_separator), $second, 2;
  $_ ||= 0 for ($hour, $minute, $millisecond);

  $millisecond                 = substr $millisecond, 0, 3;
  $millisecond                .= '0' x (3 - length $millisecond);

  return undef unless $yy && $mm && $dd;
  return DateTime->new(year => $yy, month => $mm, day => $dd, hour => $hour * 1, minute => $minute * 1, second => $second * 1, nanosecond => $millisecond * 1000000);
}

sub format_date_object_to_time {
  my ($self, $datetime, %params) = @_;

  my $format =  $::myconfig{timeformat} || 'hh:mm';
  $format    =~ s/hh/\%H/;
  $format    =~ s/mm/\%M/;
  $format    =~ s/ss/\%S/;

  return $datetime->strftime($format);
}

sub format_date_object {
  my ($self, $datetime, %params)    = @_;

  my $format             =   $params{dateformat}   || $::myconfig{dateformat}   || 'yyyy-mm-dd';
  my $num_separator      =  ($params{numberformat} || $::myconfig{numberformat} || '1,000.00') =~ m{,\d+$} ? ',' : '.';
  $format                =~ s/yy(?:yy)?/\%Y/;
  $format                =~ s/mm/\%m/;
  $format                =~ s/dd/\%d/;

  my $precision          =  $params{precision} || 'day';
  $precision             =~ s/s$//;
  my %precision_spec_map = (
    millisecond => '%H:%M:%S' . $num_separator . '%3N',
    second      => '%H:%M:%S',
    minute      => '%H:%M',
    hour        => '%H',
  );

  $format .= ' ' . $precision_spec_map{$precision} if $precision_spec_map{$precision};

  return $datetime->strftime($format);
}

sub reformat_date {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig, $date, $output_format, $longformat) = @_;

  $main::lxdebug->leave_sub(2) and return "" unless ($date);

  my ($yy, $mm, $dd) = $self->parse_date($myconfig, $date);

  $output_format =~ /(d+)/;
  substr($output_format, $-[0], $+[0] - $-[0]) =
    sprintf("%0" . (length($1)) . "d", $dd);

  $output_format =~ /(m+)/;
  substr($output_format, $-[0], $+[0] - $-[0]) =
    sprintf("%0" . (length($1)) . "d", $mm);

  $output_format =~ /y+/;
  substr($output_format, $-[0], $+[0] - $-[0]) = $yy;

  $main::lxdebug->leave_sub(2);

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
  $format =~ s{ (d+) }{ sprintf("%0" . (length($1)) . "d", $dd) }gex;
  $format =~ s{ (m+) }{ sprintf("%0" . (length($1)) . "d", $mm) }gex;
  $format =~ s{ (y+) }{ sprintf("%0${yy_len}d",            $yy) }gex;

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
  binmode $fh, ":utf8";
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

sub get_local_time_zone {
  my $self = shift;
  $self->{local_time_zone} ||= DateTime::TimeZone->new(name => 'local');
  return $self->{local_time_zone};
}

sub language_join {
  my ($self, $items, %params) = @_;

  $items               ||= [];
  $params{conjunction} ||= $::locale->text('and');
  my $num                = scalar @{ $items };

  return 0 == $num ? ''
       : 1 == $num ? $items->[0]
       :             join(', ', @{ $items }[0..$num - 2]) . ' ' . $params{conjunction} . ' ' . $items->[$num - 1];
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Locale - Functions for dealing with locale-dependent information

=head1 SYNOPSIS

  use Locale;
  use DateTime;

  my $locale = Locale->new('de');
  my $now    = DateTime->now_local;
  print "Current date and time: ", $::locale->format_date_object($now, precision => 'second'), "\n";

=head1 OVERVIEW

TODO: write overview

=head1 FUNCTIONS

=over 4

=item C<date>

TODO: Describe date

=item C<findsub>

TODO: Describe findsub

=item C<format_date>

TODO: Describe format_date

=item C<format_date_object $datetime, %params>

Formats the C<$datetime> object according to the user's locale setting.

The parameter C<precision> can control whether or not the time
component is formatted as well:

=over 4

=item * C<day>

Only format the year, month and day. This is also the default.

=item * C<hour>

Add the hour to the date.

=item * C<minute>

Add hour:minute to the date.

=item * C<second>

Add hour:minute:second to the date.

=item * C<millisecond>

Add hour:minute:second.millisecond to the date. The decimal separator
is derived from the number format.

=item * C<numberformat>

The number format to use, e.g. C<1,000.00>. If unset the user's
current number format is used.

=item * C<dateformat>

The date format to use, e.g. C<mm/dd/yy>. If unset the user's current
date format is used.

=back

=item C<get_local_time_zone>

TODO: Describe get_local_time_zone

=item C<lang_to_locale>

TODO: Describe lang_to_locale

=item C<new>

TODO: Describe new

=item C<parse_date>

TODO: Describe parse_date

=item C<parse_date_to_object $string, %params>

Parses a date and optional timestamp in C<$string> and returns an
instance of L<DateTime>. The date and number formats used are the ones
the user has currently selected. They can be overriden by passing them
in as parameters to this function, though.

The time stamps can have up to millisecond precision.

=item C<quote_special_chars>

TODO: Describe quote_special_chars

=item C<raw_io_active>

TODO: Describe raw_io_active

=item C<reformat_date>

TODO: Describe reformat_date

=item C<remap_special_chars>

TODO: Describe remap_special_chars

=item C<restore_numberformat>

TODO: Describe restore_numberformat

=item C<set_numberformat_wo_thousands_separator>

TODO: Describe set_numberformat_wo_thousands_separator

=item C<text>

TODO: Describe text

=item C<unquote_special_chars>

TODO: Describe unquote_special_chars

=item C<with_raw_io>

TODO: Describe with_raw_io

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
