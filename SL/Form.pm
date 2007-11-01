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
# Utilities for parsing forms
# and supporting routines for linking account numbers
# used in AR, AP and IS, IR modules
#
#======================================================================

package Form;
use Data::Dumper;

use Cwd;
use Template;
use SL::Template;
use CGI::Ajax;
use SL::DBUtils;
use SL::Mailer;
use SL::Menu;
use SL::User;
use SL::Common;
use CGI;
use List::Util qw(max min sum);

my $standard_dbh;

sub DESTROY {
  if ($standard_dbh) {
    $standard_dbh->disconnect();
    undef $standard_dbh;
  }
}

sub _input_to_hash {
  $main::lxdebug->enter_sub(2);

  my $input = $_[0];
  my %in    = ();
  my @pairs = split(/&/, $input);

  foreach (@pairs) {
    my ($name, $value) = split(/=/, $_, 2);
    $in{$name} = unescape(undef, $value);
  }

  $main::lxdebug->leave_sub(2);

  return %in;
}

sub _request_to_hash {
  $main::lxdebug->enter_sub(2);

  my ($input) = @_;

  if (!$ENV{'CONTENT_TYPE'}
      || ($ENV{'CONTENT_TYPE'} !~ /multipart\/form-data\s*;\s*boundary\s*=\s*(.+)$/)) {
    $main::lxdebug->leave_sub(2);
    return _input_to_hash($input);
  }

  my ($name, $filename, $headers_done, $content_type, $boundary_found, $need_cr);
  my %params;

  my $boundary = '--' . $1;

  foreach my $line (split m/\n/, $input) {
    last if (($line eq "${boundary}--") || ($line eq "${boundary}--\r"));

    if (($line eq $boundary) || ($line eq "$boundary\r")) {
      $params{$name} =~ s|\r?\n$|| if $name;

      undef $name;
      undef $filename;

      $headers_done   = 0;
      $content_type   = "text/plain";
      $boundary_found = 1;
      $need_cr        = 0;

      next;
    }

    next unless $boundary_found;

    if (!$headers_done) {
      $line =~ s/[\r\n]*$//;

      if (!$line) {
        $headers_done = 1;
        next;
      }

      if ($line =~ m|^content-disposition\s*:.*?form-data\s*;|i) {
        if ($line =~ m|filename\s*=\s*"(.*?)"|i) {
          $filename = $1;
          substr $line, $-[0], $+[0] - $-[0], "";
        }

        if ($line =~ m|name\s*=\s*"(.*?)"|i) {
          $name = $1;
          substr $line, $-[0], $+[0] - $-[0], "";
        }

        $params{$name}    = "";
        $params{FILENAME} = $filename if ($filename);

        next;
      }

      if ($line =~ m|^content-type\s*:\s*(.*?)$|i) {
        $content_type = $1;
      }

      next;
    }

    next unless $name;

    $params{$name} .= "${line}\n";
  }

  $params{$name} =~ s|\r?\n$|| if $name;

  $main::lxdebug->leave_sub(2);
  return %params;
}

sub new {
  $main::lxdebug->enter_sub();

  my $type = shift;

  my $self = {};

  if ($LXDebug::watch_form) {
    require SL::Watchdog;
    tie %{ $self }, 'SL::Watchdog';
  }

  read(STDIN, $_, $ENV{CONTENT_LENGTH});

  if ($ENV{QUERY_STRING}) {
    $_ = $ENV{QUERY_STRING};
  }

  if ($ARGV[0]) {
    $_ = $ARGV[0];
  }

  my %parameters = _request_to_hash($_);
  map({ $self->{$_} = $parameters{$_}; } keys(%parameters));

  $self->{action} = lc $self->{action};
  $self->{action} =~ s/( |-|,|\#)/_/g;

  $self->{version}   = "2.4.3";

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

sub debug {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  print "\n";

  map { print "$_ = $self->{$_}\n" } (sort keys %{$self});

  $main::lxdebug->leave_sub();
}

sub escape {
  $main::lxdebug->enter_sub(2);

  my ($self, $str) = @_;

  $str =~ s/([^a-zA-Z0-9_.-])/sprintf("%%%02x", ord($1))/ge;

  $main::lxdebug->leave_sub(2);

  return $str;
}

sub unescape {
  $main::lxdebug->enter_sub(2);

  my ($self, $str) = @_;

  $str =~ tr/+/ /;
  $str =~ s/\\$//;

  $str =~ s/%([0-9a-fA-Z]{2})/pack("c",hex($1))/eg;

  $main::lxdebug->leave_sub(2);

  return $str;
}

sub quote {
  my ($self, $str) = @_;

  if ($str && !ref($str)) {
    $str =~ s/\"/&quot;/g;
  }

  $str;

}

sub unquote {
  my ($self, $str) = @_;

  if ($str && !ref($str)) {
    $str =~ s/&quot;/\"/g;
  }

  $str;

}

sub quote_html {
  $main::lxdebug->enter_sub(2);

  my ($self, $str) = @_;

  my %replace =
    ('order' => ['"', '<', '>'],
     '<'             => '&lt;',
     '>'             => '&gt;',
     '"'             => '&quot;',
    );

  map({ $str =~ s/$_/$replace{$_}/g; } @{ $replace{"order"} });

  $main::lxdebug->leave_sub(2);

  return $str;
}

sub hide_form {
  my $self = shift;

  if (@_) {
    map({ print($main::cgi->hidden("-name" => $_, "-default" => $self->{$_}) . "\n"); } @_);
  } else {
    for (sort keys %$self) {
      next if (($_ eq "header") || (ref($self->{$_}) ne ""));
      print($main::cgi->hidden("-name" => $_, "-default" => $self->{$_}) . "\n");
    }
  }

}

sub error {
  $main::lxdebug->enter_sub();

  $main::lxdebug->show_backtrace();

  my ($self, $msg) = @_;
  if ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;
    $self->show_generic_error($msg);

  } else {

    die "Error: $msg\n";
  }

  $main::lxdebug->leave_sub();
}

sub info {
  $main::lxdebug->enter_sub();

  my ($self, $msg) = @_;

  if ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;

    if (!$self->{header}) {
      $self->header;
      print qq|
      <body>|;
    }

    print qq|

    <p><b>$msg</b>
    |;

  } else {

    if ($self->{info_function}) {
      &{ $self->{info_function} }($msg);
    } else {
      print "$msg\n";
    }
  }

  $main::lxdebug->leave_sub();
}

# calculates the number of rows in a textarea based on the content and column number
# can be capped with maxrows
sub numtextrows {
  $main::lxdebug->enter_sub();
  my ($self, $str, $cols, $maxrows) = @_;

  my $rows   = sum map { int((length() - 2) / $cols) + 1 } split /\r/, $str;
  $maxrows ||= $rows;

  $main::lxdebug->leave_sub();
  return min $rows, $maxrows;
}

sub dberror {
  $main::lxdebug->enter_sub();

  my ($self, $msg) = @_;

  $self->error("$msg\n" . $DBI::errstr);

  $main::lxdebug->leave_sub();
}

sub isblank {
  $main::lxdebug->enter_sub();

  my ($self, $name, $msg) = @_;

  if ($self->{$name} =~ /^\s*$/) {
    $self->error($msg);
  }
  $main::lxdebug->leave_sub();
}

sub header {
  $main::lxdebug->enter_sub();

  my ($self, $extra_code) = @_;

  if ($self->{header}) {
    $main::lxdebug->leave_sub();
    return;
  }

  my ($stylesheet, $favicon);

  if ($ENV{HTTP_USER_AGENT}) {
    my $doctype;

    if ($ENV{'HTTP_USER_AGENT'} =~ m/MSIE\s+\d/) {
      # Only set the DOCTYPE for Internet Explorer. Other browsers have problems displaying the menu otherwise.
      $doctype = qq|<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">\n|;
    }

    my $stylesheets = "$self->{stylesheet} $self->{stylesheets}";

    $stylesheets =~ s|^\s*||;
    $stylesheets =~ s|\s*$||;
    foreach my $file (split m/\s+/, $stylesheets) {
      $file =~ s|.*/||;
      next if (! -f "css/$file");

      $stylesheet .= qq|<link rel="stylesheet" href="css/$file" TYPE="text/css" TITLE="Lx-Office stylesheet">\n|;
    }

    $self->{favicon}    = "favicon.ico" unless $self->{favicon};

    if ($self->{favicon} && (-f "$self->{favicon}")) {
      $favicon =
        qq|<LINK REL="shortcut icon" HREF="$self->{favicon}" TYPE="image/x-icon">
  |;
    }

    my $db_charset = $main::dbcharset ? $main::dbcharset : Common::DEFAULT_CHARSET;

    if ($self->{landscape}) {
      $pagelayout = qq|<style type="text/css">
                        \@page { size:landscape; }
                        </style>|;
    }

    my $fokus = qq|  document.$self->{fokus}.focus();| if ($self->{"fokus"});

    #Set Calendar
    my $jsscript = "";
    if ($self->{jsscript} == 1) {

      $jsscript = qq|
        <style type="text/css">\@import url(js/jscalendar/calendar-win2k-1.css);</style>
        <script type="text/javascript" src="js/jscalendar/calendar.js"></script>
        <script type="text/javascript" src="js/jscalendar/lang/calendar-de.js"></script>
        <script type="text/javascript" src="js/jscalendar/calendar-setup.js"></script>
        $self->{javascript}
       |;
    }

    $self->{titlebar} =
      ($self->{title})
      ? "$self->{title} - $self->{titlebar}"
      : $self->{titlebar};
    my $ajax = "";
    foreach $item (@ { $self->{AJAX} }) {
      $ajax .= $item->show_javascript();
    }
    print qq|Content-Type: text/html; charset=${db_charset};

${doctype}<html>
<head>
  <title>$self->{titlebar}</title>
  $stylesheet
  $pagelayout
  $favicon
  <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=${db_charset}">
  $jsscript
  $ajax

  <script type="text/javascript">
  <!--
    function fokus() {
      $fokus
    }
  //-->
  </script>

  <meta name="robots" content="noindex,nofollow" />
  <script type="text/javascript" src="js/highlight_input.js"></script>
  <link rel="stylesheet" type="text/css" href="css/tabcontent.css" />

  <script type="text/javascript" src="js/tabcontent.js">

  /***********************************************
  * Tab Content script- Dynamic Drive DHTML code library (www.dynamicdrive.com)
  * This notice MUST stay intact for legal use
  * Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code
  ***********************************************/

  </script>

  $extra_code
</head>

|;
  }
  $self->{header} = 1;

  $main::lxdebug->leave_sub();
}

