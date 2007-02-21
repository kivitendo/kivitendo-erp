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
use HTML::Template;
use SL::Template;
use CGI::Ajax;
use SL::DBUtils;
use SL::Menu;
use CGI;

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
  my ($i,        $loc,  $key,    $val);
  my (%ATTACH,   $f,    $header, $header_body, $len, $buf);
  my ($boundary, @list, $size,   $body, $x, $blah, $name);

  if ($ENV{'CONTENT_TYPE'}
      && ($ENV{'CONTENT_TYPE'} =~ /multipart\/form-data; boundary=(.+)$/)) {
    $boundary = quotemeta('--' . $1);
    @list     = split(/$boundary/, $input);

    # For some reason there are always 2 extra, that are empty
    $size = @list - 2;

    for ($x = 1; $x <= $size; $x++) {
      $header_body = $list[$x];
      $header_body =~ /\r\n\r\n|\n\n/;

      # Here we split the header and body
      $header = $`;
      $body   = $';    #'
      $body =~ s/\r\n$//;

      # Now we try to get the file name
      $name = $header;
      $name =~ /name=\"(.+)\"/;
      ($name, $blah) = split(/\"/, $1);

      # If the form name is not attach, then we need to parse this like
      # regular form data
      if ($name ne "attach") {
        $body =~ s/%([0-9a-fA-Z]{2})/pack("c",hex($1))/eg;
        $ATTACH{$name} = $body;

        # Otherwise it is an attachment and we need to finish it up
      } elsif ($name eq "attach") {
        $header =~ /filename=\"(.+)\"/;
        $ATTACH{'FILE_NAME'} = $1;
        $ATTACH{'FILE_NAME'} =~ s/\"//g;
        $ATTACH{'FILE_NAME'} =~ s/\s//g;
        $ATTACH{'FILE_CONTENT'} = $body;

        for ($i = $x; $list[$i]; $i++) {
          $list[$i] =~ s/^.+name=$//;
          $list[$i] =~ /\"(\w+)\"/;
          $ATTACH{$1} = $';    #'
        }
      }
    }

    $main::lxdebug->leave_sub(2);
    return %ATTACH;

      } else {
    $main::lxdebug->leave_sub(2);
    return _input_to_hash($input);
  }
}

sub new {
  $main::lxdebug->enter_sub();

  my $type = shift;

  my $self = {};

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

  $self->{version}   = "2.4.2";

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

  my ($self, $str, $beenthere) = @_;

  # for Apache 2 we escape strings twice
  #if (($ENV{SERVER_SOFTWARE} =~ /Apache\/2/) && !$beenthere) {
  #  $str = $self->escape($str, 1);
  #}

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
    for (@_) {
      print qq|<input type=hidden name="$_" value="|
        . $self->quote($self->{$_})
        . qq|">\n|;
    }
  } else {
    delete $self->{header};
    for (sort keys %$self) {
      print qq|<input type=hidden name="$_" value="|
        . $self->quote($self->{$_})
        . qq|">\n|;
    }
  }

}

sub error {
  $main::lxdebug->enter_sub();

  my ($self, $msg) = @_;
  if ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;
    $self->show_generic_error($msg);

  } else {

    if ($self->{error_function}) {
      &{ $self->{error_function} }($msg);
    } else {
      die "Error: $msg\n";
    }
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

sub numtextrows {
  $main::lxdebug->enter_sub();

  my ($self, $str, $cols, $maxrows) = @_;

  my $rows = 0;

  map { $rows += int(((length) - 2) / $cols) + 1 } split /\r/, $str;

  $maxrows = $rows unless defined $maxrows;

  $main::lxdebug->leave_sub();

  return ($rows > $maxrows) ? $maxrows : $rows;
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

  my ($stylesheet, $favicon, $charset);

  if ($ENV{HTTP_USER_AGENT}) {

    if ($self->{stylesheet} && (-f "css/$self->{stylesheet}")) {
      $stylesheet =
        qq|<LINK REL="stylesheet" HREF="css/$self->{stylesheet}" TYPE="text/css" TITLE="Lx-Office stylesheet">
 |;
    }

    $self->{favicon}    = "favicon.ico" unless $self->{favicon};

    if ($self->{favicon} && (-f "$self->{favicon}")) {
      $favicon =
        qq|<LINK REL="shortcut icon" HREF="$self->{favicon}" TYPE="image/x-icon">
  |;
    }

    if ($self->{charset}) {
      $charset =
        qq|<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=$self->{charset}">
  |;
    }
    if ($self->{landscape}) {
      $pagelayout = qq|<style type="text/css">
                        \@page { size:landscape; }
                        </style>|;
    }
    if ($self->{fokus}) {
      $fokus = qq|<script type="text/javascript">
<!--
function fokus(){document.$self->{fokus}.focus();}
//-->
</script>|;
    }

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
    print qq|Content-Type: text/html

<html>
<head>
  <title>$self->{titlebar}</title>
  $stylesheet
  $pagelayout
  $favicon
  $charset
  $jsscript
  $ajax
  $fokus
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

sub parse_html_template {
  $main::lxdebug->enter_sub();

  my ($self, $file, $additional_params) = @_;
  my $language;

  if (!defined($main::myconfig) || !defined($main::myconfig{"countrycode"})) {
    $language = $main::language;
  } else {
    $language = $main::myconfig{"countrycode"};
  }

  if (-f "templates/webpages/${file}_${language}.html") {
    if ((-f ".developer") &&
        (-f "templates/webpages/${file}_master.html") &&
        ((stat("templates/webpages/${file}_master.html"))[9] >
         (stat("templates/webpages/${file}_${language}.html"))[9])) {
      my $info = "Developper information: templates/webpages/${file}_master.html is newer than the localized version.\n" .
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

  my $template = HTML::Template->new("filename" => $file,
                                     "die_on_bad_params" => 0,
                                     "strict" => 0,
                                     "case_sensitive" => 1,
                                     "loop_context_vars" => 1,
                                     "global_vars" => 1);

  $additional_params = {} unless ($additional_params);
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

  $additional_params->{"conf_jscalendar"} = $main::jscalendar;
  $additional_params->{"conf_lizenzen"} = $main::lizenzen;
  $additional_params->{"conf_latex_templates"} = $main::latex;
  $additional_params->{"conf_opendocument_templates"} = $main::opendocument_templates;

  my @additional_param_names = keys(%{$additional_params});
  foreach my $key ($template->param()) {
    my $param = $self->{$key};
    $param = $additional_params->{$key} if (grep(/^${key}$/, @additional_param_names));
    $param = [] if (($template->query("name" => $key) eq "LOOP") && (ref($param) ne "ARRAY"));
    $template->param($key => $param);
  }

  my $output = $template->output();

  $main::lxdebug->leave_sub();

  return $output;
}

sub show_generic_error {
  my ($self, $error, $title, $action) = @_;

  my $add_params = {};
  $add_params->{"title"} = $title if ($title);
  $self->{"label_error"} = $error;

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

  $self->header();
  print($self->parse_html_template("generic/error", $add_params));

  die("Error: $error\n");
}

sub show_generic_information {
  my ($self, $error, $title) = @_;

  my $add_params = {};
  $add_params->{"title"} = $title if ($title);
  $self->{"label_information"} = $error;

  $self->header();
  print($self->parse_html_template("generic/information", $add_params));

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

    ($script, $argv) = split(/\?/, $self->{callback});
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
  my $neg = ($amount =~ s/-//);

  if (defined($places) && ($places ne '')) {
    if ($places < 0) {
      $amount *= 1;
      $places *= -1;

      my ($actual_places) = ($amount =~ /\.(\d+)/);
      $actual_places = length($actual_places);
      $places = $actual_places > $places ? $actual_places : $places;
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
  my $template;

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

  $self->{copies} = 1 if (($self->{copies} *= 1) <= 0);

  # OUT is used for the media, screen, printer, email
  # for postscript we store a copy in a temporary file
  my $fileid = time;
  $self->{tmpfile} = "$userspath/${fileid}.$self->{IN}" if ( $self->{tmpfile} eq '' );
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

      use SL::Mailer;

      my $mail = new Mailer;

      map { $mail->{$_} = $self->{$_} }
        qw(cc bcc subject message version format charset);
      $mail->{to}     = qq|$self->{email}|;
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

      my $err = $mail->send($out);
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
          $self->{attachment_filename} = $self->{tmpfile} if ($self->{attachment_filename} eq '');
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
  $main::lxdebug->enter_sub();

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

  $main::lxdebug->leave_sub();

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

sub update_balance {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $table, $field, $where, $value) = @_;

  # if we have a value, go do it
  if ($value != 0) {

    # retrieve balance from table
    my $query = "SELECT $field FROM $table WHERE $where FOR UPDATE";
    my $sth   = $dbh->prepare($query);

    $sth->execute || $self->dberror($query);
    my ($balance) = $sth->fetchrow_array;
    $sth->finish;

    $balance += $value;

    # update balance
    $query = "UPDATE $table SET $field = $balance WHERE $where";
    $dbh->do($query) || $self->dberror($query);
  }
  $main::lxdebug->leave_sub();
}

sub update_exchangerate {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $curr, $transdate, $buy, $sell) = @_;

  # some sanity check for currency
  if ($curr eq '') {
    $main::lxdebug->leave_sub();
    return;
  }

  my $query = qq|SELECT e.curr FROM exchangerate e
                 WHERE e.curr = '$curr'
	         AND e.transdate = '$transdate'
		 FOR UPDATE|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

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
		WHERE curr = '$curr'
		AND transdate = '$transdate'|;
  } else {
    $query = qq|INSERT INTO exchangerate (curr, buy, sell, transdate)
                VALUES ('$curr', $buy, $sell, '$transdate')|;
  }
  $sth->finish;
  $dbh->do($query) || $self->dberror($query);

  $main::lxdebug->leave_sub();
}

sub save_exchangerate {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $currency, $transdate, $rate, $fld) = @_;

  my $dbh = $self->dbconnect($myconfig);

  my ($buy, $sell) = (0, 0);
  $buy  = $rate if $fld eq 'buy';
  $sell = $rate if $fld eq 'sell';

  $self->update_exchangerate($dbh, $currency, $transdate, $buy, $sell);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_exchangerate {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $curr, $transdate, $fld) = @_;

  unless ($transdate) {
    $main::lxdebug->leave_sub();
    return 1;
  }

  my $query = qq|SELECT e.$fld FROM exchangerate e
                 WHERE e.curr = '$curr'
		 AND e.transdate = '$transdate'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my ($exchangerate) = $sth->fetchrow_array;
  $sth->finish;

  if (!$exchangerate) {
    $exchangerate = 1;
  }

  $main::lxdebug->leave_sub();

  return $exchangerate;
}

sub set_payment_options {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $transdate) = @_;

  if ($self->{payment_id}) {

    my $dbh = $self->dbconnect($myconfig);

    my $query =
      qq|SELECT p.terms_netto, p.terms_skonto, p.percent_skonto, | .
      qq|p.description_long | .
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
      qq|SELECT date '$transdate' + $self->{terms_netto} AS netto_date, | .
      qq|date '$transdate' + $self->{terms_skonto} AS skonto_date | .
      qq|FROM payment_terms LIMIT 1|;
    ($self->{netto_date}, $self->{skonto_date}) =
      selectrow_query($self, $dbh, $query);

    my $total = ($self->{invtotal}) ? $self->{invtotal} : $self->{ordtotal};
    my $skonto_amount = $self->parse_amount($myconfig, $total) *
      $self->{percent_skonto};

    $self->{skonto_amount} =
      $self->format_amount($myconfig, $skonto_amount, 2);

    if ($self->{"language_id"}) {
      $query =
        qq|SELECT t.description_long, | .
        qq|l.output_numberformat, l.output_dateformat, l.output_longdates | .
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
        $self->{skonto_amount} =
          $self->format_amount($myconfig, $skonto_amount, 2);
        $myconfig->{"numberformat"} = $saved_numberformat;
      }
    }

    $self->{payment_terms} =~ s/<%netto_date%>/$self->{netto_date}/g;
    $self->{payment_terms} =~ s/<%skonto_date%>/$self->{skonto_date}/g;
    $self->{payment_terms} =~ s/<%skonto_amount%>/$self->{skonto_amount}/g;
    $self->{payment_terms} =~ s/<%total%>/$self->{total}/g;
    $self->{payment_terms} =~ s/<%invtotal%>/$self->{invtotal}/g;
    $self->{payment_terms} =~ s/<%currency%>/$self->{currency}/g;
    $self->{payment_terms} =~ s/<%terms_netto%>/$self->{terms_netto}/g;
    $self->{payment_terms} =~ s/<%account_number%>/$self->{account_number}/g;
    $self->{payment_terms} =~ s/<%bank%>/$self->{bank}/g;
    $self->{payment_terms} =~ s/<%bank_code%>/$self->{bank_code}/g;

    $dbh->disconnect;
  }

  $main::lxdebug->leave_sub();

}

sub check_exchangerate {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $currency, $transdate, $fld) = @_;

  unless ($transdate) {
    $main::lxdebug->leave_sub();
    return "";
  }

  my $dbh = $self->dbconnect($myconfig);

  my $query = qq|SELECT e.$fld FROM exchangerate e
                 WHERE e.curr = '$currency'
		 AND e.transdate = '$transdate'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my ($exchangerate) = $sth->fetchrow_array;
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $exchangerate;
}

sub get_template_language {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{language_id}) {

    my $dbh = $self->dbconnect($myconfig);


    my $query = qq|SELECT l.template_code FROM language l
                  WHERE l.id = $self->{language_id}|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
  
    ($template_code) = $sth->fetchrow_array;
    $sth->finish;
    $dbh->disconnect;
  }

  $main::lxdebug->leave_sub();

  return $template_code;
}

sub get_printer_code {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{printer_id}) {

    my $dbh = $self->dbconnect($myconfig);


    my $query = qq|SELECT p.template_code,p.printer_command FROM printers p
                  WHERE p.id = $self->{printer_id}|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
  
    ($template_code, $self->{printer_command}) = $sth->fetchrow_array;
    $sth->finish;
    $dbh->disconnect;
  }

  $main::lxdebug->leave_sub();

  return $template_code;
}

sub get_shipto {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $template_code = "";

  if ($self->{shipto_id}) {

    my $dbh = $self->dbconnect($myconfig);


    my $query = qq|SELECT s.* FROM shipto s
                  WHERE s.shipto_id = $self->{shipto_id}|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $self->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;  
    $dbh->disconnect;
  }

  $main::lxdebug->leave_sub();

}

sub add_shipto {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id, $module) = @_;
##LINET
  my $shipto;
  foreach my $item (
    qw(name department_1 department_2 street zipcode city country contact phone fax email)
    ) {
    if ($self->{"shipto$item"}) {
      $shipto = 1 if ($self->{$item} ne $self->{"shipto$item"});
    }
    $self->{"shipto$item"} =~ s/\'/\'\'/g;
  }
  if ($shipto) {
    if ($self->{shipto_id}) {
      my $query = qq| UPDATE shipto set
                      shiptoname = '$self->{shiptoname}',
                      shiptodepartment_1 = '$self->{shiptodepartment_1}',
                      shiptodepartment_2 = '$self->{shiptodepartment_2}',
                      shiptostreet = '$self->{shiptostreet}',
                      shiptozipcode = '$self->{shiptozipcode}',
                      shiptocity = '$self->{shiptocity}',
                      shiptocountry = '$self->{shiptocountry}',
                      shiptocontact = '$self->{shiptocontact}',
                      shiptophone = '$self->{shiptophone}',
                      shiptofax = '$self->{shiptofax}',
                      shiptoemail = '$self->{shiptoemail}'
                      WHERE shipto_id = $self->{shipto_id}|;
      $dbh->do($query) || $self->dberror($query);
    } else {
      my $query =
      qq|INSERT INTO shipto (trans_id, shiptoname, shiptodepartment_1, shiptodepartment_2, shiptostreet,
                   shiptozipcode, shiptocity, shiptocountry, shiptocontact,
		   shiptophone, shiptofax, shiptoemail, module) VALUES ($id,
		   '$self->{shiptoname}', '$self->{shiptodepartment_1}', '$self->{shiptodepartment_2}', '$self->{shiptostreet}',
		   '$self->{shiptozipcode}', '$self->{shiptocity}',
		   '$self->{shiptocountry}', '$self->{shiptocontact}',
		   '$self->{shiptophone}', '$self->{shiptofax}',
		   '$self->{shiptoemail}', '$module')|;
      $dbh->do($query) || $self->dberror($query);
    }
  }
##/LINET
  $main::lxdebug->leave_sub();
}

sub get_employee {
  $main::lxdebug->enter_sub();

  my ($self, $dbh) = @_;

  my $query = qq|SELECT e.id, e.name FROM employee e
                 WHERE e.login = '$self->{login}'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  ($self->{employee_id}, $self->{employee}) = $sth->fetchrow_array;
  $self->{employee_id} *= 1;

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub get_duedate {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;

  my $dbh = $self->dbconnect($myconfig);
  my $query = qq|SELECT current_date+terms_netto FROM payment_terms
                 WHERE id = '$self->{payment_id}'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  ($self->{duedate}) = $sth->fetchrow_array;

  $sth->finish;

  $main::lxdebug->leave_sub();
}

# get contacts for id, if no contact return {"","","","",""}
sub get_contacts {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id, $key) = @_;

  $key = "all_contacts" unless ($key);
  $self->{$key} = [];

  my $query =
    qq|SELECT c.cp_id, c.cp_cv_id, c.cp_name, c.cp_givenname, c.cp_abteilung | .
    qq|FROM contacts c | .
    qq|WHERE cp_cv_id = ? | .
    qq|ORDER BY lower(c.cp_name)|;
  my $sth = $dbh->prepare($query);
  $sth->execute($id) || $self->dberror($query . " ($id)");

  my $i = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{$key} }, $ref;
    $i++;
  }

  if ($i == 0) {
    push @{ $self->{$key} }, { { "", "", "", "", "", "" } };
  }
  $sth->finish;
  $main::lxdebug->leave_sub();
}

sub get_projects {
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
  my $sth = $dbh->prepare($query);
  $sth->execute(@values) ||
    $self->dberror($query . " (" . join(", ", @values) . ")");

  $self->{$key} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{ $self->{$key} }, $ref);
  }

  $sth->finish;
  $main::lxdebug->leave_sub();
}

sub get_lists {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my %params = @_;

  my $dbh = $self->dbconnect(\%main::myconfig);
  my ($sth, $query, $ref);

  my $vc = $self->{"vc"} eq "customer" ? "customer" : "vendor";
  my $vc_id = $self->{"${vc}_id"};

  if ($params{"contacts"}) {
    $self->get_contacts($dbh, $vc_id, $params{"contacts"});
  }

  if ($params{"shipto"}) {
    # get shipping addresses
    $query =
      qq|SELECT s.shipto_id,s.shiptoname,s.shiptodepartment_1 | .
      qq|FROM shipto s | .
      qq|WHERE s.trans_id = ?|;
    $sth = $dbh->prepare($query);
    $sth->execute($vc_id) || $self->dberror($query . " ($vc_id)");

    $self->{$params{"shipto"}} = [];
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push(@{ $self->{$params{"shipto"}} }, $ref);
    }
    $sth->finish;
  }

  if ($params{"projects"} || $params{"all_projects"}) {
    $self->get_projects($dbh, $params{"all_projects"} ?
                        $params{"all_projects"} : $params{"projects"},
                        $params{"all_projects"} ? 1 : 0);
  }

  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

# this sub gets the id and name from $table
sub get_name {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $table) = @_;

  # connect to database
  my $dbh = $self->dbconnect($myconfig);

  my $name           = $self->like(lc $self->{$table});
  my $customernumber = $self->like(lc $self->{customernumber});

  if ($self->{customernumber} ne "") {
    $query = qq~SELECT c.id, c.name,
                  c.street || ' ' || c.zipcode || ' ' || c.city || ' ' || c.country AS address
                  FROM $table c
                  WHERE (lower(c.customernumber) LIKE '$customernumber') AND (not c.obsolete)
                  ORDER BY c.name~;
  } else {
    $query = qq~SELECT c.id, c.name,
                 c.street || ' ' || c.zipcode || ' ' || c.city || ' ' || c.country AS address
                 FROM $table c
		 WHERE (lower(c.name) LIKE '$name') AND (not c.obsolete)
		 ORDER BY c.name~;
  }

  if ($self->{openinvoices}) {
    $query = qq~SELECT DISTINCT c.id, c.name,
                c.street || ' ' || c.zipcode || ' ' || c.city || ' ' || c.country AS address
		FROM $self->{arap} a
		JOIN $table c ON (a.${table}_id = c.id)
		WHERE NOT a.amount = a.paid
		AND lower(c.name) LIKE '$name'
		ORDER BY c.name~;
  }
  my $sth = $dbh->prepare($query);

  $sth->execute || $self->dberror($query);

  my $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{ $self->{name_list} }, $ref);
    $i++;
  }
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $i;
}

# the selection sub is used in the AR, AP, IS, IR and OE module
#
sub all_vc {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $table, $module) = @_;

  my $ref;
  my $dbh = $self->dbconnect($myconfig);

  my $query = qq|SELECT count(*) FROM $table|;
  my $sth   = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);
  my ($count) = $sth->fetchrow_array;
  $sth->finish;

  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT id, name
		FROM $table WHERE not obsolete
		ORDER BY name|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $self->{"all_$table"} }, $ref;
    }

    $sth->finish;

  }

  # get self
  $self->get_employee($dbh);

  # setup sales contacts
  $query = qq|SELECT e.id, e.name
	      FROM employee e
	      WHERE e.sales = '1'
	      AND NOT e.id = $self->{employee_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_employees} }, $ref;
  }
  $sth->finish;

  # this is for self
  push @{ $self->{all_employees} },
    { id   => $self->{employee_id},
      name => $self->{employee} };

  # sort the whole thing
  @{ $self->{all_employees} } =
    sort { $a->{name} cmp $b->{name} } @{ $self->{all_employees} };

  if ($module eq 'AR') {

    # prepare query for departments
    $query = qq|SELECT d.id, d.description
		FROM department d
		WHERE d.role = 'P'
		ORDER BY 2|;

  } else {
    $query = qq|SELECT d.id, d.description
		FROM department d
		ORDER BY 2|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_departments} }, $ref;
  }
  $sth->finish;

  # get languages
  $query = qq|SELECT id, description
              FROM language
	      ORDER BY 1|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{languages} }, $ref;
  }
  $sth->finish;

  # get printer
  $query = qq|SELECT printer_description, id
              FROM printers
	      ORDER BY 1|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{printers} }, $ref;
  }
  $sth->finish;


  # get payment terms
  $query = qq|SELECT id, description
              FROM payment_terms
              ORDER BY sortkey|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{payment_terms} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub language_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig) = @_;
  undef $self->{languages};
  undef $self->{payment_terms};
  undef $self->{printers};

  my $ref;
  my $dbh = $self->dbconnect($myconfig);
  # get languages
  my $query = qq|SELECT id, description
              FROM language
	      ORDER BY 1|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{languages} }, $ref;
  }
  $sth->finish;

  # get printer
  $query = qq|SELECT printer_description, id
              FROM printers
	      ORDER BY 1|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{printers} }, $ref;
  }
  $sth->finish;

  # get payment terms
  $query = qq|SELECT id, description
              FROM payment_terms
              ORDER BY sortkey|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{payment_terms} }, $ref;
  }
  $sth->finish;

  # get buchungsgruppen
  $query = qq|SELECT id, description
              FROM buchungsgruppen|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{BUCHUNGSGRUPPEN} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{BUCHUNGSGRUPPEN} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

# this is only used for reports
sub all_departments {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $table) = @_;

  my $dbh   = $self->dbconnect($myconfig);
  my $where = "1 = 1";

  if (defined $table) {
    if ($table eq 'customer') {
      $where = " d.role = 'P'";
    }
  }

  my $query = qq|SELECT d.id, d.description
                 FROM department d
	         WHERE $where
	         ORDER BY 2|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_departments} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub create_links {
  $main::lxdebug->enter_sub();

  my ($self, $module, $myconfig, $table) = @_;

  $self->all_vc($myconfig, $table, $module);

  # get last customers or vendors
  my ($query, $sth);

  my $dbh = $self->dbconnect($myconfig);
  my %xkeyref = ();

  if (!$self->{id}) {

    my $transdate = "current_date";
    if ($self->{transdate}) {
      $transdate = qq|'$self->{transdate}'|;
    }
  
    # now get the account numbers
    $query = qq|SELECT c.accno, c.description, c.link, c.taxkey_id, tk.tax_id
                FROM chart c, taxkeys tk
                WHERE c.link LIKE '%$module%' AND c.id=tk.chart_id AND tk.id = (SELECT id from taxkeys where taxkeys.chart_id =c.id AND startdate<=$transdate ORDER BY startdate desc LIMIT 1)
                ORDER BY c.accno|;
  
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
  
    $self->{accounts} = "";
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
  
      foreach my $key (split(/:/, $ref->{link})) {
        if ($key =~ /$module/) {
  
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
  $query = qq|SELECT id, taxkey, taxdescription
              FROM tax|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{TAXKEY} }, $ref;
  }

  $sth->finish;


  # get tax zones
  $query = qq|SELECT id, description
              FROM tax_zones|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);


  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{TAXZONE} }, $ref;
  }
  $sth->finish;

  if (($module eq "AP") || ($module eq "AR")) {

    # get tax rates and description
    $query = qq| SELECT * FROM tax t|;
    $sth   = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
    $self->{TAX} = ();
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $self->{TAX} }, $ref;
    }
    $sth->finish;
  }

  if ($self->{id}) {
    my $arap = ($table eq 'customer') ? 'ar' : 'ap';

    $query = qq|SELECT a.cp_id, a.invnumber, a.transdate,
                a.${table}_id, a.datepaid, a.duedate, a.ordnumber,
		a.taxincluded, a.curr AS currency, a.notes, a.intnotes,
		c.name AS $table, a.department_id, d.description AS department,
		a.amount AS oldinvtotal, a.paid AS oldtotalpaid,
		a.employee_id, e.name AS employee, a.gldate, a.type
		FROM $arap a
		JOIN $table c ON (a.${table}_id = c.id)
		LEFT JOIN employee e ON (e.id = a.employee_id)
		LEFT JOIN department d ON (d.id = a.department_id)
		WHERE a.id = $self->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    foreach $key (keys %$ref) {
      $self->{$key} = $ref->{$key};
    }
    $sth->finish;


    my $transdate = "current_date";
    if ($self->{transdate}) {
      $transdate = qq|'$self->{transdate}'|;
    }
  
    # now get the account numbers
    $query = qq|SELECT c.accno, c.description, c.link, c.taxkey_id, tk.tax_id
                FROM chart c, taxkeys tk
                WHERE c.link LIKE '%$module%' AND (((tk.chart_id=c.id) AND NOT(c.link like '%_tax%')) OR (NOT(tk.chart_id=c.id) AND (c.link like '%_tax%'))) AND (((tk.id = (SELECT id from taxkeys where taxkeys.chart_id =c.id AND startdate<=$transdate ORDER BY startdate desc LIMIT 1)) AND NOT(c.link like '%_tax%')) OR (c.link like '%_tax%'))
                ORDER BY c.accno|;
  
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
  
    $self->{accounts} = "";
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
  
      foreach my $key (split(/:/, $ref->{link})) {
        if ($key =~ /$module/) {
  
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
    $query = qq|SELECT c.accno, c.description, a.source, a.amount, a.memo,
                a.transdate, a.cleared, a.project_id, p.projectnumber, a.taxkey, t.rate, t.id
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		LEFT JOIN project p ON (p.id = a.project_id)
                LEFT JOIN tax t ON (t.id=(SELECT tk.tax_id from taxkeys tk WHERE (tk.taxkey_id=a.taxkey) AND ((CASE WHEN a.chart_id IN (SELECT chart_id FROM taxkeys WHERE taxkey_id=a.taxkey) THEN tk.chart_id=a.chart_id ELSE 1=1 END) OR (c.link='%tax%')) AND startdate <=a.transdate ORDER BY startdate DESC LIMIT 1)) 
                WHERE a.trans_id = $self->{id}
		AND a.fx_transaction = '0'
		ORDER BY a.oid,a.transdate|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    my $fld = ($table eq 'customer') ? 'buy' : 'sell';

    # get exchangerate for currency
    $self->{exchangerate} =
      $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate},
                              $fld);
    my $index = 0;

    # store amounts in {acc_trans}{$key} for multiple accounts
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{exchangerate} =
        $self->get_exchangerate($dbh, $self->{currency}, $ref->{transdate},
                                $fld);
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
    $query = qq|SELECT d.curr AS currencies, d.closedto, d.revtrans,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxloss_accno_id = c.id) AS fxloss_accno
		FROM defaults d|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $self->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

  } else {

    # get date
    $query = qq|SELECT current_date AS transdate,
                d.curr AS currencies, d.closedto, d.revtrans,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxloss_accno_id = c.id) AS fxloss_accno
		FROM defaults d|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $self->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    if ($self->{"$self->{vc}_id"}) {

      # only setup currency
      ($self->{currency}) = split(/:/, $self->{currencies});

    } else {

      $self->lastname_used($dbh, $myconfig, $table, $module);

      my $fld = ($table eq 'customer') ? 'buy' : 'sell';

      # get exchangerate for currency
      $self->{exchangerate} =
        $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate},
                                $fld);

    }

  }

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub lastname_used {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $myconfig, $table, $module) = @_;

  my $arap  = ($table eq 'customer') ? "ar" : "ap";
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
		              WHERE $where
			      AND ${table}_id > 0|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my ($trans_id) = $sth->fetchrow_array;
  $sth->finish;

  $trans_id *= 1;
  $query = qq|SELECT ct.name, a.curr, a.${table}_id,
              current_date + ct.terms AS duedate, a.department_id,
	      d.description AS department
	      FROM $arap a
	      JOIN $table ct ON (a.${table}_id = ct.id)
	      LEFT JOIN department d ON (a.department_id = d.id)
	      WHERE a.id = $trans_id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  ($self->{$table},  $self->{currency},      $self->{"${table}_id"},
   $self->{duedate}, $self->{department_id}, $self->{department})
    = $sth->fetchrow_array;
  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub current_date {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $thisdate, $days) = @_;

  my $dbh = $self->dbconnect($myconfig);
  my ($sth, $query);

  $days *= 1;
  if ($thisdate) {
    my $dateformat = $myconfig->{dateformat};
    $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;

    $query = qq|SELECT to_date('$thisdate', '$dateformat') + $days AS thisdate
                FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
  } else {
    $query = qq|SELECT current_date AS thisdate
                FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
  }

  ($thisdate) = $sth->fetchrow_array;
  $sth->finish;

  $dbh->disconnect;

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

  map { push @ndx, { num => $new->[$_ - 1]->{runningnumber}, ndx => $_ } }
    (1 .. $count);

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
                 WHERE formname = '$self->{formname}'
		 AND trans_id = ?|;
  my $sth = $dbh->prepare($query) || $self->dberror($query);

  if ($self->{formname} =~ /(check|receipt)/) {
    for $i (1 .. $self->{rowcount}) {
      $sth->execute($self->{"id_$i"} * 1) || $self->dberror($query);
      $sth->finish;
    }
  } else {
    $sth->execute($self->{id}) || $self->dberror($query);
    $sth->finish;
  }

  my $printed = ($self->{printed} =~ /$self->{formname}/) ? "1" : "0";
  my $emailed = ($self->{emailed} =~ /$self->{formname}/) ? "1" : "0";

  my %queued = split / /, $self->{queued};

  if ($self->{formname} =~ /(check|receipt)/) {

    # this is a check or receipt, add one entry for each lineitem
    my ($accno) = split /--/, $self->{account};
    $query = qq|INSERT INTO status (trans_id, printed, spoolfile, formname,
		chart_id) VALUES (?, '$printed',
		'$queued{$self->{formname}}', '$self->{prinform}',
		(SELECT c.id FROM chart c WHERE c.accno = '$accno'))|;
    $sth = $dbh->prepare($query) || $self->dberror($query);

    for $i (1 .. $self->{rowcount}) {
      if ($self->{"checked_$i"}) {
        $sth->execute($self->{"id_$i"}) || $self->dberror($query);
        $sth->finish;
      }
    }
  } else {
    $query = qq|INSERT INTO status (trans_id, printed, emailed,
		spoolfile, formname)
		VALUES ($self->{id}, '$printed', '$emailed',
		'$queued{$self->{formname}}', '$self->{formname}')|;
    $dbh->do($query) || $self->dberror($query);
  }

  $dbh->commit;
  $dbh->disconnect;

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
    qq|INSERT INTO history_erp (trans_id, employee_id, addition, what_done) | .
    qq|VALUES (?, ?, ?, ?)|;
  my @values = (conv_i($self->{id}), conv_i($self->{employee_id}),
                $self->{addition}, $self->{what_done});
  do_query($self, $dbh, $query, @values);
	
	$main::lxdebug->leave_sub();
}

sub get_history {
	$main::lxdebug->enter_sub();
	
	my $self = shift();
	my $dbh = shift();
	my $trans_id = shift();
	my $restriction = shift();
	my @tempArray;
	my $i = 0;
	if ($trans_id ne "") {
		my $query =
      qq|SELECT h.employee_id, h.itime::timestamp(0) AS itime, h.addition, h.what_done, emp.name | .
      qq|FROM history_erp h | .
      qq|LEFT JOIN employee emp | .
      qq|ON emp.id = h.employee_id | .
      qq|WHERE trans_id = ? |
      . $restriction;
	
		my $sth = $dbh->prepare($query) || $self->dberror($query);
	
		$sth->execute($trans_id) || $self->dberror("$query ($trans_id)");

		while(my $hash_ref = $sth->fetchrow_hashref()) {
			$hash_ref->{addition} = $main::locale->text($hash_ref->{addition});
			$hash_ref->{what_done} = $main::locale->text($hash_ref->{what_done});
			$tempArray[$i++] = $hash_ref; 
		}
    $main::lxdebug->leave_sub() and return \@tempArray
      if ($i > 0 && $tempArray[0] ne "");
	}
	$main::lxdebug->leave_sub();
	return 0;
}

sub save_status {
  $main::lxdebug->enter_sub();

  my ($self, $dbh) = @_;

  my ($query, $printed, $emailed);

  my $formnames  = $self->{printed};
  my $emailforms = $self->{emailed};

  $query = qq|DELETE FROM status
              WHERE formname = '$self->{formname}'
		      AND trans_id = $self->{id}|;
  $dbh->do($query) || $self->dberror($query);

  # this only applies to the forms
  # checks and receipts are posted when printed or queued

  if ($self->{queued}) {
    my %queued = split / /, $self->{queued};

    foreach my $formname (keys %queued) {
      $printed = ($self->{printed} =~ /$self->{formname}/) ? "1" : "0";
      $emailed = ($self->{emailed} =~ /$self->{formname}/) ? "1" : "0";

      $query = qq|INSERT INTO status (trans_id, printed, emailed,
                  spoolfile, formname)
		  VALUES ($self->{id}, '$printed', '$emailed',
		  '$queued{$formname}', '$formname')|;
      $dbh->do($query) || $self->dberror($query);

      $formnames  =~ s/$self->{formname}//;
      $emailforms =~ s/$self->{formname}//;

    }
  }

  # save printed, emailed info
  $formnames  =~ s/^ +//g;
  $emailforms =~ s/^ +//g;

  my %status = ();
  map { $status{$_}{printed} = 1 } split / +/, $formnames;
  map { $status{$_}{emailed} = 1 } split / +/, $emailforms;

  foreach my $formname (keys %status) {
    $printed = ($formnames  =~ /$self->{formname}/) ? "1" : "0";
    $emailed = ($emailforms =~ /$self->{formname}/) ? "1" : "0";

    $query = qq|INSERT INTO status (trans_id, printed, emailed, formname)
		VALUES ($self->{id}, '$printed', '$emailed', '$formname')|;
    $dbh->do($query) || $self->dberror($query);
  }

  $main::lxdebug->leave_sub();
}

sub update_defaults {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $fld) = @_;

  my $dbh   = $self->dbconnect_noauto($myconfig);
  my $query = qq|SELECT $fld FROM defaults FOR UPDATE|;
  my $sth   = $dbh->prepare($query);

  $sth->execute || $self->dberror($query);
  my ($var) = $sth->fetchrow_array;
  $sth->finish;

  $var++;

  $query = qq|UPDATE defaults
              SET $fld = '$var'|;
  $dbh->do($query) || $self->dberror($query);

  $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $var;
}

sub update_business {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $business_id) = @_;

  my $dbh   = $self->dbconnect_noauto($myconfig);
  my $query =
    qq|SELECT customernumberinit FROM business  WHERE id=$business_id FOR UPDATE|;
  my $sth = $dbh->prepare($query);

  $sth->execute || $self->dberror($query);
  my ($var) = $sth->fetchrow_array;
  $sth->finish;
  if ($var ne "") {
    $var++;
  }
  $query = qq|UPDATE business
              SET customernumberinit = '$var' WHERE id=$business_id|;
  $dbh->do($query) || $self->dberror($query);

  $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $var;
}

sub get_salesman {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $salesman) = @_;

  my $dbh   = $self->dbconnect($myconfig);
  my $query =
    qq|SELECT id, name FROM customer  WHERE (customernumber ilike '%$salesman%' OR name ilike '%$salesman%') AND business_id in (SELECT id from business WHERE salesman)|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my $i = 0;
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{ $self->{salesman_list} }, $ref);
    $i++;
  }
  $dbh->commit;
  $main::lxdebug->leave_sub();

  return $i;
}

sub get_partsgroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $p) = @_;

  my $dbh = $self->dbconnect($myconfig);

  my $query = qq|SELECT DISTINCT pg.id, pg.partsgroup
                 FROM partsgroup pg
		 JOIN parts p ON (p.partsgroup_id = pg.id)|;

  if ($p->{searchitems} eq 'part') {
    $query .= qq|
                 WHERE p.inventory_accno_id > 0|;
  }
  if ($p->{searchitems} eq 'service') {
    $query .= qq|
                 WHERE p.inventory_accno_id IS NULL|;
  }
  if ($p->{searchitems} eq 'assembly') {
    $query .= qq|
                 WHERE p.assembly = '1'|;
  }
  if ($p->{searchitems} eq 'labor') {
    $query .= qq|
                 WHERE p.inventory_accno_id > 0 AND p.income_accno_id IS NULL|;
  }

  $query .= qq|
		 ORDER BY partsgroup|;

  if ($p->{all}) {
    $query = qq|SELECT id, partsgroup FROM partsgroup
                ORDER BY partsgroup|;
  }

  if ($p->{language_code}) {
    $query = qq|SELECT DISTINCT pg.id, pg.partsgroup,
                t.description AS translation
                FROM partsgroup pg
		JOIN parts p ON (p.partsgroup_id = pg.id)
		LEFT JOIN translation t ON (t.trans_id = pg.id AND t.language_code = '$p->{language_code}')
		ORDER BY translation|;
  }

  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{all_partsgroup} = ();
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_partsgroup} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub get_pricegroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $p) = @_;

  my $dbh = $self->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.pricegroup
                 FROM pricegroup p|;

  $query .= qq|
		 ORDER BY pricegroup|;

  if ($p->{all}) {
    $query = qq|SELECT id, pricegroup FROM pricegroup
                ORDER BY pricegroup|;
  }

  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{all_pricegroup} = ();
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_pricegroup} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub audittrail {
  my ($self, $dbh, $myconfig, $audittrail) = @_;

  # table, $reference, $formname, $action, $id, $transdate) = @_;

  my $query;
  my $rv;
  my $disconnect;

  if (!$dbh) {
    $dbh        = $self->dbconnect($myconfig);
    $disconnect = 1;
  }

  # if we have an id add audittrail, otherwise get a new timestamp

  if ($audittrail->{id}) {

    $query = qq|SELECT audittrail FROM defaults|;

    if ($dbh->selectrow_array($query)) {
      my ($null, $employee_id) = $self->get_employee($dbh);

      if ($self->{audittrail} && !$myconfig) {
        chop $self->{audittrail};

        my @a = split /\|/, $self->{audittrail};
        my %newtrail = ();
        my $key;
        my $i;
        my @flds = qw(tablename reference formname action transdate);

        # put into hash and remove dups
        while (@a) {
          $key = "$a[2]$a[3]";
          $i   = 0;
          $newtrail{$key} = { map { $_ => $a[$i++] } @flds };
          splice @a, 0, 5;
        }

        $query = qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id, transdate)
	            VALUES ($audittrail->{id}, ?, ?,
		    ?, ?, $employee_id, ?)|;
        my $sth = $dbh->prepare($query) || $self->dberror($query);

        foreach $key (
          sort {
            $newtrail{$a}{transdate} cmp $newtrail{$b}{transdate}
          } keys %newtrail
          ) {
          $i = 1;
          for (@flds) { $sth->bind_param($i++, $newtrail{$key}{$_}) }

          $sth->execute || $self->dberror;
          $sth->finish;
        }
      }

      if ($audittrail->{transdate}) {
        $query = qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id, transdate) VALUES (
		    $audittrail->{id}, '$audittrail->{tablename}', |
          . $dbh->quote($audittrail->{reference}) . qq|,
		    '$audittrail->{formname}', '$audittrail->{action}',
		    $employee_id, '$audittrail->{transdate}')|;
      } else {
        $query = qq|INSERT INTO audittrail (trans_id, tablename, reference,
		    formname, action, employee_id) VALUES ($audittrail->{id},
		    '$audittrail->{tablename}', |
          . $dbh->quote($audittrail->{reference}) . qq|,
		    '$audittrail->{formname}', '$audittrail->{action}',
		    $employee_id)|;
      }
      $dbh->do($query);
    }
  } else {

    $query = qq|SELECT current_timestamp FROM defaults|;
    my ($timestamp) = $dbh->selectrow_array($query);

    $rv =
      "$audittrail->{tablename}|$audittrail->{reference}|$audittrail->{formname}|$audittrail->{action}|$timestamp|";
  }

  $dbh->disconnect if $disconnect;

  $rv;

}


sub all_years {
# usage $form->all_years($myconfig, [$dbh])
# return list of all years where bookings found
# (@all_years)

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $dbh) = @_;
  
  my $disconnect = 0;
  if (! $dbh) {
    $dbh = $self->dbconnect($myconfig);
    $disconnect = 1;
  }
 
  # get years
  my $query = qq|SELECT (SELECT MIN(transdate) FROM acc_trans),
                     (SELECT MAX(transdate) FROM acc_trans)
              FROM defaults|;
  my ($startdate, $enddate) = $dbh->selectrow_array($query);

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

  $dbh->disconnect if $disconnect;

  return @all_years;

  $main::lxdebug->leave_sub();
}


1;
