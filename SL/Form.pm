#=====================================================================
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

sub _input_to_hash {
  $main::lxdebug->enter_sub();

  my $input = $_[0];
  my %in    = ();
  my @pairs = split(/&/, $input);

  foreach (@pairs) {
    my ($name, $value) = split(/=/, $_, 2);
    $in{$name} = unescape(undef, $value);
  }

  $main::lxdebug->leave_sub();

  return %in;
}

sub _request_to_hash {
  $main::lxdebug->enter_sub();

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

    $main::lxdebug->leave_sub();
    return %ATTACH;

      } else {
    $main::lxdebug->leave_sub();
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

  $self->{menubar} = 1 if $self->{path} =~ /lynx/i;

  $self->{action} = lc $self->{action};
  $self->{action} =~ s/( |-|,|#)/_/g;

  $self->{version}   = "2.1.2";
  $self->{dbversion} = "2.1.2";

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
  $main::lxdebug->enter_sub();

  my ($self, $str, $beenthere) = @_;

  # for Apache 2 we escape strings twice
  #if (($ENV{SERVER_SOFTWARE} =~ /Apache\/2/) && !$beenthere) {
  #  $str = $self->escape($str, 1);
  #}

  $str =~ s/([^a-zA-Z0-9_.-])/sprintf("%%%02x", ord($1))/ge;

  $main::lxdebug->leave_sub();

  return $str;
}

sub unescape {
  $main::lxdebug->enter_sub();

  my ($self, $str) = @_;

  $str =~ tr/+/ /;
  $str =~ s/\\$//;

  $str =~ s/%([0-9a-fA-Z]{2})/pack("c",hex($1))/eg;

  $main::lxdebug->leave_sub();

  return $str;
}

sub error {
  $main::lxdebug->enter_sub();

  my ($self, $msg) = @_;

  if ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;

    $self->header;

    print qq|
    <body>

    <h2 class=error>Error!</h2>

    <p><b>$msg</b>

    </body>
    </html>
    |;

    die "Error: $msg\n";

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

  my ($self) = @_;

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
    $jsscript = "";
    if ($self->{jsscript} == 1) {

      $jsscript = qq|
        <style type="text/css">\@import url(js/jscalendar/calendar-win2k-1.css);</style>
        <script type="text/javascript" src="js/jscalendar/calendar.js"></script>
        <script type="text/javascript" src="js/jscalendar/lang/calendar-de.js"></script>
        <script type="text/javascript" src="js/jscalendar/calendar-setup.js"></script>
       |;
    }

    $self->{titlebar} =
      ($self->{title})
      ? "$self->{title} - $self->{titlebar}"
      : $self->{titlebar};

    print qq|Content-Type: text/html

<head>
  <title>$self->{titlebar}</title>
  $stylesheet
  $pagelayout
  $favicon
  $charset
  $jsscript
  $fokus
</head>

|;
  }
  $self->{header} = 1;

  $main::lxdebug->leave_sub();
}