sub _prepare_html_template {
  $main::lxdebug->enter_sub();

  my ($self, $file, $additional_params) = @_;
  my $language;

  if (!defined(%main::myconfig) || !defined($main::myconfig{"countrycode"})) {
    $language = $main::language;
  } else {
    $language = $main::myconfig{"countrycode"};
  }
  $language = "de" unless ($language);

  if (-f "templates/webpages/${file}_${language}.html") {
    if ((-f ".developer") &&
        (-f "templates/webpages/${file}_master.html") &&
        ((stat("templates/webpages/${file}_master.html"))[9] >
         (stat("templates/webpages/${file}_${language}.html"))[9])) {
      my $info = "Developer information: templates/webpages/${file}_master.html is newer than the localized version.\n" .
        "Please re-run 'locales.pl' in 'locale/${language}'.";
      print(qq|<pre>$info</pre>|);
      die($info);
    }

    $file = "templates/webpages/${file}_${language}.html";
  } elsif (-f "templates/webpages/${file}.html") {
    $file = "templates/webpages/${file}.html";
  } else {
    my $info = "Web page template '${file}' not found.\n" .
      "Please re-run 'locales.pl' in 'locale/${language}'.";
    print(qq|<pre>$info</pre>|);
    die($info);
  }

  if ($self->{"DEBUG"}) {
    $additional_params->{"DEBUG"} = $self->{"DEBUG"};
  }

  if ($additional_params->{"DEBUG"}) {
    $additional_params->{"DEBUG"} =
      "<br><em>DEBUG INFORMATION:</em><pre>" . $additional_params->{"DEBUG"} . "</pre>";
  }

  if (%main::myconfig) {
    map({ $additional_params->{"myconfig_${_}"} = $main::myconfig{$_}; } keys(%main::myconfig));
    my $jsc_dateformat = $main::myconfig{"dateformat"};
    $jsc_dateformat =~ s/d+/\%d/gi;
    $jsc_dateformat =~ s/m+/\%m/gi;
    $jsc_dateformat =~ s/y+/\%Y/gi;
    $additional_params->{"myconfig_jsc_dateformat"} = $jsc_dateformat;
  }

  $additional_params->{"conf_webdav"}                 = $main::webdav;
  $additional_params->{"conf_lizenzen"}               = $main::lizenzen;
  $additional_params->{"conf_latex_templates"}        = $main::latex;
  $additional_params->{"conf_opendocument_templates"} = $main::opendocument_templates;

  if (%main::debug_options) {
    map { $additional_params->{'DEBUG_' . uc($_)} = $main::debug_options{$_} } keys %main::debug_options;
  }

  $main::lxdebug->leave_sub();

  return $file;
}

sub parse_html_template {
  $main::lxdebug->enter_sub();

  my ($self, $file, $additional_params) = @_;

  $additional_params ||= { };

  $file = $self->_prepare_html_template($file, $additional_params);

  my $template = Template->new({ 'INTERPOLATE' => 0,
                                 'EVAL_PERL'   => 0,
                                 'ABSOLUTE'    => 1,
                                 'CACHE_SIZE'  => 0,
                                 'PLUGIN_BASE' => 'SL::Template::Plugin',
                               }) || die;

  map { $additional_params->{$_} ||= $self->{$_} } keys %{ $self };

  my $output;
  if (!$template->process($file, $additional_params, \$output)) {
    print STDERR $template->error();
  }

  $output = $main::locale->{iconv}->convert($output) if ($main::locale);

  $main::lxdebug->leave_sub();

  return $output;
}

sub show_generic_error {
  my ($self, $error, $title, $action) = @_;

  my $add_params = {
    'title_error' => $title,
    'label_error' => $error,
  };

  my @vars;
  if ($action) {
    map({ delete($self->{$_}); } qw(action));
    map({ push(@vars, { "name" => $_, "value" => $self->{$_} })
            if (!ref($self->{$_})); }
        keys(%{$self}));
    $add_params->{"SHOW_BUTTON"} = 1;
    $add_params->{"BUTTON_LABEL"} = $action;
  }
  $add_params->{"VARIABLES"} = \@vars;

  $self->{title} = $title if ($title);

  $self->header();
  print $self->parse_html_template("generic/error", $add_params);

  die("Error: $error\n");
}

sub show_generic_information {
  my ($self, $text, $title) = @_;

  my $add_params = {
    'title_information' => $title,
    'label_information' => $text,
  };

  $self->{title} = $title if ($title);

  $self->header();
  print $self->parse_html_template("generic/information", $add_params);

  die("Information: $error\n");
}

# write Trigger JavaScript-Code ($qty = quantity of Triggers)
# changed it to accept an arbitrary number of triggers - sschoeling
sub write_trigger {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my $myconfig = shift;
  my $qty      = shift;

  # set dateform for jsscript
  # default
  my %dateformats = (
    "dd.mm.yy" => "%d.%m.%Y",
    "dd-mm-yy" => "%d-%m-%Y",
    "dd/mm/yy" => "%d/%m/%Y",
    "mm/dd/yy" => "%m/%d/%Y",
    "mm-dd-yy" => "%m-%d-%Y",
    "yyyy-mm-dd" => "%Y-%m-%d",
    );

  my $ifFormat = defined($dateformats{$myconfig{"dateformat"}}) ?
    $dateformats{$myconfig{"dateformat"}} : "%d.%m.%Y";

  my @triggers;
  while ($#_ >= 2) {
    push @triggers, qq|
       Calendar.setup(
      {
      inputField : "| . (shift) . qq|",
      ifFormat :"$ifFormat",
      align : "| .  (shift) . qq|",
      button : "| . (shift) . qq|"
      }
      );
       |;
  }
  my $jsscript = qq|
       <script type="text/javascript">
       <!--| . join("", @triggers) . qq|//-->
        </script>
        |;

  $main::lxdebug->leave_sub();

  return $jsscript;
}    #end sub write_trigger

sub redirect {
  $main::lxdebug->enter_sub();

  my ($self, $msg) = @_;

  if ($self->{callback}) {

    ($script, $argv) = split(/\?/, $self->{callback}, 2);
    $script =~ s|.*/||;
    $script =~ s|[^a-zA-Z0-9_\.]||g;
    exec("perl", "$script", $argv);

  } else {

    $self->info($msg);
    exit;
  }

  $main::lxdebug->leave_sub();
}

