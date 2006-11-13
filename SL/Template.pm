#====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#====================================================================

package SimpleTemplate;

# Parameters:
#   1. The template's file name
#   2. A reference to the Form object
#   3. A reference to the myconfig hash
#
# Returns:
#   A new template object
sub new {
  my $type = shift;
  my $self = {};

  bless($self, $type);
  $self->_init(@_);

  return $self;
}

sub _init {
  my $self = shift;

  $self->{"source"} = shift;
  $self->{"form"} = shift;
  $self->{"myconfig"} = shift;
  $self->{"userspath"} = shift;

  $self->{"error"} = undef;
}

sub cleanup {
  my ($self) = @_;
}

# Parameters:
#   1. A typeglob for the file handle. The output will be written
#      to this file handle.
#
# Returns:
#   1 on success and undef or 0 if there was an error. In the latter case
#   the calling function can retrieve the error message via $obj->get_error()
sub parse {
  my $self = $_[0];
  local *OUT = $_[1];

  print(OUT "Hallo!\n");
}

sub get_error {
  my $self = shift;

  return $self->{"error"};
}

sub uses_temp_file {
  return 0;
}

1;

####
#### LaTeXTemplate
####

package LaTeXTemplate;

use vars qw(@ISA);

@ISA = qw(SimpleTemplate);

sub new {
  my $type = shift;

  return $type->SUPER::new(@_);
}

sub format_string {
  my ($self, $variable) = @_;
  my $form = $self->{"form"};

  my %replace =
    ('order' => [
                 '&', quotemeta("\n"),
                 '"', '\$', '%', '_', '#', quotemeta('^'),
                 '{', '}',  '<', '>', '£', "\r"
                 ],
     '"'             => "''",
     '&'             => '\&',
     '\$'            => '\$',
     '%'             => '\%',
     '_'             => '\_',
     '#'             => '\#',
     '{'             => '\{',
     '}'             => '\}',
     '<'             => '$<$',
     '>'             => '$>$',
     '£'             => '\pounds ',
     "\r"            => "",
     quotemeta('^')  => '\^\\',
     quotemeta("\n") => '\newline '
     );

  map({ $variable =~ s/$_/$replace{$_}/g; } @{ $replace{"order"} });

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  my %markup_replace = ('b' => 'textbf',
                        'i' => 'textit',
                        'u' => 'underline');

  foreach my $key (keys(%markup_replace)) {
    my $new = $markup_replace{$key};
    $variable =~ s/\$\<\$${key}\$\>\$(.*?)\$<\$\/${key}\$>\$/\\${new}\{$1\}/gi;
  }

  return $variable;
}