# write Trigger JavaScript-Code ($qty = 1 - only one Trigger)
sub write_trigger {
  $main::lxdebug->enter_sub();

  my ($self,         $myconfig, $qty,
      $inputField_1, $align_1,  $button_1,
      $inputField_2, $align_2,  $button_2)
    = @_;

  # set dateform for jsscript
  # default
  $ifFormat = "%d.%m.%Y";
  if ($myconfig->{dateformat} eq "dd.mm.yy") {
    $ifFormat = "%d.%m.%Y";
  } else {
    if ($myconfig->{dateformat} eq "dd-mm-yy") {
      $ifFormat = "%d-%m-%Y";
    } else {
      if ($myconfig->{dateformat} eq "dd/mm/yy") {
        $ifFormat = "%d/%m/%Y";
      } else {
        if ($myconfig->{dateformat} eq "mm/dd/yy") {
          $ifFormat = "%m/%d/%Y";
        } else {
          if ($myconfig->{dateformat} eq "mm-dd-yy") {
            $ifFormat = "%m-%d-%Y";
          } else {
            if ($myconfig->{dateformat} eq "yyyy-mm-dd") {
              $ifFormat = "%Y-%m-%d";
            }
          }
        }
      }
    }
  }

  $trigger_1 = qq|
       Calendar.setup(
       {
         inputField  : "$inputField_1",
         ifFormat    :"$ifFormat",
         align    : "$align_1",     
         button      : "$button_1"
       }
       );
       |;

  if ($qty == 2) {
    $trigger_2 = qq|
       Calendar.setup(
       {
         inputField  : "$inputField_2",
         ifFormat    :"$ifFormat",
         align    : "$align_2",     
         button      : "$button_2"
       }
       );
        |;
  }
  $jsscript = qq|
       <script type="text/javascript">
       <!--
       $trigger_1
       $trigger_2
        //-->
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

sub format_amount {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $amount, $places, $dash) = @_;

  if ($places =~ /\d/) {
    $amount = $self->round_amount($amount, $places);
  }

  # is the amount negative
  my $negative = ($amount < 0);

  if ($amount != 0) {
    if ($myconfig->{numberformat} && ($myconfig->{numberformat} ne '1000.00'))
    {
      my ($whole, $dec) = split /\./, "$amount";
      $whole =~ s/-//;
      $amount = join '', reverse split //, $whole;

      if ($myconfig->{numberformat} eq '1,000.00') {
        $amount =~ s/\d{3,}?/$&,/g;
        $amount =~ s/,$//;
        $amount = join '', reverse split //, $amount;
        $amount .= "\.$dec" if ($dec ne "");
      }

      if ($myconfig->{numberformat} eq '1.000,00') {
        $amount =~ s/\d{3,}?/$&./g;
        $amount =~ s/\.$//;
        $amount = join '', reverse split //, $amount;
        $amount .= ",$dec" if ($dec ne "");
      }

      if ($myconfig->{numberformat} eq '1000,00') {
        $amount = "$whole";
        $amount .= ",$dec" if ($dec ne "");
      }

      if ($dash =~ /-/) {
        $amount = ($negative) ? "($amount)" : "$amount";
      } elsif ($dash =~ /DRCR/) {
        $amount = ($negative) ? "$amount DR" : "$amount CR";
      } else {
        $amount = ($negative) ? "-$amount" : "$amount";
      }
    }
  } else {
    if ($dash eq "0" && $places) {
      if ($myconfig->{numberformat} eq '1.000,00') {
        $amount = "0" . "," . "0" x $places;
      } else {
        $amount = "0" . "." . "0" x $places;
      }
    } else {
      $amount = ($dash ne "") ? "$dash" : "0";
    }
  }

  $main::lxdebug->leave_sub();

  return $amount;
}

sub parse_amount {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $amount) = @_;

  if (!(substr($amount, -3, 1) eq ".")) {
    if (   ($myconfig->{numberformat} eq '1.000,00')
        || ($myconfig->{numberformat} eq '1000,00')) {
      $amount =~ s/\.//g;
      $amount =~ s/,/\./;
    }

    $amount =~ s/,//g;
  }

  $main::lxdebug->leave_sub();

  return ($amount * 1);
}

sub round_amount {
  $main::lxdebug->enter_sub();

  my ($self, $amount, $places) = @_;
  my $round_amount;

  # Rounding like "Kaufmannsrunden"
  # Descr. http://de.wikipedia.org/wiki/Rundung
  # Inspired by 
  # http://www.perl.com/doc/FAQs/FAQ/oldfaq-html/Q4.13.html
  # Solves Bug: 189
  # Udo Spallek
  $amount       = $amount * (10 ** ($places));
  $round_amount = int($amount + .5 * ($amount <=> 0))/(10**($places));

  $main::lxdebug->leave_sub();

  return $round_amount;
}