# sort of columns removed - empty sub
sub sort_columns {
  $main::lxdebug->enter_sub();

  my ($self, @columns) = @_;

  $main::lxdebug->leave_sub();

  return @columns;
}
#
sub format_amount {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig, $amount, $places, $dash) = @_;

  if ($amount eq "") {
    $amount = 0;
  }
  
  # Hey watch out! The amount can be an exponential term like 1.13686837721616e-13
  
  my $neg = ($amount =~ s/^-//);
  my $exp = ($amount =~ m/[e]/) ? 1 : 0;
  
  if (defined($places) && ($places ne '')) {
    if (not $exp) {
      if ($places < 0) {
        $amount *= 1;
        $places *= -1;

        my ($actual_places) = ($amount =~ /\.(\d+)/);
        $actual_places = length($actual_places);
        $places = $actual_places > $places ? $actual_places : $places;
      }
    }
    $amount = $self->round_amount($amount, $places);
  }

  my @d = map { s/\d//g; reverse split // } my $tmp = $myconfig->{numberformat}; # get delim chars
  my @p = split(/\./, $amount); # split amount at decimal point

  $p[0] =~ s/\B(?=(...)*$)/$d[1]/g if $d[1]; # add 1,000 delimiters

  $amount = $p[0];
  $amount .= $d[0].$p[1].(0 x ($places - length $p[1])) if ($places || $p[1] ne '');

  $amount = do {
    ($dash =~ /-/)    ? ($neg ? "($amount)"  : "$amount" )    :
    ($dash =~ /DRCR/) ? ($neg ? "$amount DR" : "$amount CR" ) :
                        ($neg ? "-$amount"   : "$amount" )    ;
  };


  $main::lxdebug->leave_sub(2);
  return $amount;
}
#

sub format_string {
  $main::lxdebug->enter_sub(2);

  my $self  = shift;
  my $input = shift;

  $input =~ s/(^|[^\#]) \#  (\d+)  /$1$_[$2 - 1]/gx;
  $input =~ s/(^|[^\#]) \#\{(\d+)\}/$1$_[$2 - 1]/gx;
  $input =~ s/\#\#/\#/g;

  $main::lxdebug->leave_sub(2);

  return $input;
}

sub parse_amount {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig, $amount) = @_;

  if (   ($myconfig->{numberformat} eq '1.000,00')
      || ($myconfig->{numberformat} eq '1000,00')) {
    $amount =~ s/\.//g;
    $amount =~ s/,/\./;
  }

  if ($myconfig->{numberformat} eq "1'000.00") {
    $amount =~ s/\'//g;
  }

  $amount =~ s/,//g;

  $main::lxdebug->leave_sub(2);

  return ($amount * 1);
}

sub round_amount {
  $main::lxdebug->enter_sub(2);

  my ($self, $amount, $places) = @_;
  my $round_amount;

  # Rounding like "Kaufmannsrunden"
  # Descr. http://de.wikipedia.org/wiki/Rundung
  # Inspired by
  # http://www.perl.com/doc/FAQs/FAQ/oldfaq-html/Q4.13.html
  # Solves Bug: 189
  # Udo Spallek
  $amount = $amount * (10**($places));
  $round_amount = int($amount + .5 * ($amount <=> 0)) / (10**($places));

  $main::lxdebug->leave_sub(2);

  return $round_amount;

}

sub parse_template {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $userspath) = @_;
  my ($template, $out);

  local (*IN, *OUT);

  $self->{"cwd"} = getcwd();
  $self->{"tmpdir"} = $self->{cwd} . "/${userspath}";

  if ($self->{"format"} =~ /(opendocument|oasis)/i) {
    $template = OpenDocumentTemplate->new($self->{"IN"}, $self, $myconfig, $userspath);
  } elsif ($self->{"format"} =~ /(postscript|pdf)/i) {
    $ENV{"TEXINPUTS"} = ".:" . getcwd() . "/" . $myconfig->{"templates"} . ":" . $ENV{"TEXINPUTS"};
    $template = LaTeXTemplate->new($self->{"IN"}, $self, $myconfig, $userspath);
  } elsif (($self->{"format"} =~ /html/i) ||
           (!$self->{"format"} && ($self->{"IN"} =~ /html$/i))) {
    $template = HTMLTemplate->new($self->{"IN"}, $self, $myconfig, $userspath);
  } elsif (($self->{"format"} =~ /xml/i) ||
             (!$self->{"format"} && ($self->{"IN"} =~ /xml$/i))) {
    $template = XMLTemplate->new($self->{"IN"}, $self, $myconfig, $userspath);
  } elsif ( $self->{"format"} =~ /elsterwinston/i ) {
    $template = XMLTemplate->new($self->{"IN"}, $self, $myconfig, $userspath);
  } elsif ( $self->{"format"} =~ /elstertaxbird/i ) {
    $template = XMLTemplate->new($self->{"IN"}, $self, $myconfig, $userspath);
  } elsif ( defined $self->{'format'}) {
    $self->error("Outputformat not defined. This may be a future feature: $self->{'format'}");
  } elsif ( $self->{'format'} eq '' ) {
    $self->error("No Outputformat given: $self->{'format'}");
  } else { #Catch the rest
    $self->error("Outputformat not defined: $self->{'format'}");
  }

  # Copy the notes from the invoice/sales order etc. back to the variable "notes" because that is where most templates expect it to be.
  $self->{"notes"} = $self->{ $self->{"formname"} . "notes" };

  map({ $self->{"employee_${_}"} = $myconfig->{$_}; }
      qw(email tel fax name signature company address businessnumber
         co_ustid taxnumber duns));
  map({ $self->{"employee_${_}"} =~ s/\\n/\n/g; }
      qw(company address signature));
  map({ $self->{$_} =~ s/\\n/\n/g; } qw(company address signature));

  map({ $self->{"${_}"} = $myconfig->{$_}; }
      qw(co_ustid));
              

  $self->{copies} = 1 if (($self->{copies} *= 1) <= 0);

  # OUT is used for the media, screen, printer, email
  # for postscript we store a copy in a temporary file
  my $fileid = time;
  my $prepend_userspath;

  if (!$self->{tmpfile}) {
    $self->{tmpfile}   = "${fileid}.$self->{IN}";
    $prepend_userspath = 1;
  }

  $prepend_userspath = 1 if substr($self->{tmpfile}, 0, length $userspath) eq $userspath;

  $self->{tmpfile} =~ s|.*/||;
  $self->{tmpfile} =~ s/[^a-zA-Z0-9\._\ \-]//g;
  $self->{tmpfile} = "$userspath/$self->{tmpfile}" if $prepend_userspath;

  if ($template->uses_temp_file() || $self->{media} eq 'email') {
    $out = $self->{OUT};
    $self->{OUT} = ">$self->{tmpfile}";
  }

  if ($self->{OUT}) {
    open(OUT, "$self->{OUT}") or $self->error("$self->{OUT} : $!");
  } else {
    open(OUT, ">-") or $self->error("STDOUT : $!");
    $self->header;
  }

  if (!$template->parse(*OUT)) {
    $self->cleanup();
    $self->error("$self->{IN} : " . $template->get_error());
  }

  close(OUT);

  if ($template->uses_temp_file() || $self->{media} eq 'email') {

    if ($self->{media} eq 'email') {

      my $mail = new Mailer;

      map { $mail->{$_} = $self->{$_} }
        qw(cc bcc subject message version format);
      $mail->{charset} = $main::dbcharset ? $main::dbcharset : Common::DEFAULT_CHARSET;
      $mail->{to} = $self->{EMAIL_RECIPIENT} ? $self->{EMAIL_RECIPIENT} : $self->{email};
      $mail->{from}   = qq|"$myconfig->{name}" <$myconfig->{email}>|;
      $mail->{fileid} = "$fileid.";
      $myconfig->{signature} =~ s/\\r\\n/\\n/g;

      # if we send html or plain text inline
      if (($self->{format} eq 'html') && ($self->{sendmode} eq 'inline')) {
        $mail->{contenttype} = "text/html";

        $mail->{message}       =~ s/\r\n/<br>\n/g;
        $myconfig->{signature} =~ s/\\n/<br>\n/g;
        $mail->{message} .= "<br>\n-- <br>\n$myconfig->{signature}\n<br>";

        open(IN, $self->{tmpfile})
          or $self->error($self->cleanup . "$self->{tmpfile} : $!");
        while (<IN>) {
          $mail->{message} .= $_;
        }

        close(IN);

      } else {

        if (!$self->{"do_not_attach"}) {
          @{ $mail->{attachments} } =
            ({ "filename" => $self->{"tmpfile"},
               "name" => $self->{"attachment_filename"} ?
                 $self->{"attachment_filename"} : $self->{"tmpfile"} });
        }

        $mail->{message}       =~ s/\r\n/\n/g;
        $myconfig->{signature} =~ s/\\n/\n/g;
        $mail->{message} .= "\n-- \n$myconfig->{signature}";

      }

      my $err = $mail->send();
      $self->error($self->cleanup . "$err") if ($err);

    } else {

      $self->{OUT} = $out;

      my $numbytes = (-s $self->{tmpfile});
      open(IN, $self->{tmpfile})
        or $self->error($self->cleanup . "$self->{tmpfile} : $!");

      $self->{copies} = 1 unless $self->{media} eq 'printer';

      chdir("$self->{cwd}");
      #print(STDERR "Kopien $self->{copies}\n");
      #print(STDERR "OUT $self->{OUT}\n");
      for my $i (1 .. $self->{copies}) {
        if ($self->{OUT}) {
          open(OUT, $self->{OUT})
            or $self->error($self->cleanup . "$self->{OUT} : $!");
        } else {
          $self->{attachment_filename} = ($self->{attachment_filename}) 
                                       ? $self->{attachment_filename}
                                       : $self->generate_attachment_filename();

          # launch application
          print qq|Content-Type: | . $template->get_mime_type() . qq|
Content-Disposition: attachment; filename="$self->{attachment_filename}"
Content-Length: $numbytes

|;

          open(OUT, ">-") or $self->error($self->cleanup . "$!: STDOUT");

        }

        while (<IN>) {
          print OUT $_;
        }

        close(OUT);

        seek IN, 0, 0;
      }

      close(IN);
    }

  }

  $self->cleanup;

  chdir("$self->{cwd}");
  $main::lxdebug->leave_sub();
}

sub get_formname_translation {
  my ($self, $formname) = @_;

  $formname ||= $self->{formname};

  my %formname_translations = (
    bin_list            => $main::locale->text('Bin List'),
    credit_note         => $main::locale->text('Credit Note'),
    invoice             => $main::locale->text('Invoice'),
    packing_list        => $main::locale->text('Packing List'),
    pick_list           => $main::locale->text('Pick List'),
    proforma            => $main::locale->text('Proforma Invoice'),
    purchase_order      => $main::locale->text('Purchase Order'),
    request_quotation   => $main::locale->text('RFQ'),
    sales_order         => $main::locale->text('Confirmation'),
    sales_quotation     => $main::locale->text('Quotation'),
    storno_invoice      => $main::locale->text('Storno Invoice'),
    storno_packing_list => $main::locale->text('Storno Packing List'),
  );

  return $formname_translations{$formname}
}

sub generate_attachment_filename {
  my ($self) = @_;

  my $attachment_filename = $self->get_formname_translation();
  my $prefix = 
      (grep { $self->{"type"} eq $_ } qw(invoice credit_note)) ? "inv"
    : ($self->{"type"} =~ /_quotation$/)                       ? "quo"
    :                                                            "ord";

  if ($attachment_filename && $self->{"${prefix}number"}) {
    $attachment_filename .= "_" . $self->{"${prefix}number"}
                            . (  $self->{format} =~ /pdf/i          ? ".pdf"
                               : $self->{format} =~ /postscript/i   ? ".ps"
                               : $self->{format} =~ /opendocument/i ? ".odt"
                               : $self->{format} =~ /html/i         ? ".html"
                               :                                      "");
    $attachment_filename =~ s/ /_/g;
    my %umlaute = ( "ä" => "ae", "ö" => "oe", "ü" => "ue", 
                    "Ä" => "Ae", "Ö" => "Oe", "Ü" => "Ue", "ß" => "ss");
    map { $attachment_filename =~ s/$_/$umlaute{$_}/g } keys %umlaute;
  } else {
    $attachment_filename = "";
  }

  return $attachment_filename;
}

sub cleanup {
  $main::lxdebug->enter_sub();

  my $self = shift;

  chdir("$self->{tmpdir}");

  my @err = ();
  if (-f "$self->{tmpfile}.err") {
    open(FH, "$self->{tmpfile}.err");
    @err = <FH>;
    close(FH);
  }

  if ($self->{tmpfile}) {
    $self->{tmpfile} =~ s|.*/||g;
    # strip extension
    $self->{tmpfile} =~ s/\.\w+$//g;
    my $tmpfile = $self->{tmpfile};
    unlink(<$tmpfile.*>);
  }

  chdir("$self->{cwd}");

  $main::lxdebug->leave_sub();

  return "@err";
}

sub datetonum {
  $main::lxdebug->enter_sub();

  my ($self, $date, $myconfig) = @_;

  if ($date && $date =~ /\D/) {

    if ($myconfig->{dateformat} =~ /^yy/) {
      ($yy, $mm, $dd) = split /\D/, $date;
    }
    if ($myconfig->{dateformat} =~ /^mm/) {
      ($mm, $dd, $yy) = split /\D/, $date;
    }
    if ($myconfig->{dateformat} =~ /^dd/) {
      ($dd, $mm, $yy) = split /\D/, $date;
    }

    $dd *= 1;
    $mm *= 1;
    $yy = ($yy < 70) ? $yy + 2000 : $yy;
    $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

    $dd = "0$dd" if ($dd < 10);
    $mm = "0$mm" if ($mm < 10);

    $date = "$yy$mm$dd";
  }

  $main::lxdebug->leave_sub();

  return $date;
}

# Database routines used throughout

sub dbconnect {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig) = @_;

  # connect to database
  my $dbh =
    DBI->connect($myconfig->{dbconnect},
                 $myconfig->{dbuser}, $myconfig->{dbpasswd})
    or $self->dberror;

  # set db options
  if ($myconfig->{dboptions}) {
    $dbh->do($myconfig->{dboptions}) || $self->dberror($myconfig->{dboptions});
  }

  $main::lxdebug->leave_sub(2);

  return $dbh;
}

sub dbconnect_noauto {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;
  
  # connect to database
  $dbh =
    DBI->connect($myconfig->{dbconnect}, $myconfig->{dbuser},
                 $myconfig->{dbpasswd}, { AutoCommit => 0 })
    or $self->dberror;

  # set db options
  if ($myconfig->{dboptions}) {
    $dbh->do($myconfig->{dboptions}) || $self->dberror($myconfig->{dboptions});
  }

  $main::lxdebug->leave_sub();

  return $dbh;
}

sub get_standard_dbh {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig) = @_;

  $standard_dbh ||= $self->dbconnect_noauto($myconfig);

  $main::lxdebug->leave_sub(2);

  return $standard_dbh;
}

sub update_balance {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $table, $field, $where, $value, @values) = @_;

  # if we have a value, go do it
  if ($value != 0) {

    # retrieve balance from table
    my $query = "SELECT $field FROM $table WHERE $where FOR UPDATE";
    my $sth = prepare_execute_query($self, $dbh, $query, @values);
    my ($balance) = $sth->fetchrow_array;
    $sth->finish;

    $balance += $value;

    # update balance
    $query = "UPDATE $table SET $field = $balance WHERE $where";
    do_query($self, $dbh, $query, @values);
  }
  $main::lxdebug->leave_sub();
}