sub parse {
  my $self = $_[0];
  local *OUT = $_[1];
  my ($form, $myconfig) = ($self->{"form"}, $self->{"myconfig"});

  # Some variables used for page breaks
  my ($chars_per_line, $lines_on_first_page, $lines_on_second_page) =
    (0, 0, 0);
  my ($current_page, $current_line, $current_row) = (1, 1, 0);
  my ($pagebreak, $sum, $two_passes, $nodiscount_sum) = ("", 0, 0, 0);
  my ($par, $var);

  # Do we have to run LaTeX two times? This is needed if
  # the template contains page references.
  $two_passes = 0;

  if (!open(IN, "$form->{templates}/$form->{IN}")) {
    $self->{"error"} = "$!";
    return 0;
  }
  @_ = <IN>;
  close(IN);

  # first we generate a tmpfile
  # read file and replace <%variable%>
  while ($_ = shift) {
    $par = "";
    $var = $_;

    $two_passes = 1 if (/\\pageref/);

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

    if (/\s*<%foreach /) {

      # this one we need for the count
      chomp $var;
      $var =~ s/\s*<%foreach (.+?)%>/$1/;
      while ($_ = shift) {
        last if (/\s*<%end /);

        # store line in $par
        $par .= $_;
      }

      # Count the number of "lines" for our variable. Also find the forced pagebreak entries.
      my $num_entries = scalar(@{$form->{$var}});
      my @forced_pagebreaks = ();
      for (my $i = 0; $i < scalar(@{$form->{$var}}); $i++) {
        if ($form->{$var}->[$i] =~ /<pagebreak>/) {
          push(@forced_pagebreaks, $i);
        }
      }

      $current_line = 1;
      # display contents of $form->{number}[] array
      for ($i = 0; $i < $num_entries; $i++) {
        # Try to detect whether a manual page break is necessary
        # but only if there was a <%pagebreak ...%> block before

        if ($chars_per_line) {
          my $lines =
            int(length($form->{"description"}->[$i]) / $chars_per_line + 0.95);
          my $lpp;

          $form->{"description"}->[$i] =~ s/(\\newline\s?)*$//;
          my $_description = $form->{"description"}->[$i];
          while ($_description =~ /\\newline/) {
            $lines++;
            $_description =~ s/\\newline//;
          }
          $lines++;

          if ($current_page == 1) {
            $lpp = $lines_on_first_page;
          } else {
            $lpp = $lines_on_second_page;
          }

          # Yes we need a manual page break -- or the user has forced one
          if ((($current_line + $lines) > $lpp) ||
              grep(/^${current_row}$/, @forced_pagebreaks)) {
            my $pb = $pagebreak;

            # replace the special variables <%sumcarriedforward%>
            # and <%lastpage%>

            my $psum = $form->format_amount($myconfig, $sum, 2);
            my $nodiscount_psum = $form->format_amount($myconfig, $nodiscount_sum, 2);
            $pb =~ s/<%nodiscount_sumcarriedforward%>/$nodiscount_psum/g;
            $pb =~ s/<%sumcarriedforward%>/$psum/g;
            $pb =~ s/<%lastpage%>/$current_page/g;

            # only "normal" variables are supported here
            # (no <%if, no <%foreach, no <%include)

            while ($pb =~ /<%(.*?)%>/) {
              substr($pb, $-[0], $+[0] - $-[0]) =
                $self->format_string($form->{"$1"}->[$i]);
            }

            # page break block is ready to rock
            print(OUT $pb);
            $current_page++;
            $current_line = 1;
          }
          $current_line += $lines;
          $current_row++;
        }
        $sum += $form->parse_amount($myconfig, $form->{"linetotal"}->[$i]);
        $nodiscount_sum += $form->parse_amount($myconfig, $form->{"nodiscount_linetotal"}->[$i]);

        # don't parse par, we need it for each line
        $_ = $par;
        while (/<%(.*?)%>/) {
          substr($_, $-[0], $+[0] - $-[0]) =
            $self->format_string($form->{"$1"}->[$i]);
        }
        print OUT;
      }
      next;
    }

    # if not comes before if!
    if (/\s*<%if not /) {

      # check if it is not set and display
      chop;
      s/\s*<%if not (.+?)%>/$1/;

      unless ($form->{$_}) {
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

      if ($form->{$_}) {
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
      next if ($form->{"$var"});

      open(INC, $form->{templates} . "/$var")
        or $form->error($self->cleanup . $form->{templates} . "/$var : $!");
      unshift(@_, <INC>);
      close(INC);

      $form->{"$var"} = 1;

      next;
    }

    while (/<%(.*?)%>/) {
      substr($_, $-[0], $+[0] - $-[0]) = $self->format_string($form->{$1});
    }
    print OUT;
  }

  if ($form->{"format"} =~ /postscript/i) {
    return $self->convert_to_postscript($two_passes);
  } elsif ($form->{"format"} =~ /pdf/i) {
    return $self->convert_to_pdf($two_passes);
  } else {
    return 1;
  }
}

sub convert_to_postscript {
  my ($self, $two_passes) = @_;
  my ($form, $userspath) = ($self->{"form"}, $self->{"userspath"});

  # Convert the tex file to postscript

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{tmpfile} =~ s/$userspath\///g;

  system("latex --interaction=nonstopmode $form->{tmpfile} " .
         "> $form->{tmpfile}.err");
  if ($?) {
    $self->{"error"} = $form->cleanup();
    $self->cleanup();
    return 0;
  }
  if ($two_passes) {
    system("latex --interaction=nonstopmode $form->{tmpfile} " .
           "> $form->{tmpfile}.err");
    if ($?) {
      $self->{"error"} = $form->cleanup();
      $self->cleanup();
      return 0;
    }
  }

  $form->{tmpfile} =~ s/tex$/dvi/;

  system("dvips $form->{tmpfile} -o -q > /dev/null");
  if ($?) {
    $self->{"error"} = "dvips : $!";
    $self->cleanup();
    return 0;
  }
  $form->{tmpfile} =~ s/dvi$/ps/;

  $self->cleanup();

  return 1;
}

sub convert_to_pdf {
  my ($self, $two_passes) = @_;
  my ($form, $userspath) = ($self->{"form"}, $self->{"userspath"});

  # Convert the tex file to PDF

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{tmpfile} =~ s/$userspath\///g;

  system("pdflatex --interaction=nonstopmode $form->{tmpfile} " .
         "> $form->{tmpfile}.err");
  if ($?) {
    $self->{"error"} = $form->cleanup();
    $self->cleanup();
    return 0;
  }

  if ($two_passes) {
    system("pdflatex --interaction=nonstopmode $form->{tmpfile} " .
           "> $form->{tmpfile}.err");
    if ($?) {
      $self->{"error"} = $form->cleanup();
      $self->cleanup();
      return 0;
    }
  }

  $form->{tmpfile} =~ s/tex$/pdf/;

  $self->cleanup();
}

sub get_mime_type() {
  my ($self) = @_;

  if ($self->{"form"}->{"format"} =~ /postscript/i) {
    return "application/postscript";
  } else {
    return "application/pdf";
  }
}

sub uses_temp_file {
  return 1;
}


####
#### HTMLTemplate
####

package HTMLTemplate;

use vars qw(@ISA);

@ISA = qw(LaTeXTemplate);

sub new {
  my $type = shift;

  return $type->SUPER::new(@_);
}

sub format_string {
  my ($self, $variable) = @_;
  my $form = $self->{"form"};

  my %replace =
    ('order' => ['<', '>', quotemeta("\n")],
     '<'             => '&lt;',
     '>'             => '&gt;',
     quotemeta("\n") => '<br>',
     );

  map({ $variable =~ s/$_/$replace{$_}/g; } @{ $replace{"order"} });

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  my @markup_replace = ('b', 'i', 's', 'u');

  foreach my $key (@markup_replace) {
    $variable =~ s/\&lt;(\/?)${key}\&gt;/<$1${key}>/g;
  }

  return $variable;
}

sub get_mime_type() {
  return "text/html";
}

sub uses_temp_file {
  return 0;
}



####
#### HTMLTemplate
####

package OpenDocumentTemplate;

use vars qw(@ISA);

use Cwd;
# use File::Copy;
# use File::Spec;
# use File::Temp qw(:mktemp);
use IO::File;

@ISA = qw(SimpleTemplate);

sub new {
  my $type = shift;

  $self = $type->SUPER::new(@_);

  foreach my $module (qw(Archive::Zip Text::Iconv)) {
    eval("use ${module};");
    if ($@) {
      $self->{"form"}->error("The Perl module '${module}' could not be " .
                             "loaded. Support for OpenDocument templates " .
                             "does not work without it. Please install your " .
                             "distribution's package or get the module from " .
                             "CPAN ( http://www.cpan.org ).");
    }
  }

  $self->{"rnd"} = int(rand(1000000));
  $self->{"iconv"} = Text::Iconv->new($main::dbcharset, "UTF-8");

  return $self;
}

sub substitute_vars {
  my ($self, $text, @indices) = @_;

  my $form = $self->{"form"};

  while ($text =~ /\&lt;\%(.*?)\%\&gt;/) {
    my $value = $form->{$1};

    for (my $i = 0; $i < scalar(@indices); $i++) {
      last unless (ref($value) eq "ARRAY");
      $value = $value->[$indices[$i]];
    }
    substr($text, $-[0], $+[0] - $-[0]) = $self->format_string($value);
  }

  return $text;
}

sub parse_foreach {
  my ($self, $var, $text, $start_tag, $end_tag, @indices) = @_;

  my ($form, $new_contents) = ($self->{"form"}, "");

  my $ary = $form->{$var};
  for (my $i = 0; $i < scalar(@indices); $i++) {
    last unless (ref($ary) eq "ARRAY");
    $ary = $ary->[$indices[$i]];
  }

  for (my $i = 0; $i < scalar(@{$ary}); $i++) {
    my $new_text = $self->parse_block($text, (@indices, $i));
    return undef unless (defined($new_text));
    $new_contents .= $start_tag . $new_text . $end_tag;
  }

  return $new_contents;
}

sub parse_block {
  $main::lxdebug->enter_sub();

  my ($self, $contents, @indices) = @_;

  my $new_contents = "";

  while ($contents ne "") {
    if (substr($contents, 0, 1) eq "<") {
      $contents =~ m|^<[^>]+>|;
      my $tag = $&;
      substr($contents, 0, length($&)) = "";

      if ($tag =~ m|<table:table-row|) {
        $contents =~ m|^(.*?)(</table:table-row[^>]*>)|;
        my $table_row = $1;
        my $end_tag = $2;
        substr($contents, 0, length($1) + length($end_tag)) = "";

        if ($table_row =~ m|\&lt;\%foreachrow\s+(.*?)\%\&gt;|) {
          my $var = $1;

          $table_row =~ s|\&lt;\%foreachrow .*?\%\&gt;||g;
          $table_row =~ s!\&lt;\%end(for|foreach)?row\s+${var}\%\&gt;!!g;

          my $new_text = $self->parse_foreach($var, $table_row, $tag, $end_tag, @indices);
          return undef unless (defined($new_text));
          $new_contents .= $new_text;

        } else {
          my $new_text = $self->parse_block($table_row, @indices);
          return undef unless (defined($new_text));
          $new_contents .= $tag . $new_text . $end_tag;
        }

      } else {
        $new_contents .= $tag;
      }

    } else {
      $contents =~ /^[^<]+/;
      my $text = $&;

      my $pos_if = index($text, '&lt;%if');
      my $pos_foreach = index($text, '&lt;%foreach');

      if ((-1 == $pos_if) && (-1 == $pos_foreach)) {
        substr($contents, 0, length($text)) = "";
        $new_contents .= $self->substitute_vars($text, @indices);
        next;
      }

      if ((-1 == $pos_if) || ((-1 != $pos_foreach) && ($pos_if > $pos_foreach))) {
        $new_contents .= $self->substitute_vars(substr($contents, 0, $pos_foreach), @indices);
        substr($contents, 0, $pos_foreach) = "";

        if ($contents !~ m|^\&lt;\%foreach (.*?)\%\&gt;|) {
          $self->{"error"} = "Malformed <\%foreach\%>.";
          $main::lxdebug->leave_sub();
          return undef;
        }

        my $var = $1;

        substr($contents, 0, length($&)) = "";

        if ($contents !~ m!\&lt;\%end\s*?(for)?\s+${var}\%\&gt;!) {
          $self->{"error"} = "Unclosed <\%foreach\%>.";
          $main::lxdebug->leave_sub();
          return undef;
        }

        substr($contents, 0, length($`) + length($&)) = "";
        my $new_text = $self->parse_foreach($var, $`, "", "", @indices);
        return undef unless (defined($new_text));
        $new_contents .= $new_text;

      } else {
        $new_contents .= $self->substitute_vars(substr($contents, 0, $pos_if), @indices);
        substr($contents, 0, $pos_if) = "";

        if ($contents !~ m|^\&lt;\%if(not)?\s+(.*?)\%\&gt;|) {
          $self->{"error"} = "Malformed <\%if\%>.";
          $main::lxdebug->leave_sub();
          return undef;
        }

        my ($not, $var) = ($1, $2);

        substr($contents, 0, length($&)) = "";

        if ($contents !~ m!\&lt;\%endif${not}\s+${var}\%\&gt;!) {
          $self->{"error"} = "Unclosed <\%if${not}\%>.";
          $main::lxdebug->leave_sub();
          return undef;
        }

        substr($contents, 0, length($`) + length($&)) = "";

        my $value = $self->{"form"}->{$var};
        for (my $i = 0; $i < scalar(@indices); $i++) {
          last unless (ref($value) eq "ARRAY");
          $value = $value->[$indices[$i]];
        }

        if (($not && !$value) || (!$not && $value)) {
          my $new_text = $self->parse_block($`, @indices);
          return undef unless (defined($new_text));
          $new_contents .= $new_text;
        }
      }
    }
  }

  return $new_contents;
}

sub parse {
  $main::lxdebug->enter_sub();

  my $self = $_[0];
  local *OUT = $_[1];
  my $form = $self->{"form"};

  close(OUT);

  my $zip = Archive::Zip->new();
  if (Archive::Zip::AZ_OK != $zip->read("$form->{templates}/$form->{IN}")) {
    $self->{"error"} = "File not found/is not a OpenDocument file.";
    $main::lxdebug->leave_sub();
    return 0;
  }

  my $contents = $zip->contents("content.xml");
  if (!$contents) {
    $self->{"error"} = "File is not a OpenDocument file.";
    $main::lxdebug->leave_sub();
    return 0;
  }

  my $rnd = $self->{"rnd"};
  my $new_styles = qq|<style:style style:name="TLXO${rnd}BOLD" style:family="text">
<style:text-properties fo:font-weight="bold" style:font-weight-asian="bold" style:font-weight-complex="bold"/>
</style:style>
<style:style style:name="TLXO${rnd}ITALIC" style:family="text">
<style:text-properties fo:font-style="italic" style:font-style-asian="italic" style:font-style-complex="italic"/>
</style:style>
<style:style style:name="TLXO${rnd}UNDERLINE" style:family="text">
<style:text-properties style:text-underline-style="solid" style:text-underline-width="auto" style:text-underline-color="font-color"/>
</style:style>
<style:style style:name="TLXO${rnd}STRIKETHROUGH" style:family="text">
<style:text-properties style:text-line-through-style="solid"/>
</style:style>|;

  $contents =~ s|</office:automatic-styles>|${new_styles}</office:automatic-styles>|;
  $contents =~ s|[\n\r]||gm;

  my $new_contents = $self->parse_block($contents);
  return 0 unless (defined($new_contents));

#   $new_contents =~ s|>|>\n|g;

  $zip->contents("content.xml", $new_contents);
  $zip->writeToFileNamed($form->{"tmpfile"}, 1);

  my $res = 1;
  if ($form->{"format"} =~ /pdf/) {
    $res = $self->convert_to_pdf();
  }

  $main::lxdebug->leave_sub();
  return $res;
}

sub convert_to_pdf {
  my ($self) = @_;

  my $form = $self->{"form"};

  my $filename = $form->{"tmpfile"};
  $filename =~ s/.odt$//;
  if (substr($filename, 0, 1) ne "/") {
    $filename = getcwd() . "/${filename}";
  }

  if (substr($self->{"userspath"}, 0, 1) eq "/") {
    $ENV{'HOME'} = $self->{"userspath"};
  } else {
    $ENV{'HOME'} = getcwd() . "/" . $self->{"userspath"};
  }

  my @cmdline = ($main::xvfb_run_bin, $main::openofficeorg_writer_bin,
                 "-minimized", "-norestore", "-nologo", "-nolockcheck",
                 "-headless",
                 "file:${filename}.odt",
                 "macro://" . (split('/', $filename))[-1] .
                 "/Standard.Conversion.ConvertSelfToPDF()");

  system(@cmdline);

  my $res = $?;
  if (0 == $?) {
    $form->{"tmpfile"} =~ s/odt$/pdf/;

    unlink($filename . ".odt");

    $main::lxdebug->leave_sub();
    return 1;

  }

  unlink($filename . ".odt", $filename . ".pdf");
  $self->{"error"} = "Conversion from OpenDocument to PDF failed. " .
    "Exit code: $res";

  $main::lxdebug->leave_sub();
  return 0;
}

sub format_string {
  my ($self, $variable) = @_;
  my $form = $self->{"form"};
  my $iconv = $self->{"iconv"};

  my %replace =
    ('order' => ['<', '>', '"', "'",
                 '\x80',        # Euro
                 quotemeta("\n"), quotemeta("\r"), '&'],
     '<'             => '&lt;',
     '>'             => '&gt;',
     '"'             => '&quot;',
     "'"             => '&apos;',
     '&'             => '&quot;',
     '\x80'          => chr(0xa4), # Euro
     quotemeta("\n") => '<text:line-break/>',
     quotemeta("\r") => '',
     );

  map({ $variable =~ s/$_/$replace{$_}/g; } @{ $replace{"order"} });

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  my $rnd = $self->{"rnd"};
  my %markup_replace = ("b" => "BOLD", "i" => "ITALIC", "s" => "STRIKETHROUGH",
                        "u" => "UNDERLINE");

  foreach my $key (keys(%markup_replace)) {
    my $value = $markup_replace{$key};
    $variable =~ s|\&lt;${key}\&gt;|<text:span text:style-name=\"TLXO${rnd}${value}\">|g;
    $variable =~ s|\&lt;/${key}\&gt;|</text:span>|g;
  }

  return $iconv->convert($variable);
}

sub get_mime_type() {
  if ($self->{"form"}->{"format"} =~ /pdf/) {
    return "application/pdf";
  } else {
    return "application/vnd.oasis.opendocument.text";
  }
}

sub uses_temp_file {
  return 1;
}

1;