sub parse_template {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $userspath) = @_;

  # { Moritz Bunkus
  # Some variables used for page breaks
  my ($chars_per_line, $lines_on_first_page, $lines_on_second_page) =
    (0, 0, 0);
  my ($current_page, $current_line) = (1, 1);
  my $pagebreak = "";
  my $sum       = 0;

  # } Moritz Bunkus

  # Make sure that all *notes* (intnotes, partnotes_*, notes etc) are converted to markup correctly.
  $self->format_string(grep(/notes/, keys(%{$self})));

  # Copy the notes from the invoice/sales order etc. back to the variable "notes" because that is where most templates expect it to be.
  $self->{"notes"} = $self->{ $self->{"formname"} . "notes" };

  map({ $self->{"employee_${_}"} = $myconfig->{$_}; }
      qw(email tel fax name signature));

  open(IN, "$self->{templates}/$self->{IN}")
    or $self->error("$self->{IN} : $!");

  @_ = <IN>;
  close(IN);

  $self->{copies} = 1 if (($self->{copies} *= 1) <= 0);

  # OUT is used for the media, screen, printer, email
  # for postscript we store a copy in a temporary file
  my $fileid = time;
  $self->{tmpfile} = "$userspath/${fileid}.$self->{IN}";
  if ($self->{format} =~ /(postscript|pdf)/ || $self->{media} eq 'email') {
    $out = $self->{OUT};
    $self->{OUT} = ">$self->{tmpfile}";
  }

  if ($self->{OUT}) {
    open(OUT, "$self->{OUT}") or $self->error("$self->{OUT} : $!");
  } else {
    open(OUT, ">-") or $self->error("STDOUT : $!");
    $self->header;
  }

  # Do we have to run LaTeX two times? This is needed if
  # the template contains page references.
  $two_passes = 0;

  # first we generate a tmpfile
  # read file and replace <%variable%>
  while ($_ = shift) {

    $par = "";
    $var = $_;

    $two_passes = 1 if (/\\pageref/);

    # { Moritz Bunkus
    # detect pagebreak block and its parameters
    if (/\s*<%pagebreak ([0-9]+) ([0-9]+) ([0-9]+)%>/) {
      $chars_per_line       = $1;
      $lines_on_first_page  = $2;
      $lines_on_second_page = $3;

      while ($_ = shift) {
        last if (/\s*<%end pagebreak%>/);
        $pagebreak .= $_;
      }
    }

    # } Moritz Bunkus

    if (/\s*<%foreach /) {

      # this one we need for the count
      chomp $var;
      $var =~ s/\s*<%foreach (.+?)%>/$1/;
      while ($_ = shift) {
        last if (/\s*<%end /);

        # store line in $par
        $par .= $_;
      }

      # display contents of $self->{number}[] array
      for $i (0 .. $#{ $self->{$var} }) {

        # { Moritz Bunkus
        # Try to detect whether a manual page break is necessary
        # but only if there was a <%pagebreak ...%> block before

        if ($chars_per_line) {
          my $lines =
            int(length($self->{"description"}[$i]) / $chars_per_line + 0.95);
          my $lpp;

          my $_description = $self->{"description"}[$i];
          while ($_description =~ /\\newline/) {
            $lines++;
            $_description =~ s/\\newline//;
          }
          $self->{"description"}[$i] =~ s/(\\newline\s?)*$//;

          if ($current_page == 1) {
            $lpp = $lines_on_first_page;
          } else {
            $lpp = $lines_on_second_page;
          }

          # Yes we need a manual page break
          if (($current_line + $lines) > $lpp) {
            my $pb = $pagebreak;

            # replace the special variables <%sumcarriedforward%>
            # and <%lastpage%>

            my $psum = $self->format_amount($myconfig, $sum, 2);
            $pb =~ s/<%sumcarriedforward%>/$psum/g;
            $pb =~ s/<%lastpage%>/$current_page/g;

            # only "normal" variables are supported here
            # (no <%if, no <%foreach, no <%include)

            $pb =~ s/<%(.+?)%>/$self->{$1}/g;

            # page break block is ready to rock
            print(OUT $pb);
            $current_page++;
            $current_line = 1;
          }
          $current_line += $lines;
        }
        $sum += $self->parse_amount($myconfig, $self->{"linetotal"}[$i]);

        # } Moritz Bunkus

        # don't parse par, we need it for each line
        $_ = $par;
        s/<%(.+?)%>/$self->{$1}[$i]/mg;
        print OUT;
      }
      next;
    }

    # if not comes before if!
    if (/\s*<%if not /) {

      # check if it is not set and display
      chop;
      s/\s*<%if not (.+?)%>/$1/;

      unless ($self->{$_}) {
        while ($_ = shift) {
          last if (/\s*<%end /);

          # store line in $par
          $par .= $_;
        }

        $_ = $par;

      } else {
        while ($_ = shift) {
          last if (/\s*<%end /);
        }
        next;
      }
    }

    if (/\s*<%if /) {

      # check if it is set and display
      chop;
      s/\s*<%if (.+?)%>/$1/;

      if ($self->{$_}) {
        while ($_ = shift) {
          last if (/\s*<%end /);

          # store line in $par
          $par .= $_;
        }

        $_ = $par;

      } else {
        while ($_ = shift) {
          last if (/\s*<%end /);
        }
        next;
      }
    }

    # check for <%include filename%>
    if (/\s*<%include /) {

      # get the filename
      chomp $var;
      $var =~ s/\s*<%include (.+?)%>/$1/;

      # mangle filename
      $var =~ s/(\/|\.\.)//g;

      # prevent the infinite loop!
      next if ($self->{"$var"});

      open(INC, "$self->{templates}/$var")
        or $self->error($self->cleanup . "$self->{templates}/$var : $!");
      unshift(@_, <INC>);
      close(INC);

      $self->{"$var"} = 1;

      next;
    }

    s/<%(.+?)%>/$self->{$1}/g;
    print OUT;
  }

  close(OUT);

  # { Moritz Bunkus
  # Convert the tex file to postscript
  if ($self->{format} =~ /(postscript|pdf)/) {

    use Cwd;
    $self->{cwd}    = cwd();
    $self->{tmpdir} = "$self->{cwd}/$userspath";

    chdir("$userspath") or $self->error($self->cleanup . "chdir : $!");

    $self->{tmpfile} =~ s/$userspath\///g;

    if ($self->{format} eq 'postscript') {
      system(
        "latex --interaction=nonstopmode $self->{tmpfile} > $self->{tmpfile}.err"
      );
      $self->error($self->cleanup) if ($?);
      if ($two_passes) {
        system(
          "latex --interaction=nonstopmode $self->{tmpfile} > $self->{tmpfile}.err"
        );
        $self->error($self->cleanup) if ($?);
      }

      $self->{tmpfile} =~ s/tex$/dvi/;

      system("dvips $self->{tmpfile} -o -q > /dev/null");
      $self->error($self->cleanup . "dvips : $!") if ($?);
      $self->{tmpfile} =~ s/dvi$/ps/;
    }
    if ($self->{format} eq 'pdf') {
      system(
        "pdflatex --interaction=nonstopmode $self->{tmpfile} > $self->{tmpfile}.err"
      );
      $self->error($self->cleanup) if ($?);
      if ($two_passes) {
        system(
          "pdflatex --interaction=nonstopmode $self->{tmpfile} > $self->{tmpfile}.err"
        );
        $self->error($self->cleanup) if ($?);
      }
      $self->{tmpfile} =~ s/tex$/pdf/;
    }

  }

  if ($self->{format} =~ /(postscript|pdf)/ || $self->{media} eq 'email') {

    if ($self->{media} eq 'email') {

      use SL::Mailer;

      my $mail = new Mailer;

      map { $mail->{$_} = $self->{$_} }
        qw(cc bcc subject message version format charset);
      $mail->{to}     = qq|$self->{email}|;
      $mail->{from}   = qq|"$myconfig->{name}" <$myconfig->{email}>|;
      $mail->{fileid} = "$fileid.";

      # if we send html or plain text inline
      if (($self->{format} eq 'html') && ($self->{sendmode} eq 'inline')) {
        $mail->{contenttype} = "text/html";

        $mail->{message}       =~ s/\r\n/<br>\n/g;
        $myconfig->{signature} =~ s/\\n/<br>\n/g;
        $mail->{message} .= "<br>\n--<br>\n$myconfig->{signature}\n<br>";

        open(IN, $self->{tmpfile})
          or $self->error($self->cleanup . "$self->{tmpfile} : $!");
        while (<IN>) {
          $mail->{message} .= $_;
        }

        close(IN);

      } else {

        @{ $mail->{attachments} } = ($self->{tmpfile});

        $myconfig->{signature} =~ s/\\n/\r\n/g;
        $mail->{message} .= "\r\n--\r\n$myconfig->{signature}";

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

      for my $i (1 .. $self->{copies}) {
        if ($self->{OUT}) {
          open(OUT, $self->{OUT})
            or $self->error($self->cleanup . "$self->{OUT} : $!");
        } else {

          # launch application
          print qq|Content-Type: application/$self->{format}
Content-Disposition: attachment; filename="$self->{tmpfile}"
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

    $self->cleanup;

  }

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

    # strip extension
    $self->{tmpfile} =~ s/\.\w+$//g;
    my $tmpfile = $self->{tmpfile};
    unlink(<$tmpfile.*>);
  }

  chdir("$self->{cwd}");

  $main::lxdebug->leave_sub();

  return "@err";
}

sub format_string {
  $main::lxdebug->enter_sub();

  my ($self, @fields) = @_;
  my %unique_fields;

  %unique_fields = map({ $_ => 1 } @fields);
  @fields = keys(%unique_fields);
  my $format = $self->{format};
  if ($self->{format} =~ /(postscript|pdf)/) {
    $format = 'tex';
  }

  my %replace = (
    'order' => {
      'html' => [
        '<', '>', quotemeta('\n'), '
'
      ],
      'tex' => [
        '&', quotemeta('\n'), '
',
        '"', '\$', '%', '_', '#', quotemeta('^'),
        '{', '}',  '<', '>', '£', "\r"
      ]
    },
    'html' => {
      '<'             => '&lt;',
      '>'             => '&gt;',
      quotemeta('\n') => '<br>',
      '
' => '<br>'
    },
    'tex' => {
      '"'             => "''",
      '&'             => '\&',
      '\$'            => '\$',
      '%'             => '\%',
      '_'             => '\_',
      '#'             => '\#',
      quotemeta('^')  => '\^\\',
      '{'             => '\{',
      '}'             => '\}',
      '<'             => '$<$',
      '>'             => '$>$',
      quotemeta('\n') => '\newline ',
      '
'          => '\newline ',
      '£'  => '\pounds ',
      "\r" => ""
    });

  foreach my $key (@{ $replace{order}{$format} }) {
    map { $self->{$_} =~ s/$key/$replace{$format}{$key}/g; } @fields;
  }

  $main::lxdebug->leave_sub();
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

  my $query = qq|SELECT e.$fld FROM exchangerate e
                 WHERE e.curr = '$curr'
		 AND e.transdate = '$transdate'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my ($exchangerate) = $sth->fetchrow_array;
  $sth->finish;

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

sub add_shipto {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id) = @_;
##LINET
  my $shipto;
  foreach
    my $item (qw(name department_1 department_2 street zipcode city country contact phone fax email)) {
    if ($self->{"shipto$item"}) {
      $shipto = 1 if ($self->{$item} ne $self->{"shipto$item"});
    }
    $self->{"shipto$item"} =~ s/\'/\'\'/g;
  }

  if ($shipto) {
    my $query = qq|INSERT INTO shipto (trans_id, shiptoname, shiptodepartment_1, shiptodepartment_2, shiptostreet,
                   shiptozipcode, shiptocity, shiptocountry, shiptocontact,
		   shiptophone, shiptofax, shiptoemail) VALUES ($id,
		   '$self->{shiptoname}', '$self->{shiptodepartment_1}', '$self->{shiptodepartment_2}', '$self->{shiptostreet}',
		   '$self->{shiptozipcode}', '$self->{shiptocity}',
		   '$self->{shiptocountry}', '$self->{shiptocontact}',
		   '$self->{shiptophone}', '$self->{shiptofax}',
		   '$self->{shiptoemail}')|;
    $dbh->do($query) || $self->dberror($query);
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

# get other contact for transaction and form - html/tex
sub get_contact {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id) = @_;

  my $query = qq|SELECT c.*
              FROM contacts c
              WHERE cp_id=$id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  push @{ $self->{$_} }, $ref;

  $sth->finish;
  $main::lxdebug->leave_sub();
}

# get contacts for id, if no contact return {"","","","",""}
sub get_contacts {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id) = @_;

  my $query = qq|SELECT c.cp_id, c.cp_cv_id, c.cp_name, c.cp_givenname
              FROM contacts c
              WHERE cp_cv_id=$id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my $i = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{all_contacts} }, $ref;
    $i++;
  }

  if ($i == 0) {
    push @{ $self->{all_contacts} }, { { "", "", "", "", "" } };
  }
  $sth->finish;
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

  # now get the account numbers
  $query =
    qq|SELECT c.accno, SUBSTRING(c.description,1,50) as description, c.link, c.taxkey_id
              FROM chart c
	      WHERE c.link LIKE '%$module%'
	      ORDER BY c.accno|;

  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $self->{accounts} = "";
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    foreach my $key (split /:/, $ref->{link}) {
      if ($key =~ /$module/) {

        # cross reference for keys
        $xkeyref{ $ref->{accno} } = $key;

        push @{ $self->{"${module}_links"}{$key} },
          { accno       => $ref->{accno},
            description => $ref->{description},
            taxkey      => $ref->{taxkey_id} };

        $self->{accounts} .= "$ref->{accno} " unless $key =~ /tax/;
      }
    }
  }
  $sth->finish;

  if (($module eq "AP") || ($module eq "AR")) {

    # get tax rates and description
    $query = qq| SELECT * FROM tax t|;
    $sth   = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
    $form->{TAX} = ();
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
		a.employee_id, e.name AS employee, a.gldate
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

    # get amounts from individual entries
    $query = qq|SELECT c.accno, c.description, a.source, a.amount, a.memo,
                a.transdate, a.cleared, a.project_id, p.projectnumber, a.taxkey, t.rate
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		LEFT JOIN project p ON (p.id = a.project_id)
		LEFT Join tax t ON (a.taxkey = t.taxkey)
		WHERE a.trans_id = $self->{id}
		AND a.fx_transaction = '0'
		ORDER BY a.transdate|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    my $fld = ($table eq 'customer') ? 'buy' : 'sell';

    # get exchangerate for currency
    $self->{exchangerate} =
      $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate},
                              $fld);

    # store amounts in {acc_trans}{$key} for multiple accounts
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{exchangerate} =
        $self->get_exchangerate($dbh, $self->{currency}, $ref->{transdate},
                                $fld);

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
      ($self->{currency}) = split /:/, $self->{currencies};

    } else {

      $self->lastname_used($dbh, $myconfig, $table, $module);

      my $fld = ($table eq 'customer') ? 'buy' : 'sell';

      # get exchangerate for currency
      $self->{exchangerate} =
        $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate},
                                $fld);

    }

  }

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

  my $query = qq|SELECT id FROM $arap
                 WHERE id IN (SELECT MAX(id) FROM $arap
		              WHERE $where
			      AND ${table}_id > 0)|;
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

sub save_status {
  $main::lxdebug->enter_sub();

  my ($self, $dbh) = @_;

  my ($query, $printed, $emailed);

  my $formnames  = $self->{printed};
  my $emailforms = $self->{emailed};

  my $query = qq|DELETE FROM status
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
  $dbh->do($query) || $form->dberror($query);

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
  $dbh->do($query) || $form->dberror($query);

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

package Locale;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $country, $NLS_file) = @_;
  my $self = {};

  %self = ();
  if ($country && -d "locale/$country") {
    $self->{countrycode} = $country;
    eval { require "locale/$country/$NLS_file"; };
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
  my ($self, $text) = @_;

  return (exists $self{texts}{$text}) ? $self{texts}{$text} : $text;
}

sub findsub {
  $main::lxdebug->enter_sub();

  my ($self, $text) = @_;

  if (exists $self{subs}{$text}) {
    $text = $self{subs}{$text};
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

1;