sub update_exchangerate {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $curr, $transdate, $buy, $sell) = @_;
  my ($query);
  # some sanity check for currency
  if ($curr eq '') {
    $main::lxdebug->leave_sub();
    return;
  }  
  $query = qq|SELECT curr FROM defaults|;

  my ($currency) = selectrow_query($self, $dbh, $query);
  my ($defaultcurrency) = split m/:/, $currency;


  if ($curr eq $defaultcurrency) {
    $main::lxdebug->leave_sub();
    return;
  }

  $query = qq|SELECT e.curr FROM exchangerate e
                 WHERE e.curr = ? AND e.transdate = ?
                 FOR UPDATE|;
  my $sth = prepare_execute_query($self, $dbh, $query, $curr, $transdate);

  if ($buy == 0) {
    $buy = "";
  }
  if ($sell == 0) {
    $sell = "";
  }

  $buy = conv_i($buy, "NULL");
  $sell = conv_i($sell, "NULL");

  my $set;
  if ($buy != 0 && $sell != 0) {
    $set = "buy = $buy, sell = $sell";
  } elsif ($buy != 0) {
    $set = "buy = $buy";
  } elsif ($sell != 0) {
    $set = "sell = $sell";
  }

  if ($sth->fetchrow_array) {
    $query = qq|UPDATE exchangerate
                SET $set
                WHERE curr = ?
                AND transdate = ?|;
    
  } else {
    $query = qq|INSERT INTO exchangerate (curr, buy, sell, transdate)
                VALUES (?, $buy, $sell, ?)|;
  }
  $sth->finish;
  do_query($self, $dbh, $query, $curr, $transdate);

  $main::lxdebug->leave_sub();
}

sub save_exchangerate {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $currency, $transdate, $rate, $fld) = @_;

  my $dbh = $self->dbconnect($myconfig);

  my ($buy, $sell);

  $buy  = $rate if $fld eq 'buy';
  $sell = $rate if $fld eq 'sell';


  $self->update_exchangerate($dbh, $currency, $transdate, $buy, $sell);


  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_exchangerate {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $curr, $transdate, $fld) = @_;
  my ($query);

  unless ($transdate) {
    $main::lxdebug->leave_sub();
    return 1;
  }

  $query = qq|SELECT curr FROM defaults|;

  my ($currency) = selectrow_query($self, $dbh, $query);
  my ($defaultcurrency) = split m/:/, $currency;

  if ($currency eq $defaultcurrency) {
    $main::lxdebug->leave_sub();
    return 1;
  }

  $query = qq|SELECT e.$fld FROM exchangerate e
                 WHERE e.curr = ? AND e.transdate = ?|;
  my ($exchangerate) = selectrow_query($self, $dbh, $query, $curr, $transdate);



  $main::lxdebug->leave_sub();

  return $exchangerate;
}

sub check_exchangerate {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $currency, $transdate, $fld) = @_;

  unless ($transdate) {
    $main::lxdebug->leave_sub();
    return "";
  }

  my ($defaultcurrency) = $self->get_default_currency($myconfig);

  if ($currency eq $defaultcurrency) {
    $main::lxdebug->leave_sub();
    return 1;
  }

  my $dbh   = $self->get_standard_dbh($myconfig);
  my $query = qq|SELECT e.$fld FROM exchangerate e
                 WHERE e.curr = ? AND e.transdate = ?|;

  my ($exchangerate) = selectrow_query($self, $dbh, $query, $currency, $transdate);

  $exchangerate = 1 if ($exchangerate eq "");

  $main::lxdebug->leave_sub();

  return $exchangerate;
}

sub get_default_currency {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;
  my $dbh = $self->get_standard_dbh($myconfig);

  my $query = qq|SELECT curr FROM defaults|;

  my ($curr)            = selectrow_query($self, $dbh, $query);
  my ($defaultcurrency) = split m/:/, $curr;

  $main::lxdebug->leave_sub();

  return $defaultcurrency;
}


sub set_payment_options {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $transdate) = @_;

  return $main::lxdebug->leave_sub() unless ($self->{payment_id});

  my $dbh = $self->get_standard_dbh($myconfig);

  my $query =
    qq|SELECT p.terms_netto, p.terms_skonto, p.percent_skonto, p.description_long | .
    qq|FROM payment_terms p | .
    qq|WHERE p.id = ?|;

  ($self->{terms_netto}, $self->{terms_skonto}, $self->{percent_skonto},
   $self->{payment_terms}) =
     selectrow_query($self, $dbh, $query, $self->{payment_id});

  if ($transdate eq "") {
    if ($self->{invdate}) {
      $transdate = $self->{invdate};
    } else {
      $transdate = $self->{transdate};
    }
  }

  $query =
    qq|SELECT ?::date + ?::integer AS netto_date, ?::date + ?::integer AS skonto_date | .
    qq|FROM payment_terms|;
  ($self->{netto_date}, $self->{skonto_date}) =
    selectrow_query($self, $dbh, $query, $transdate, $self->{terms_netto}, $transdate, $self->{terms_skonto});

  my ($invtotal, $total);
  my (%amounts, %formatted_amounts);

  if ($self->{type} =~ /_order$/) {
    $amounts{invtotal} = $self->{ordtotal};
    $amounts{total}    = $self->{ordtotal};

  } elsif ($self->{type} =~ /_quotation$/) {
    $amounts{invtotal} = $self->{quototal};
    $amounts{total}    = $self->{quototal};

  } else {
    $amounts{invtotal} = $self->{invtotal};
    $amounts{total}    = $self->{total};
  }

  map { $amounts{$_} = $self->parse_amount($myconfig, $amounts{$_}) } keys %amounts;

  $amounts{skonto_amount}      = $amounts{invtotal} * $self->{percent_skonto};
  $amounts{invtotal_wo_skonto} = $amounts{invtotal} * (1 - $self->{percent_skonto});
  $amounts{total_wo_skonto}    = $amounts{total}    * (1 - $self->{percent_skonto});

  foreach (keys %amounts) {
    $amounts{$_}           = $self->round_amount($amounts{$_}, 2);
    $formatted_amounts{$_} = $self->format_amount($myconfig, $amounts{$_}, 2);
  }

  if ($self->{"language_id"}) {
    $query =
      qq|SELECT t.description_long, l.output_numberformat, l.output_dateformat, l.output_longdates | .
      qq|FROM translation_payment_terms t | .
      qq|LEFT JOIN language l ON t.language_id = l.id | .
      qq|WHERE (t.language_id = ?) AND (t.payment_terms_id = ?)|;
    my ($description_long, $output_numberformat, $output_dateformat,
      $output_longdates) =
      selectrow_query($self, $dbh, $query,
                      $self->{"language_id"}, $self->{"payment_id"});

    $self->{payment_terms} = $description_long if ($description_long);

    if ($output_dateformat) {
      foreach my $key (qw(netto_date skonto_date)) {
        $self->{$key} =
          $main::locale->reformat_date($myconfig, $self->{$key},
                                       $output_dateformat,
                                       $output_longdates);
      }
    }

    if ($output_numberformat &&
        ($output_numberformat ne $myconfig->{"numberformat"})) {
      my $saved_numberformat = $myconfig->{"numberformat"};
      $myconfig->{"numberformat"} = $output_numberformat;
      map { $formatted_amounts{$_} = $self->format_amount($myconfig, $amounts{$_}) } keys %amounts;
      $myconfig->{"numberformat"} = $saved_numberformat;
    }
  }

  $self->{payment_terms} =~ s/<%netto_date%>/$self->{netto_date}/g;
  $self->{payment_terms} =~ s/<%skonto_date%>/$self->{skonto_date}/g;
  $self->{payment_terms} =~ s/<%currency%>/$self->{currency}/g;
  $self->{payment_terms} =~ s/<%terms_netto%>/$self->{terms_netto}/g;
  $self->{payment_terms} =~ s/<%account_number%>/$self->{account_number}/g;
  $self->{payment_terms} =~ s/<%bank%>/$self->{bank}/g;
  $self->{payment_terms} =~ s/<%bank_code%>/$self->{bank_code}/g;

  map { $self->{payment_terms} =~ s/<%${_}%>/$formatted_amounts{$_}/g; } keys %formatted_amounts;

  $main::lxdebug->leave_sub();

}

sub get_template_language {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{language_id}) {
    my $dbh = $self->get_standard_dbh($myconfig);
    my $query = qq|SELECT template_code FROM language WHERE id = ?|;
    ($template_code) = selectrow_query($self, $dbh, $query, $self->{language_id});
  }

  $main::lxdebug->leave_sub();

  return $template_code;
}

sub get_printer_code {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{printer_id}) {
    my $dbh = $self->get_standard_dbh($myconfig);
    my $query = qq|SELECT template_code, printer_command FROM printers WHERE id = ?|;
    ($template_code, $self->{printer_command}) = selectrow_query($self, $dbh, $query, $self->{printer_id});
  }

  $main::lxdebug->leave_sub();

  return $template_code;
}

sub get_shipto {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{shipto_id}) {
    my $dbh = $self->get_standard_dbh($myconfig);
    my $query = qq|SELECT * FROM shipto WHERE shipto_id = ?|;
    my $ref = selectfirst_hashref_query($self, $dbh, $query, $self->{shipto_id});
    map({ $self->{$_} = $ref->{$_} } keys(%$ref));
  }

  $main::lxdebug->leave_sub();
}

sub add_shipto {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id, $module) = @_;

  my $shipto;
  my @values;

  foreach my $item (qw(name department_1 department_2 street zipcode city country
                       contact phone fax email)) {
    if ($self->{"shipto$item"}) {
      $shipto = 1 if ($self->{$item} ne $self->{"shipto$item"});
    }
    push(@values, $self->{"shipto${item}"});
  }

  if ($shipto) {
    if ($self->{shipto_id}) {
      my $query = qq|UPDATE shipto set
                       shiptoname = ?,
                       shiptodepartment_1 = ?,
                       shiptodepartment_2 = ?,
                       shiptostreet = ?,
                       shiptozipcode = ?,
                       shiptocity = ?,
                       shiptocountry = ?,
                       shiptocontact = ?,
                       shiptophone = ?,
                       shiptofax = ?,
                       shiptoemail = ?
                     WHERE shipto_id = ?|;
      do_query($self, $dbh, $query, @values, $self->{shipto_id});
    } else {
      my $query = qq|SELECT * FROM shipto
                     WHERE shiptoname = ? AND
                       shiptodepartment_1 = ? AND
                       shiptodepartment_2 = ? AND
                       shiptostreet = ? AND
                       shiptozipcode = ? AND
                       shiptocity = ? AND
                       shiptocountry = ? AND
                       shiptocontact = ? AND
                       shiptophone = ? AND
                       shiptofax = ? AND
                       shiptoemail = ? AND
                       module = ? AND 
                       trans_id = ?|;
      my $insert_check = selectfirst_hashref_query($self, $dbh, $query, @values, $module, $id);
      if(!$insert_check){
        $query =
          qq|INSERT INTO shipto (trans_id, shiptoname, shiptodepartment_1, shiptodepartment_2,
                                 shiptostreet, shiptozipcode, shiptocity, shiptocountry,
                                 shiptocontact, shiptophone, shiptofax, shiptoemail, module)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|;
        do_query($self, $dbh, $query, $id, @values, $module);
      }
    }
  }

  $main::lxdebug->leave_sub();
}

sub get_employee {
  $main::lxdebug->enter_sub();

  my ($self, $dbh) = @_;

  my $query = qq|SELECT id, name FROM employee WHERE login = ?|;
  ($self->{"employee_id"}, $self->{"employee"}) = selectrow_query($self, $dbh, $query, $self->{login});
  $self->{"employee_id"} *= 1;

  $main::lxdebug->leave_sub();
}

sub get_salesman {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $salesman_id) = @_;

  $main::lxdebug->leave_sub() and return unless $salesman_id;

  my $dbh = $self->get_standard_dbh($myconfig);

  my ($login) =
    selectrow_query($self, $dbh, qq|SELECT login FROM employee WHERE id = ?|,
                    $salesman_id);

  if ($login) {
    my $user = new User($main::memberfile, $login);
    map({ $self->{"salesman_$_"} = $user->{$_}; }
        qw(address businessnumber co_ustid company duns email fax name
           taxnumber tel));
    $self->{salesman_login} = $login;

    $self->{salesman_name} = $login
      if ($self->{salesman_name} eq "");

    map({ $self->{"salesman_$_"} =~ s/\\n/\n/g; } qw(address company));
  }

  $main::lxdebug->leave_sub();
}

sub get_duedate {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);
  my $query = qq|SELECT current_date + terms_netto FROM payment_terms WHERE id = ?|;
  ($self->{duedate}) = selectrow_query($self, $dbh, $query, $self->{payment_id});

  $main::lxdebug->leave_sub();
}

sub _get_contacts {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id, $key) = @_;

  $key = "all_contacts" unless ($key);

  my $query =
    qq|SELECT cp_id, cp_cv_id, cp_name, cp_givenname, cp_abteilung | .
    qq|FROM contacts | .
    qq|WHERE cp_cv_id = ? | .
    qq|ORDER BY lower(cp_name)|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query, $id);

  $main::lxdebug->leave_sub();
}

sub _get_projects {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  my ($all, $old_id, $where, @values);

  if (ref($key) eq "HASH") {
    my $params = $key;

    $key = "ALL_PROJECTS";

    foreach my $p (keys(%{$params})) {
      if ($p eq "all") {
        $all = $params->{$p};
      } elsif ($p eq "old_id") {
        $old_id = $params->{$p};
      } elsif ($p eq "key") {
        $key = $params->{$p};
      }
    }
  }

  if (!$all) {
    $where = "WHERE active ";
    if ($old_id) {
      if (ref($old_id) eq "ARRAY") {
        my @ids = grep({ $_ } @{$old_id});
        if (@ids) {
          $where .= " OR id IN (" . join(",", map({ "?" } @ids)) . ") ";
          push(@values, @ids);
        }
      } else {
        $where .= " OR (id = ?) ";
        push(@values, $old_id);
      }
    }
  }

  my $query =
    qq|SELECT id, projectnumber, description, active | .
    qq|FROM project | .
    $where .
    qq|ORDER BY lower(projectnumber)|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

sub _get_shipto {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $vc_id, $key) = @_;

  $key = "all_shipto" unless ($key);

  # get shipping addresses
  my $query = qq|SELECT * FROM shipto WHERE trans_id = ?|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query, $vc_id);

  $main::lxdebug->leave_sub();
}

sub _get_printers {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_printers" unless ($key);

  my $query = qq|SELECT id, printer_description, printer_command, template_code FROM printers|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_charts {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $params) = @_;

  $key = $params->{key};
  $key = "all_charts" unless ($key);

  my $transdate = quote_db_date($params->{transdate});

  my $query =
    qq|SELECT c.id, c.accno, c.description, c.link, tk.taxkey_id, tk.tax_id | .
    qq|FROM chart c | .
    qq|LEFT JOIN taxkeys tk ON | .
    qq|(tk.id = (SELECT id FROM taxkeys | .
    qq|          WHERE taxkeys.chart_id = c.id AND startdate <= $transdate | .
    qq|          ORDER BY startdate DESC LIMIT 1)) | .
    qq|ORDER BY c.accno|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_taxcharts {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_taxcharts" unless ($key);

  my $query = qq|SELECT * FROM tax ORDER BY taxkey|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_taxzones {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_taxzones" unless ($key);

  my $query = qq|SELECT * FROM tax_zones ORDER BY id|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_employees {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $default_key, $key) = @_;

  $key = $default_key unless ($key);
  $self->{$key} = selectall_hashref_query($self, $dbh, qq|SELECT * FROM employee ORDER BY name|);

  $main::lxdebug->leave_sub();
}

sub _get_business_types {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_business_types" unless ($key);
  $self->{$key} =
    selectall_hashref_query($self, $dbh, qq|SELECT * FROM business|);

  $main::lxdebug->leave_sub();
}

sub _get_languages {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_languages" unless ($key);

  my $query = qq|SELECT * FROM language ORDER BY id|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_dunning_configs {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_dunning_configs" unless ($key);

  my $query = qq|SELECT * FROM dunning_config ORDER BY dunning_level|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_currencies {
$main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_currencies" unless ($key);

  my $query = qq|SELECT curr AS currency FROM defaults|;
 
  $self->{$key} = [split(/\:/ , selectfirst_hashref_query($self, $dbh, $query)->{currency})];

  $main::lxdebug->leave_sub();
}

sub _get_payments {
$main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_payments" unless ($key);

  my $query = qq|SELECT * FROM payment_terms ORDER BY id|;
 
  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_customers {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key, $limit) = @_;

  $key = "all_customers" unless ($key);
  $limit_clause = "LIMIT $limit" if $limit;

  my $query = qq|SELECT * FROM customer WHERE NOT obsolete ORDER BY name $limit_clause|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_vendors {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_vendors" unless ($key);

  my $query = qq|SELECT * FROM vendor WHERE NOT obsolete ORDER BY name|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_departments {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key = "all_departments" unless ($key);

  my $query = qq|SELECT * FROM department ORDER BY description|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub _get_price_factors {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $key) = @_;

  $key ||= "all_price_factors";

  my $query = qq|SELECT * FROM price_factors ORDER BY sortkey|;

  $self->{$key} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub get_lists {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my %params = @_;

  my $dbh = $self->get_standard_dbh(\%main::myconfig);
  my ($sth, $query, $ref);

  my $vc = $self->{"vc"} eq "customer" ? "customer" : "vendor";
  my $vc_id = $self->{"${vc}_id"};

  if ($params{"contacts"}) {
    $self->_get_contacts($dbh, $vc_id, $params{"contacts"});
  }

  if ($params{"shipto"}) {
    $self->_get_shipto($dbh, $vc_id, $params{"shipto"});
  }

  if ($params{"projects"} || $params{"all_projects"}) {
    $self->_get_projects($dbh, $params{"all_projects"} ?
                         $params{"all_projects"} : $params{"projects"},
                         $params{"all_projects"} ? 1 : 0);
  }

  if ($params{"printers"}) {
    $self->_get_printers($dbh, $params{"printers"});
  }

  if ($params{"languages"}) {
    $self->_get_languages($dbh, $params{"languages"});
  }

  if ($params{"charts"}) {
    $self->_get_charts($dbh, $params{"charts"});
  }

  if ($params{"taxcharts"}) {
    $self->_get_taxcharts($dbh, $params{"taxcharts"});
  }

  if ($params{"taxzones"}) {
    $self->_get_taxzones($dbh, $params{"taxzones"});
  }

  if ($params{"employees"}) {
    $self->_get_employees($dbh, "all_employees", $params{"employees"});
  }
  
  if ($params{"salesmen"}) {
    $self->_get_employees($dbh, "all_salesmen", $params{"salesmen"});
  }

  if ($params{"business_types"}) {
    $self->_get_business_types($dbh, $params{"business_types"});
  }

  if ($params{"dunning_configs"}) {
    $self->_get_dunning_configs($dbh, $params{"dunning_configs"});
  }
  
  if($params{"currencies"}) {
    $self->_get_currencies($dbh, $params{"currencies"});
  }
  
  if($params{"customers"}) {
    if (ref $params{"customers"} eq 'HASH') {
      $self->_get_customers($dbh, $params{"customers"}{key}, $params{"customers"}{limit});
    } else {
      $self->_get_customers($dbh, $params{"customers"});
    }
  }
  
  if($params{"vendors"}) {
    if (ref $params{"vendors"} eq 'HASH') {
      $self->_get_vendors($dbh, $params{"vendors"}{key}, $params{"vendors"}{limit});
    } else {
      $self->_get_vendors($dbh, $params{"vendors"});
    }
  }
  
  if($params{"payments"}) {
    $self->_get_payments($dbh, $params{"payments"});
  }

  if($params{"departments"}) {
    $self->_get_departments($dbh, $params{"departments"});
  }

  if ($params{price_factors}) {
    $self->_get_price_factors($dbh, $params{price_factors});
  }

  $main::lxdebug->leave_sub();
}

# this sub gets the id and name from $table
sub get_name {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $table) = @_;

  # connect to database
  my $dbh = $self->get_standard_dbh($myconfig);

  $table = $table eq "customer" ? "customer" : "vendor";
  my $arap = $self->{arap} eq "ar" ? "ar" : "ap";

  my ($query, @values);

  if (!$self->{openinvoices}) {
    my $where;
    if ($self->{customernumber} ne "") {
      $where = qq|(vc.customernumber ILIKE ?)|;
      push(@values, '%' . $self->{customernumber} . '%');
    } else {
      $where = qq|(vc.name ILIKE ?)|;
      push(@values, '%' . $self->{$table} . '%');
    }

    $query =
      qq~SELECT vc.id, vc.name,
           vc.street || ' ' || vc.zipcode || ' ' || vc.city || ' ' || vc.country AS address
         FROM $table vc
         WHERE $where AND (NOT vc.obsolete)
         ORDER BY vc.name~;
  } else {
    $query =
      qq~SELECT DISTINCT vc.id, vc.name,
           vc.street || ' ' || vc.zipcode || ' ' || vc.city || ' ' || vc.country AS address
         FROM $arap a
         JOIN $table vc ON (a.${table}_id = vc.id)
         WHERE NOT (a.amount = a.paid) AND (vc.name ILIKE ?)
         ORDER BY vc.name~;
    push(@values, '%' . $self->{$table} . '%');
  }

  $self->{name_list} = selectall_hashref_query($self, $dbh, $query, @values);

  $main::lxdebug->leave_sub();

  return scalar(@{ $self->{name_list} });
}

# the selection sub is used in the AR, AP, IS, IR and OE module
#
sub all_vc {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $table, $module) = @_;

  my $ref;
  my $dbh = $self->get_standard_dbh($myconfig);

  $table = $table eq "customer" ? "customer" : "vendor";

  my $query = qq|SELECT count(*) FROM $table|;
  my ($count) = selectrow_query($self, $dbh, $query);

  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT id, name, salesman_id
                FROM $table WHERE NOT obsolete
                ORDER BY name|;
    $self->{"all_$table"} = selectall_hashref_query($self, $dbh, $query);
  }

  # get self
  $self->get_employee($dbh);

  # setup sales contacts
  $query = qq|SELECT e.id, e.name
              FROM employee e
              WHERE (e.sales = '1') AND (NOT e.id = ?)|;
  $self->{all_employees} = selectall_hashref_query($self, $dbh, $query, $self->{employee_id});

  # this is for self
  push(@{ $self->{all_employees} },
       { id   => $self->{employee_id},
         name => $self->{employee} });

  # sort the whole thing
  @{ $self->{all_employees} } =
    sort { $a->{name} cmp $b->{name} } @{ $self->{all_employees} };

  if ($module eq 'AR') {

    # prepare query for departments
    $query = qq|SELECT id, description
                FROM department
                WHERE role = 'P'
                ORDER BY description|;

  } else {
    $query = qq|SELECT id, description
                FROM department
                ORDER BY description|;
  }

  $self->{all_departments} = selectall_hashref_query($self, $dbh, $query);

  # get languages
  $query = qq|SELECT id, description
              FROM language
              ORDER BY id|;

  $self->{languages} = selectall_hashref_query($self, $dbh, $query);

  # get printer
  $query = qq|SELECT printer_description, id
              FROM printers
              ORDER BY printer_description|;

  $self->{printers} = selectall_hashref_query($self, $dbh, $query);

  # get payment terms
  $query = qq|SELECT id, description
              FROM payment_terms
              ORDER BY sortkey|;

  $self->{payment_terms} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub language_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);
  # get languages
  my $query = qq|SELECT id, description
                 FROM language
                 ORDER BY id|;

  $self->{languages} = selectall_hashref_query($self, $dbh, $query);

  # get printer
  $query = qq|SELECT printer_description, id
              FROM printers
              ORDER BY printer_description|;

  $self->{printers} = selectall_hashref_query($self, $dbh, $query);

  # get payment terms
  $query = qq|SELECT id, description
              FROM payment_terms
              ORDER BY sortkey|;

  $self->{payment_terms} = selectall_hashref_query($self, $dbh, $query);

  # get buchungsgruppen
  $query = qq|SELECT id, description
              FROM buchungsgruppen|;

  $self->{BUCHUNGSGRUPPEN} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

# this is only used for reports
sub all_departments {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $table) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);
  my $where;

  if ($table eq 'customer') {
    $where = "WHERE role = 'P' ";
  }

  my $query = qq|SELECT id, description
                 FROM department
                 $where
                 ORDER BY description|;
  $self->{all_departments} = selectall_hashref_query($self, $dbh, $query);

  delete($self->{all_departments}) unless (@{ $self->{all_departments} });

  $main::lxdebug->leave_sub();
}

sub create_links {
  $main::lxdebug->enter_sub();

  my ($self, $module, $myconfig, $table, $provided_dbh) = @_;

  my ($fld, $arap);
  if ($table eq "customer") {
    $fld = "buy";
    $arap = "ar";
  } else {
    $table = "vendor";
    $fld = "sell";
    $arap = "ap";
  }

  $self->all_vc($myconfig, $table, $module);

  # get last customers or vendors
  my ($query, $sth, $ref);

  my $dbh = $provided_dbh ? $provided_dbh : $self->get_standard_dbh($myconfig);
  my %xkeyref = ();

  if (!$self->{id}) {

    my $transdate = "current_date";
    if ($self->{transdate}) {
      $transdate = $dbh->quote($self->{transdate});
    }

    # now get the account numbers
    $query = qq|SELECT c.accno, c.description, c.link, c.taxkey_id, tk.tax_id
                FROM chart c, taxkeys tk
                WHERE (c.link LIKE ?) AND (c.id = tk.chart_id) AND tk.id =
                  (SELECT id FROM taxkeys WHERE (taxkeys.chart_id = c.id) AND (startdate <= $transdate) ORDER BY startdate DESC LIMIT 1)
                ORDER BY c.accno|;

    $sth = $dbh->prepare($query);

    do_statement($self, $sth, $query, '%' . $module . '%');

    $self->{accounts} = "";
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

      foreach my $key (split(/:/, $ref->{link})) {
        if ($key =~ /\Q$module\E/) {

          # cross reference for keys
          $xkeyref{ $ref->{accno} } = $key;

          push @{ $self->{"${module}_links"}{$key} },
            { accno       => $ref->{accno},
              description => $ref->{description},
              taxkey      => $ref->{taxkey_id},
              tax_id      => $ref->{tax_id} };

          $self->{accounts} .= "$ref->{accno} " unless $key =~ /tax/;
        }
      }
    }
  }

  # get taxkeys and description
  $query = qq|SELECT id, taxkey, taxdescription FROM tax|;
  $self->{TAXKEY} = selectall_hashref_query($self, $dbh, $query);

  if (($module eq "AP") || ($module eq "AR")) {
    # get tax rates and description
    $query = qq|SELECT * FROM tax|;
    $self->{TAX} = selectall_hashref_query($self, $dbh, $query);
  }

  if ($self->{id}) {
    $query =
      qq|SELECT
           a.cp_id, a.invnumber, a.transdate, a.${table}_id, a.datepaid,
           a.duedate, a.ordnumber, a.taxincluded, a.curr AS currency, a.notes,
           a.intnotes, a.department_id, a.amount AS oldinvtotal,
           a.paid AS oldtotalpaid, a.employee_id, a.gldate, a.type,
           c.name AS $table,
           d.description AS department,
           e.name AS employee
         FROM $arap a
         JOIN $table c ON (a.${table}_id = c.id)
         LEFT JOIN employee e ON (e.id = a.employee_id)
         LEFT JOIN department d ON (d.id = a.department_id)
         WHERE a.id = ?|;
    $ref = selectfirst_hashref_query($self, $dbh, $query, $self->{id});

    foreach $key (keys %$ref) {
      $self->{$key} = $ref->{$key};
    }

    my $transdate = "current_date";
    if ($self->{transdate}) {
      $transdate = $dbh->quote($self->{transdate});
    }

    # now get the account numbers
    $query = qq|SELECT c.accno, c.description, c.link, c.taxkey_id, tk.tax_id
                FROM chart c
                LEFT JOIN taxkeys tk ON (tk.chart_id = c.id)
                WHERE c.link LIKE ?
                  AND (tk.id = (SELECT id FROM taxkeys WHERE taxkeys.chart_id = c.id AND startdate <= $transdate ORDER BY startdate DESC LIMIT 1)
                    OR c.link LIKE '%_tax%' OR c.taxkey_id IS NULL)
                ORDER BY c.accno|;

    $sth = $dbh->prepare($query);
    do_statement($self, $sth, $query, "%$module%");

    $self->{accounts} = "";
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

      foreach my $key (split(/:/, $ref->{link})) {
        if ($key =~ /\Q$module\E/) {

          # cross reference for keys
          $xkeyref{ $ref->{accno} } = $key;

          push @{ $self->{"${module}_links"}{$key} },
            { accno       => $ref->{accno},
              description => $ref->{description},
              taxkey      => $ref->{taxkey_id},
              tax_id      => $ref->{tax_id} };

          $self->{accounts} .= "$ref->{accno} " unless $key =~ /tax/;
        }
      }
    }


    # get amounts from individual entries
    $query =
      qq|SELECT
           c.accno, c.description,
           a.source, a.amount, a.memo, a.transdate, a.cleared, a.project_id, a.taxkey,
           p.projectnumber,
           t.rate, t.id
         FROM acc_trans a
         LEFT JOIN chart c ON (c.id = a.chart_id)
         LEFT JOIN project p ON (p.id = a.project_id)
         LEFT JOIN tax t ON (t.id= (SELECT tk.tax_id FROM taxkeys tk
                                    WHERE (tk.taxkey_id=a.taxkey) AND
                                      ((CASE WHEN a.chart_id IN (SELECT chart_id FROM taxkeys WHERE taxkey_id = a.taxkey)
                                        THEN tk.chart_id = a.chart_id
                                        ELSE 1 = 1
                                        END)
                                       OR (c.link='%tax%')) AND
                                      (startdate <= a.transdate) ORDER BY startdate DESC LIMIT 1))
         WHERE a.trans_id = ?
         AND a.fx_transaction = '0'
         ORDER BY a.oid, a.transdate|;
    $sth = $dbh->prepare($query);
    do_statement($self, $sth, $query, $self->{id});

    # get exchangerate for currency
    $self->{exchangerate} =
      $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate}, $fld);
    my $index = 0;

    # store amounts in {acc_trans}{$key} for multiple accounts
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{exchangerate} =
        $self->get_exchangerate($dbh, $self->{currency}, $ref->{transdate}, $fld);
      if (!($xkeyref{ $ref->{accno} } =~ /tax/)) {
        $index++;
      }
      if (($xkeyref{ $ref->{accno} } =~ /paid/) && ($self->{type} eq "credit_note")) {
        $ref->{amount} *= -1;
      }
      $ref->{index} = $index;

      push @{ $self->{acc_trans}{ $xkeyref{ $ref->{accno} } } }, $ref;
    }

    $sth->finish;
    $query =
      qq|SELECT
           d.curr AS currencies, d.closedto, d.revtrans,
           (SELECT c.accno FROM chart c WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
           (SELECT c.accno FROM chart c WHERE d.fxloss_accno_id = c.id) AS fxloss_accno
         FROM defaults d|;
    $ref = selectfirst_hashref_query($self, $dbh, $query);
    map { $self->{$_} = $ref->{$_} } keys %$ref;

  } else {

    # get date
    $query =
       qq|SELECT
            current_date AS transdate, d.curr AS currencies, d.closedto, d.revtrans,
            (SELECT c.accno FROM chart c WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
            (SELECT c.accno FROM chart c WHERE d.fxloss_accno_id = c.id) AS fxloss_accno
          FROM defaults d|;
    $ref = selectfirst_hashref_query($self, $dbh, $query);
    map { $self->{$_} = $ref->{$_} } keys %$ref;

    if ($self->{"$self->{vc}_id"}) {

      # only setup currency
      ($self->{currency}) = split(/:/, $self->{currencies});

    } else {

      $self->lastname_used($dbh, $myconfig, $table, $module);

      # get exchangerate for currency
      $self->{exchangerate} =
        $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate}, $fld);

    }

  }

  $main::lxdebug->leave_sub();
}

sub lastname_used {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $myconfig, $table, $module) = @_;

  my $arap  = ($table eq 'customer') ? "ar" : "ap";
  $table = $table eq "customer" ? "customer" : "vendor";
  my $where = "1 = 1";

  if ($self->{type} =~ /_order/) {
    $arap  = 'oe';
    $where = "quotation = '0'";
  }
  if ($self->{type} =~ /_quotation/) {
    $arap  = 'oe';
    $where = "quotation = '1'";
  }

  my $query = qq|SELECT MAX(id) FROM $arap
                 WHERE $where AND ${table}_id > 0|;
  my ($trans_id) = selectrow_query($self, $dbh, $query);

  $trans_id *= 1;
  $query =
    qq|SELECT
         a.curr, a.${table}_id, a.department_id,
         d.description AS department,
         ct.name, current_date + ct.terms AS duedate
       FROM $arap a
       LEFT JOIN $table ct ON (a.${table}_id = ct.id)
       LEFT JOIN department d ON (a.department_id = d.id)
       WHERE a.id = ?|;
  ($self->{currency},   $self->{"${table}_id"}, $self->{department_id},
   $self->{department}, $self->{$table},        $self->{duedate})
    = selectrow_query($self, $dbh, $query, $trans_id);

  $main::lxdebug->leave_sub();
}

sub current_date {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $thisdate, $days) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);
  my $query;

  $days *= 1;
  if ($thisdate) {
    my $dateformat = $myconfig->{dateformat};
    $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;
    $thisdate = $dbh->quote($thisdate);
    $query = qq|SELECT to_date($thisdate, '$dateformat') + $days AS thisdate|;
  } else {
    $query = qq|SELECT current_date AS thisdate|;
  }

  ($thisdate) = selectrow_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();

  return $thisdate;
}

sub like {
  $main::lxdebug->enter_sub();

  my ($self, $string) = @_;

  if ($string !~ /%/) {
    $string = "%$string%";
  }

  $string =~ s/\'/\'\'/g;

  $main::lxdebug->leave_sub();

  return $string;
}

sub redo_rows {
  $main::lxdebug->enter_sub();

  my ($self, $flds, $new, $count, $numrows) = @_;

  my @ndx = ();

  map { push @ndx, { num => $new->[$_ - 1]->{runningnumber}, ndx => $_ } } 1 .. $count;

  my $i = 0;

  # fill rows
  foreach my $item (sort { $a->{num} <=> $b->{num} } @ndx) {
    $i++;
    $j = $item->{ndx} - 1;
    map { $self->{"${_}_$i"} = $new->[$j]->{$_} } @{$flds};
  }

  # delete empty rows
  for $i ($count + 1 .. $numrows) {
    map { delete $self->{"${_}_$i"} } @{$flds};
  }

  $main::lxdebug->leave_sub();
}

sub update_status {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my ($i, $id);

  my $dbh = $self->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM status
                 WHERE (formname = ?) AND (trans_id = ?)|;
  my $sth = prepare_query($self, $dbh, $query);

  if ($self->{formname} =~ /(check|receipt)/) {
    for $i (1 .. $self->{rowcount}) {
      do_statement($self, $sth, $query, $self->{formname}, $self->{"id_$i"} * 1);
    }
  } else {
    do_statement($self, $sth, $query, $self->{formname}, $self->{id});
  }
  $sth->finish();

  my $printed = ($self->{printed} =~ /\Q$self->{formname}\E/) ? "1" : "0";
  my $emailed = ($self->{emailed} =~ /\Q$self->{formname}\E/) ? "1" : "0";

  my %queued = split / /, $self->{queued};
  my @values;

  if ($self->{formname} =~ /(check|receipt)/) {

    # this is a check or receipt, add one entry for each lineitem
    my ($accno) = split /--/, $self->{account};
    $query = qq|INSERT INTO status (trans_id, printed, spoolfile, formname, chart_id)
                VALUES (?, ?, ?, ?, (SELECT c.id FROM chart c WHERE c.accno = ?))|;
    @values = ($printed, $queued{$self->{formname}}, $self->{prinform}, $accno);
    $sth = prepare_query($self, $dbh, $query);

    for $i (1 .. $self->{rowcount}) {
      if ($self->{"checked_$i"}) {
        do_statement($self, $sth, $query, $self->{"id_$i"}, @values);
      }
    }
    $sth->finish();

  } else {
    $query = qq|INSERT INTO status (trans_id, printed, emailed, spoolfile, formname)
                VALUES (?, ?, ?, ?, ?)|;
    do_query($self, $dbh, $query, $self->{id}, $printed, $emailed,
             $queued{$self->{formname}}, $self->{formname});
  }

  $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_status {
  $main::lxdebug->enter_sub();

  my ($self, $dbh) = @_;

  my ($query, $printed, $emailed);

  my $formnames  = $self->{printed};
  my $emailforms = $self->{emailed};

  $query = qq|DELETE FROM status
                 WHERE (formname = ?) AND (trans_id = ?)|;
  do_query($self, $dbh, $query, $self->{formname}, $self->{id});

  # this only applies to the forms
  # checks and receipts are posted when printed or queued

  if ($self->{queued}) {
    my %queued = split / /, $self->{queued};

    foreach my $formname (keys %queued) {
      $printed = ($self->{printed} =~ /\Q$self->{formname}\E/) ? "1" : "0";
      $emailed = ($self->{emailed} =~ /\Q$self->{formname}\E/) ? "1" : "0";

      $query = qq|INSERT INTO status (trans_id, printed, emailed, spoolfile, formname)
                  VALUES (?, ?, ?, ?, ?)|;
      do_query($self, $dbh, $query, $self->{id}, $printed, $emailed, $queued{$formname}, $formname);

      $formnames  =~ s/\Q$self->{formname}\E//;
      $emailforms =~ s/\Q$self->{formname}\E//;

    }
  }

  # save printed, emailed info
  $formnames  =~ s/^ +//g;
  $emailforms =~ s/^ +//g;

  my %status = ();
  map { $status{$_}{printed} = 1 } split / +/, $formnames;
  map { $status{$_}{emailed} = 1 } split / +/, $emailforms;

  foreach my $formname (keys %status) {
    $printed = ($formnames  =~ /\Q$self->{formname}\E/) ? "1" : "0";
    $emailed = ($emailforms =~ /\Q$self->{formname}\E/) ? "1" : "0";

    $query = qq|INSERT INTO status (trans_id, printed, emailed, formname)
                VALUES (?, ?, ?, ?)|;
    do_query($self, $dbh, $query, $self->{id}, $printed, $emailed, $formname);
  }

  $main::lxdebug->leave_sub();
}

#--- 4 locale ---#
# $main::locale->text('SAVED')
# $main::locale->text('DELETED')
# $main::locale->text('ADDED')
# $main::locale->text('PAYMENT POSTED')
# $main::locale->text('POSTED')
# $main::locale->text('POSTED AS NEW')
# $main::locale->text('ELSE')
# $main::locale->text('SAVED FOR DUNNING')
# $main::locale->text('DUNNING STARTED')
# $main::locale->text('PRINTED')
# $main::locale->text('MAILED')
# $main::locale->text('SCREENED')
# $main::locale->text('CANCELED')
# $main::locale->text('invoice')
# $main::locale->text('proforma')
# $main::locale->text('sales_order')
# $main::locale->text('packing_list')
# $main::locale->text('pick_list')
# $main::locale->text('purchase_order')
# $main::locale->text('bin_list')
# $main::locale->text('sales_quotation')
# $main::locale->text('request_quotation')

sub save_history {
  $main::lxdebug->enter_sub();

  my $self = shift();
  my $dbh = shift();

  if(!exists $self->{employee_id}) {
    &get_employee($self, $dbh);
  }

  my $query =
   qq|INSERT INTO history_erp (trans_id, employee_id, addition, what_done, snumbers) | .
   qq|VALUES (?, (SELECT id FROM employee WHERE login = ?), ?, ?, ?)|;
  my @values = (conv_i($self->{id}), $self->{login},
                $self->{addition}, $self->{what_done}, "$self->{snumbers}");
  do_query($self, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

sub get_history {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $trans_id, $restriction, $order) = @_;
  my ($orderBy, $desc) = split(/\-\-/, $order);
  $order = " ORDER BY " . ($order eq "" ? " h.itime " : ($desc == 1 ? $orderBy . " DESC " : $orderBy . " "));
  my @tempArray;
  my $i = 0;
  if ($trans_id ne "") {
    my $query =
      qq|SELECT h.employee_id, h.itime::timestamp(0) AS itime, h.addition, h.what_done, emp.name, h.snumbers, h.trans_id AS id | .
      qq|FROM history_erp h | .
      qq|LEFT JOIN employee emp ON (emp.id = h.employee_id) | .
      qq|WHERE trans_id = | . $trans_id
      . $restriction . qq| |
      . $order;
      
    my $sth = $dbh->prepare($query) || $self->dberror($query);

    $sth->execute() || $self->dberror("$query");

    while(my $hash_ref = $sth->fetchrow_hashref()) {
      $hash_ref->{addition} = $main::locale->text($hash_ref->{addition});
      $hash_ref->{what_done} = $main::locale->text($hash_ref->{what_done});
      $hash_ref->{snumbers} =~ s/^.+_(.*)$/$1/g;
      $tempArray[$i++] = $hash_ref;
    }
    $main::lxdebug->leave_sub() and return \@tempArray 
      if ($i > 0 && $tempArray[0] ne "");
  }
  $main::lxdebug->leave_sub();
  return 0;
}

sub update_defaults {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $fld, $provided_dbh) = @_;

  my $dbh;
  if ($provided_dbh) {
    $dbh = $provided_dbh;
  } else {
    $dbh = $self->dbconnect_noauto($myconfig);
  }
  my $query = qq|SELECT $fld FROM defaults FOR UPDATE|;
  my $sth   = $dbh->prepare($query);

  $sth->execute || $self->dberror($query);
  my ($var) = $sth->fetchrow_array;
  $sth->finish;

  if ($var =~ m/\d+$/) {
    my $new_var  = (substr $var, $-[0]) * 1 + 1;
    my $len_diff = length($var) - $-[0] - length($new_var);
    $var         = substr($var, 0, $-[0]) . ($len_diff > 0 ? '0' x $len_diff : '') . $new_var;

  } else {
    $var = $var . '1';
  }

  $query = qq|UPDATE defaults SET $fld = ?|;
  do_query($self, $dbh, $query, $var);

  if (!$provided_dbh) {
    $dbh->commit;
    $dbh->disconnect;
  }

  $main::lxdebug->leave_sub();

  return $var;
}

sub update_business {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $business_id, $provided_dbh) = @_;

  my $dbh;
  if ($provided_dbh) {
    $dbh = $provided_dbh;
  } else {
    $dbh = $self->dbconnect_noauto($myconfig);
  }
  my $query =
    qq|SELECT customernumberinit FROM business
       WHERE id = ? FOR UPDATE|;
  my ($var) = selectrow_query($self, $dbh, $query, $business_id);

  if ($var =~ m/\d+$/) {
    my $new_var  = (substr $var, $-[0]) * 1 + 1;
    my $len_diff = length($var) - $-[0] - length($new_var);
    $var         = substr($var, 0, $-[0]) . ($len_diff > 0 ? '0' x $len_diff : '') . $new_var;

  } else {
    $var = $var . '1';
  }

  $query = qq|UPDATE business
              SET customernumberinit = ?
              WHERE id = ?|;
  do_query($self, $dbh, $query, $var, $business_id);

  if (!$provided_dbh) {
    $dbh->commit;
    $dbh->disconnect;
  }

  $main::lxdebug->leave_sub();

  return $var;
}

sub get_partsgroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $p) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);

  my $query = qq|SELECT DISTINCT pg.id, pg.partsgroup
                 FROM partsgroup pg
                 JOIN parts p ON (p.partsgroup_id = pg.id) |;
  my @values;

  if ($p->{searchitems} eq 'part') {
    $query .= qq|WHERE p.inventory_accno_id > 0|;
  }
  if ($p->{searchitems} eq 'service') {
    $query .= qq|WHERE p.inventory_accno_id IS NULL|;
  }
  if ($p->{searchitems} eq 'assembly') {
    $query .= qq|WHERE p.assembly = '1'|;
  }
  if ($p->{searchitems} eq 'labor') {
    $query .= qq|WHERE (p.inventory_accno_id > 0) AND (p.income_accno_id IS NULL)|;
  }

  $query .= qq|ORDER BY partsgroup|;

  if ($p->{all}) {
    $query = qq|SELECT id, partsgroup FROM partsgroup
                ORDER BY partsgroup|;
  }

  if ($p->{language_code}) {
    $query = qq|SELECT DISTINCT pg.id, pg.partsgroup,
                  t.description AS translation
                FROM partsgroup pg
                JOIN parts p ON (p.partsgroup_id = pg.id)
                LEFT JOIN translation t ON ((t.trans_id = pg.id) AND (t.language_code = ?))
                ORDER BY translation|;
    @values = ($p->{language_code});
  }

  $self->{all_partsgroup} = selectall_hashref_query($self, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

sub get_pricegroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $p) = @_;

  my $dbh = $self->get_standard_dbh($myconfig);

  my $query = qq|SELECT p.id, p.pricegroup
                 FROM pricegroup p|;

  $query .= qq| ORDER BY pricegroup|;

  if ($p->{all}) {
    $query = qq|SELECT id, pricegroup FROM pricegroup
                ORDER BY pricegroup|;
  }

  $self->{all_pricegroup} = selectall_hashref_query($self, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub all_years {
# usage $form->all_years($myconfig, [$dbh])
# return list of all years where bookings found
# (@all_years)

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $dbh) = @_;

  $dbh ||= $self->get_standard_dbh($myconfig);

  # get years
  my $query = qq|SELECT (SELECT MIN(transdate) FROM acc_trans),
                   (SELECT MAX(transdate) FROM acc_trans)|;
  my ($startdate, $enddate) = selectrow_query($self, $dbh, $query);

  if ($myconfig->{dateformat} =~ /^yy/) {
    ($startdate) = split /\W/, $startdate;
    ($enddate) = split /\W/, $enddate;
  } else {
    (@_) = split /\W/, $startdate;
    $startdate = $_[2];
    (@_) = split /\W/, $enddate;
    $enddate = $_[2];
  }

  my @all_years;
  $startdate = substr($startdate,0,4);
  $enddate = substr($enddate,0,4);

  while ($enddate >= $startdate) {
    push @all_years, $enddate--;
  }

  return @all_years;

  $main::lxdebug->leave_sub();
}

1;
