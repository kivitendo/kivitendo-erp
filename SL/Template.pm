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

  $self->{source}    = shift;
  $self->{form}      = shift;
  $self->{myconfig}  = shift;
  $self->{userspath} = shift;

  $self->{error}     = undef;
  $self->{quot_re}   = '"';

  $self->set_tag_style('<%', '%>');
}

sub set_tag_style {
  my $self                    = shift;
  my $tag_start               = shift;
  my $tag_end                 = shift;

  $self->{tag_start}          = $tag_start;
  $self->{tag_end}            = $tag_end;
  $self->{tag_start_qm}       = quotemeta $tag_start;
  $self->{tag_end_qm}         = quotemeta $tag_end;

  $self->{substitute_vars_re} = "$self->{tag_start_qm}(.+?)$self->{tag_end_qm}";
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

sub _get_loop_variable {
  my $self      = shift;
  my $var       = shift;
  my $get_array = shift;
  my @indices   = @_;

  my $form      = $self->{form};
  my $value;

  if (($get_array || @indices) && (ref $form->{TEMPLATE_ARRAYS} eq 'HASH') && (ref $form->{TEMPLATE_ARRAYS}->{$var} eq 'ARRAY')) {
    $value = $form->{TEMPLATE_ARRAYS}->{$var};
  } else {
    $value = $form->{$var};
  }

  for (my $i = 0; $i < scalar(@indices); $i++) {
    last unless (ref($value) eq "ARRAY");
    $value = $value->[$indices[$i]];
  }

  return $value;
}

sub substitute_vars {
  my ($self, $text, @indices) = @_;

  my $form = $self->{"form"};

  while ($text =~ /$self->{substitute_vars_re}/) {
    my ($tag_pos, $tag_len) = ($-[0], $+[0] - $-[0]);
    my ($var, @options)     = split(/\s+/, $1);

    my $value               = $self->_get_loop_variable($var, 0, @indices);
    $value                  = $self->format_string($value) unless (grep(/^NOESCAPE$/, @options));

    substr($text, $tag_pos, $tag_len, $value);
  }

  return $text;
}

sub _parse_block_if {
  $main::lxdebug->enter_sub();

  my $self         = shift;
  my $contents     = shift;
  my $new_contents = shift;
  my $pos_if       = shift;
  my @indices      = @_;

  $$new_contents .= $self->substitute_vars(substr($$contents, 0, $pos_if), @indices);
  substr($$contents, 0, $pos_if) = "";

  if ($$contents !~ m/^$self->{tag_start_qm}if
                     \s*
                     (not\b|\!)?           # $1 -- Eventuelle Negierung
                     \s+
                     (\b.+?\b)             # $2 -- Name der zu überprüfenden Variablen
                     (                     # $3 -- Beginn des optionalen Vergleiches
                       \s*
                       ([!=])              # $4 -- Negierung des Vergleiches speichern
                       ([=~])              # $5 -- Art des Vergleiches speichern
                       \s*
                       (                   # $6 -- Gequoteter String oder Bareword
                         $self->{quot_re}
                         (.*?)(?<!\\)      # $7 -- Gequoteter String -- direkter Vergleich mit eq bzw. ne oder Patternmatching; Escapete Anführungs als Teil des Strings belassen
                         $self->{quot_re}
                       |
                         (\b.+?\b)         # $8 -- Bareword -- als Index für $form benutzen
                       )
                     )?
                     \s*
                     $self->{tag_end_qm}
                    /x) {
    $self->{"error"} = "Malformed $self->{tag_start}if$self->{tag_end}.";
    $main::lxdebug->leave_sub();
    return undef;
  }

  my $not           = $1;
  my $var           = $2;
  my $operator_neg  = $4; # '=' oder '!' oder undef, wenn kein Vergleich erkannt
  my $operator_type = $5; # '=' oder '~' für Stringvergleich oder Regex
  my $quoted_word   = $7; # nur gültig, wenn quoted string angegeben (siehe unten); dann "value" aus <%if var == "value" %>
  my $bareword      = $8; # undef, falls quoted string angegeben wurde; andernfalls "othervar" aus <%if var == othervar %>

  $not = !$not if ($operator_neg && $operator_neg eq '!');

  substr($$contents, 0, length($&)) = "";

  my $block;
  ($block, $$contents) = $self->find_end($$contents, 0, $var, $not);
  if (!$block) {
    $self->{"error"} = "Unclosed $self->{tag_start}if$self->{tag_end}." unless ($self->{"error"});
    $main::lxdebug->leave_sub();
    return undef;
  }

  my $value = $self->_get_loop_variable($var, 0, @indices);
  my $hit   = 0;

  if ($operator_type) {
    my $compare_to = $bareword ? $self->_get_loop_variable($bareword, 0, @indices) : $quoted_word;
    if ($operator_type eq '=') {
      $hit         = ($not && !($value eq $compare_to))     || (!$not && ($value eq $compare_to));
    } else {
      $hit         = ($not && !($value =~ m/$compare_to/i)) || (!$not && ($value =~ m/$compare_to/i));
    }

  } else {
    $hit           = ($not && ! $value)                     || (!$not &&  $value);
  }

  if ($hit) {
    my $new_text = $self->parse_block($block, @indices);
    if (!defined($new_text)) {
      $main::lxdebug->leave_sub();
      return undef;
    }
    $$new_contents .= $new_text;
  }

  $main::lxdebug->leave_sub();

  return 1;
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

  my $self = $type->SUPER::new(@_);

  return $self;
}

sub format_string {
  my ($self, $variable) = @_;
  my $form = $self->{"form"};

  $variable = $main::locale->quote_special_chars('Template/LaTeX', $variable);

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  my %markup_replace = ('b' => 'textbf',
                        'i' => 'textit',
                        'u' => 'underline');

  foreach my $key (keys(%markup_replace)) {
    my $new = $markup_replace{$key};
    $variable =~ s/\$\<\$${key}\$\>\$(.*?)\$<\$\/${key}\$>\$/\\${new}\{$1\}/gi;
  }

  $variable =~ s/[\x00-\x1f]//g;

  return $variable;
}

sub parse_foreach {
  my ($self, $var, $text, $start_tag, $end_tag, @indices) = @_;

  my ($form, $new_contents) = ($self->{"form"}, "");

  my $ary = $self->_get_loop_variable($var, 1, @indices);

  my $sum                          = 0;
  my $current_page                 = 1;
  my ($current_line, $corrent_row) = (0, 1);
  my $description_array            = $self->_get_loop_variable("description",     1);
  my $longdescription_array        = $self->_get_loop_variable("longdescription", 1);
  my $linetotal_array              = $self->_get_loop_variable("linetotal",       1);

  $form->{TEMPLATE_ARRAYS}->{cumulatelinetotal} = [];

  for (my $i = 0; $i < scalar(@{$ary}); $i++) {
    $form->{"__first__"}   = $i == 1;
    $form->{"__last__"}    = ($i + 1) == scalar(@{$ary});
    $form->{"__odd__"}     = (($i + 1) % 2) == 1;
    $form->{"__counter__"} = $i + 1;

    if (scalar @{$description_array} == scalar @{$ary} && $self->{"chars_per_line"} != 0) {
      my $lines = int(length($description_array->[$i]) / $self->{"chars_per_line"});
      my $lpp;

      $description_array->[$i] =~ s/(\\newline\s?)*$//;
      my $_description = $description_array->[$i];
      while ($_description =~ /\\newline/) {
        $lines++;
        $_description =~ s/\\newline//;
      }
      $lines++;

      if ($current_page == 1) {
        $lpp = $self->{"lines_on_first_page"};
      } else {
        $lpp = $self->{"lines_on_second_page"};
      }

      # Yes we need a manual page break -- or the user has forced one
      if ((($current_line + $lines) > $lpp) || ($description_array->[$i] =~ /<pagebreak>/) || ($longdescription_array->[$i] =~ /<pagebreak>/)) {
        my $pb = $self->{"pagebreak_block"};

        # replace the special variables <%sumcarriedforward%>
        # and <%lastpage%>

        my $psum = $form->format_amount($self->{"myconfig"}, $sum, 2);
        $pb =~ s/$self->{tag_start_qm}sumcarriedforward$self->{tag_end_qm}/$psum/g;
        $pb =~ s/$self->{tag_start_qm}lastpage$self->{tag_end_qm}/$current_page/g;

        my $new_text = $self->parse_block($pb, (@indices, $i));
        return undef unless (defined($new_text));
        $new_contents .= $new_text;

        $current_page++;
        $current_line = 0;
      }
      $current_line += $lines;
    }

    if ($i < scalar(@{$linetotal_array})) {
      $sum += $form->parse_amount($self->{"myconfig"}, $linetotal_array->[$i]);
    }

    $form->{TEMPLATE_ARRAYS}->{cumulatelinetotal}->[$i] = $form->format_amount($self->{"myconfig"}, $sum, 2);

    my $new_text = $self->parse_block($text, (@indices, $i));
    return undef unless (defined($new_text));
    $new_contents .= $start_tag . $new_text . $end_tag;
  }
  map({ delete($form->{"__${_}__"}); } qw(first last odd counter));

  return $new_contents;
}

sub find_end {
  my ($self, $text, $pos, $var, $not) = @_;

  my $tag_start_len = length $self->{tag_start};

  my $depth = 1;
  $pos = 0 unless ($pos);

  while ($pos < length($text)) {
    $pos++;

    next if (substr($text, $pos - 1, length($self->{tag_start})) ne $self->{tag_start});

    my $keyword_pos = $pos - 1 + $tag_start_len;

    if ((substr($text, $keyword_pos, 2) eq 'if') || (substr($text, $keyword_pos, 3) eq 'for')) {
      $depth++;

    } elsif ((substr($text, $keyword_pos, 4) eq 'else') && (1 == $depth)) {
      if (!$var) {
        $self->{"error"} =
            "$self->{tag_start}else$self->{tag_end} outside of "
          . "$self->{tag_start}if$self->{tag_end} / "
          . "$self->{tag_start}ifnot$self->{tag_end}.";
        return undef;
      }

      my $block = substr($text, 0, $pos - 1);
      substr($text, 0, $pos - 1) = "";
      $text =~ s!^$self->{tag_start_qm}.+?$self->{tag_end_qm}!!;
      $text =  $self->{tag_start} . 'if' . ($not ?  " " : "not ") . $var . $self->{tag_end} . $text;

      return ($block, $text);

    } elsif (substr($text, $keyword_pos, 3) eq 'end') {
      $depth--;
      if ($depth == 0) {
        my $block = substr($text, 0, $pos - 1);
        substr($text, 0, $pos - 1) = "";
        $text =~ s!^$self->{tag_start_qm}.+?$self->{tag_end_qm}!!;

        return ($block, $text);
      }
    }
  }

  return undef;
}

sub parse_block {
  $main::lxdebug->enter_sub();

  my ($self, $contents, @indices) = @_;

  my $new_contents = "";

  while ($contents ne "") {
    my $pos_if      = index($contents, $self->{tag_start} . 'if');
    my $pos_foreach = index($contents, $self->{tag_start} . 'foreach');

    if ((-1 == $pos_if) && (-1 == $pos_foreach)) {
      $new_contents .= $self->substitute_vars($contents, @indices);
      last;
    }

    if ((-1 == $pos_if) || ((-1 != $pos_foreach) && ($pos_if > $pos_foreach))) {
      $new_contents .= $self->substitute_vars(substr($contents, 0, $pos_foreach), @indices);
      substr($contents, 0, $pos_foreach) = "";

      if ($contents !~ m|^$self->{tag_start_qm}foreach (.+?)$self->{tag_end_qm}|) {
        $self->{"error"} = "Malformed $self->{tag_start}foreach$self->{tag_end}.";
        $main::lxdebug->leave_sub();
        return undef;
      }

      my $var = $1;

      substr($contents, 0, length($&)) = "";

      my $block;
      ($block, $contents) = $self->find_end($contents);
      if (!$block) {
        $self->{"error"} = "Unclosed $self->{tag_start}foreach$self->{tag_end}." unless ($self->{"error"});
        $main::lxdebug->leave_sub();
        return undef;
      }

      my $new_text = $self->parse_foreach($var, $block, "", "", @indices);
      if (!defined($new_text)) {
        $main::lxdebug->leave_sub();
        return undef;
      }
      $new_contents .= $new_text;

    } else {
      if (!$self->_parse_block_if(\$contents, \$new_contents, $pos_if, @indices)) {
        $main::lxdebug->leave_sub();
        return undef;
      }
    }
  }

  $main::lxdebug->leave_sub();

  return $new_contents;
}

sub parse_first_line {
  my $self = shift;
  my $line = shift || "";

  if ($line =~ m/([^\s]+)set-tag-style([^\s]+)/) {
    if ($1 eq $2) {
      $self->{error} = "The tag start and end markers must not be equal.";
      return 0;
    }

    $self->set_tag_style($1, $2);
  }

  return 1;
}

sub _parse_config_option {
  my $self = shift;
  my $line = shift;

  $line =~ s/^\s*//;
  $line =~ s/\s*$//;

  my ($key, $value) = split m/\s*=\s*/, $line, 2;

  if ($key eq 'tag-style') {
    $self->set_tag_style(split(m/\s+/, $value, 2));
  }
}

sub _parse_config_lines {
  my $self  = shift;
  my $lines = shift;

  my ($comment_start, $comment_end) = ("", "");

  if (ref $self eq 'LaTeXTemplate') {
    $comment_start = '\s*%';
  } elsif (ref $self eq 'HTMLTemplate') {
    $comment_start = '\s*<!--';
    $comment_end   = '>\s*';
  } else {
    $comment_start = '\s*\#';
  }

  my $num_lines = scalar @{ $lines };
  my $i         = 0;

  while ($i < $num_lines) {
    my $line = $lines->[$i];

    if ($line !~ m/^${comment_start}\s*config\s*:(.*)${comment_end}$/i) {
      $i++;
      next;
    }

    $self->_parse_config_option($1);
    splice @{ $lines }, $i, 1;
    $num_lines--;
  }
}

sub _force_mandatory_packages {
  my $self  = shift;
  my $lines = shift;

  my (%used_packages, $document_start_line);

  foreach my $i (0 .. scalar @{ $lines } - 1) {
    if ($lines->[$i] =~ m/\\usepackage[^\{]*{(.*?)}/) {
      $used_packages{$1} = 1;

    } elsif ($lines->[$i] =~ m/\\begin{document}/) {
      $document_start_line = $i;
      last;

    }
  }

  $document_start_line = scalar @{ $lines } - 1 if (!defined $document_start_line);

  if (!$used_packages{textcomp}) {
    splice @{ $lines }, $document_start_line, 0, "\\usepackage{textcomp}\n";
    $document_start_line++;
  }
}

sub parse {
  my $self = $_[0];
  local *OUT = $_[1];
  my $form = $self->{"form"};

  if (!open(IN, "$form->{templates}/$form->{IN}")) {
    $self->{"error"} = "$!";
    return 0;
  }
  my @lines = <IN>;
  close(IN);

  $self->_parse_config_lines(\@lines);
  $self->_force_mandatory_packages(\@lines) if (ref $self eq 'LaTeXTemplate');

  my $contents = join("", @lines);

  # detect pagebreak block and its parameters
  if ($contents =~ /$self->{tag_start_qm}pagebreak\s+(\d+)\s+(\d+)\s+(\d+)\s*$self->{tag_end_qm}(.*?)$self->{tag_start_qm}end(\s*pagebreak)?$self->{tag_end_qm}/s) {
    $self->{"chars_per_line"} = $1;
    $self->{"lines_on_first_page"} = $2;
    $self->{"lines_on_second_page"} = $3;
    $self->{"pagebreak_block"} = $4;

    substr($contents, length($`), length($&)) = "";
  }

  $self->{"forced_pagebreaks"} = [];

  my $new_contents = $self->parse_block($contents);
  if (!defined($new_contents)) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  print(OUT $new_contents);

  if ($form->{"format"} =~ /postscript/i) {
    return $self->convert_to_postscript();
  } elsif ($form->{"format"} =~ /pdf/i) {
    return $self->convert_to_pdf();
  } else {
    return 1;
  }
}

sub convert_to_postscript {
  my ($self) = @_;
  my ($form, $userspath) = ($self->{"form"}, $self->{"userspath"});

  # Convert the tex file to postscript

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{tmpfile} =~ s/\Q$userspath\E\///g;

  my $latex = $self->_get_latex_path();

  for (my $run = 1; $run <= 2; $run++) {
    system("${latex} --interaction=nonstopmode $form->{tmpfile} " .
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
  my ($self) = @_;
  my ($form, $userspath) = ($self->{"form"}, $self->{"userspath"});

  # Convert the tex file to PDF

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{tmpfile} =~ s/\Q$userspath\E\///g;

  my $latex = $self->_get_latex_path();

  for (my $run = 1; $run <= 2; $run++) {
    system("${latex} --interaction=nonstopmode $form->{tmpfile} " .
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

sub _get_latex_path {
  return $main::latex_bin || 'pdflatex';
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

  $variable = $main::locale->quote_special_chars('Template/HTML', $variable);

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  my @markup_replace = ('b', 'i', 's', 'u', 'sub', 'sup');

  foreach my $key (@markup_replace) {
    $variable =~ s/\&lt;(\/?)${key}\&gt;/<$1${key}>/g;
  }

  return $variable;
}

sub get_mime_type() {
  my ($self) = @_;

  if ($self->{"form"}->{"format"} =~ /postscript/i) {
    return "application/postscript";
  } elsif ($self->{"form"}->{"format"} =~ /pdf/i) {
    return "application/pdf";
  } else {
    return "text/html";
  }
}

sub uses_temp_file {
  my ($self) = @_;

  if ($self->{"form"}->{"format"} =~ /postscript/i) {
    return 1;
  } elsif ($self->{"form"}->{"format"} =~ /pdf/i) {
    return 1;
  } else {
    return 0;
  }
}

sub convert_to_postscript {
  my ($self) = @_;
  my ($form, $userspath) = ($self->{"form"}, $self->{"userspath"});

  # Convert the HTML file to postscript

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{"tmpfile"} =~ s/\Q$userspath\E\///g;
  my $psfile = $form->{"tmpfile"};
  $psfile =~ s/.html/.ps/;
  if ($psfile eq $form->{"tmpfile"}) {
    $psfile .= ".ps";
  }

  system("html2ps -f html2ps-config < $form->{tmpfile} > $psfile");
  if ($?) {
    $self->{"error"} = $form->cleanup();
    $self->cleanup();
    return 0;
  }

  $form->{"tmpfile"} = $psfile;

  $self->cleanup();

  return 1;
}

sub convert_to_pdf {
  my ($self) = @_;
  my ($form, $userspath) = ($self->{"form"}, $self->{"userspath"});

  # Convert the HTML file to PDF

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{"tmpfile"} =~ s/\Q$userspath\E\///g;
  my $pdffile = $form->{"tmpfile"};
  $pdffile =~ s/.html/.pdf/;
  if ($pdffile eq $form->{"tmpfile"}) {
    $pdffile .= ".pdf";
  }

  system("html2ps -f html2ps-config < $form->{tmpfile} | ps2pdf - $pdffile");
  if ($?) {
    $self->{"error"} = $form->cleanup();
    $self->cleanup();
    return 0;
  }

  $form->{"tmpfile"} = $pdffile;

  $self->cleanup();

  return 1;
}


####
#### PlainTextTemplate
####

package PlainTextTemplate;

use vars qw(@ISA);

@ISA = qw(LaTeXTemplate);

sub new {
  my $type = shift;

  return $type->SUPER::new(@_);
}

sub format_string {
  my ($self, $variable) = @_;

  return $variable;
}

sub get_mime_type {
  return "text/plain";
}

sub parse {
}

1;

####
#### OpenDocumentTemplate
####

package OpenDocumentTemplate;

use POSIX 'setsid';
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

  $self->{"rnd"}   = int(rand(1000000));
  $self->{"iconv"} = Text::Iconv->new($main::dbcharset, "UTF-8");

  $self->set_tag_style('&lt;%', '%&gt;');
  $self->{quot_re} = '&quot;';

  return $self;
}

sub parse_foreach {
  my ($self, $var, $text, $start_tag, $end_tag, @indices) = @_;

  my ($form, $new_contents) = ($self->{"form"}, "");

  my $ary = $self->_get_loop_variable($var, 1, @indices);

  for (my $i = 0; $i < scalar(@{$ary}); $i++) {
    $form->{"__first__"} = $i == 0;
    $form->{"__last__"} = ($i + 1) == scalar(@{$ary});
    $form->{"__odd__"} = (($i + 1) % 2) == 1;
    $form->{"__counter__"} = $i + 1;
    my $new_text = $self->parse_block($text, (@indices, $i));
    return undef unless (defined($new_text));
    $new_contents .= $start_tag . $new_text . $end_tag;
  }
  map({ delete($form->{"__${_}__"}); } qw(first last odd counter));

  return $new_contents;
}

sub find_end {
  my ($self, $text, $pos, $var, $not) = @_;

  my $depth = 1;
  $pos = 0 unless ($pos);

  while ($pos < length($text)) {
    $pos++;

    next if (substr($text, $pos - 1, 5) ne '&lt;%');

    if ((substr($text, $pos + 4, 2) eq 'if') || (substr($text, $pos + 4, 3) eq 'for')) {
      $depth++;

    } elsif ((substr($text, $pos + 4, 4) eq 'else') && (1 == $depth)) {
      if (!$var) {
        $self->{"error"} = '<%else%> outside of <%if%> / <%ifnot%>.';
        return undef;
      }

      my $block = substr($text, 0, $pos - 1);
      substr($text, 0, $pos - 1) = "";
      $text =~ s!^\&lt;\%[^\%]+\%\&gt;!!;
      $text = '&lt;%if' . ($not ?  " " : "not ") . $var . '%&gt;' . $text;

      return ($block, $text);

    } elsif (substr($text, $pos + 4, 3) eq 'end') {
      $depth--;
      if ($depth == 0) {
        my $block = substr($text, 0, $pos - 1);
        substr($text, 0, $pos - 1) = "";
        $text =~ s!^\&lt;\%[^\%]+\%\&gt;!!;

        return ($block, $text);
      }
    }
  }

  return undef;
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

          substr($table_row, length($`), length($&)) = "";

          my ($t1, $t2) = $self->find_end($table_row, length($`));
          if (!$t1) {
            $self->{"error"} = "Unclosed <\%foreachrow\%>." unless ($self->{"error"});
            $main::lxdebug->leave_sub();
            return undef;
          }

          my $new_text = $self->parse_foreach($var, $t1 . $t2, $tag, $end_tag, @indices);
          if (!defined($new_text)) {
            $main::lxdebug->leave_sub();
            return undef;
          }
          $new_contents .= $new_text;

        } else {
          my $new_text = $self->parse_block($table_row, @indices);
          if (!defined($new_text)) {
            $main::lxdebug->leave_sub();
            return undef;
          }
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

        my $block;
        ($block, $contents) = $self->find_end($contents);
        if (!$block) {
          $self->{"error"} = "Unclosed <\%foreach\%>." unless ($self->{"error"});
          $main::lxdebug->leave_sub();
          return undef;
        }

        my $new_text = $self->parse_foreach($var, $block, "", "", @indices);
        if (!defined($new_text)) {
          $main::lxdebug->leave_sub();
          return undef;
        }
        $new_contents .= $new_text;

      } else {
        if (!$self->_parse_block_if(\$contents, \$new_contents, $pos_if, @indices)) {
          $main::lxdebug->leave_sub();
          return undef;
        }
      }
    }
  }

  $main::lxdebug->leave_sub();

  return $new_contents;
}

sub parse {
  $main::lxdebug->enter_sub();

  my $self = $_[0];
  local *OUT = $_[1];
  my $form = $self->{"form"};

  close(OUT);

  my $file_name;
  if ($form->{"IN"} =~ m|^/|) {
    $file_name = $form->{"IN"};
  } else {
    $file_name = $form->{"templates"} . "/" . $form->{"IN"};
  }

  my $zip = Archive::Zip->new();
  if (Archive::Zip::AZ_OK != $zip->read($file_name)) {
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
</style:style>
<style:style style:name="TLXO${rnd}SUPER" style:family="text">
<style:text-properties style:text-position="super 58%"/>
</style:style>
<style:style style:name="TLXO${rnd}SUB" style:family="text">
<style:text-properties style:text-position="sub 58%"/>
</style:style>
|;

  $contents =~ s|</office:automatic-styles>|${new_styles}</office:automatic-styles>|;
  $contents =~ s|[\n\r]||gm;

  my $new_contents = $self->parse_block($contents);
  if (!defined($new_contents)) {
    $main::lxdebug->leave_sub();
    return 0;
  }

#   $new_contents =~ s|>|>\n|g;

  $zip->contents("content.xml", $new_contents);

  my $styles = $zip->contents("styles.xml");
  if ($contents) {
    my $new_styles = $self->parse_block($styles);
    if (!defined($new_contents)) {
      $main::lxdebug->leave_sub();
      return 0;
    }
    $zip->contents("styles.xml", $new_styles);
  }

  $zip->writeToFileNamed($form->{"tmpfile"}, 1);

  my $res = 1;
  if ($form->{"format"} =~ /pdf/) {
    $res = $self->convert_to_pdf();
  }

  $main::lxdebug->leave_sub();
  return $res;
}

sub is_xvfb_running {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  local *IN;
  my $dfname = $self->{"userspath"} . "/xvfb_display";
  my $display;

  $main::lxdebug->message(LXDebug::DEBUG2, "    Looking for $dfname\n");
  if ((-f $dfname) && open(IN, $dfname)) {
    my $pid = <IN>;
    chomp($pid);
    $display = <IN>;
    chomp($display);
    my $xauthority = <IN>;
    chomp($xauthority);
    close(IN);

    $main::lxdebug->message(LXDebug::DEBUG2, "      found with $pid and $display\n");

    if ((! -d "/proc/$pid") || !open(IN, "/proc/$pid/cmdline")) {
      $main::lxdebug->message(LXDebug::DEBUG2, "  no/wrong process #1\n");
      unlink($dfname, $xauthority);
      $main::lxdebug->leave_sub();
      return undef;
    }
    my $line = <IN>;
    close(IN);
    if ($line !~ /xvfb/i) {
      $main::lxdebug->message(LXDebug::DEBUG2, "      no/wrong process #2\n");
      unlink($dfname, $xauthority);
      $main::lxdebug->leave_sub();
      return undef;
    }

    $ENV{"XAUTHORITY"} = $xauthority;
    $ENV{"DISPLAY"} = $display;
  } else {
    $main::lxdebug->message(LXDebug::DEBUG2, "      not found\n");
  }

  $main::lxdebug->leave_sub();

  return $display;
}

sub spawn_xvfb {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  $main::lxdebug->message(LXDebug::DEBUG2, "spawn_xvfb()\n");

  my $display = $self->is_xvfb_running();

  if ($display) {
    $main::lxdebug->leave_sub();
    return $display;
  }

  $display = 99;
  while ( -f "/tmp/.X${display}-lock") {
    $display++;
  }
  $display = ":${display}";
  $main::lxdebug->message(LXDebug::DEBUG2, "  display $display\n");

  my $mcookie = `mcookie`;
  die("Installation error: mcookie not found.") if ($? != 0);
  chomp($mcookie);

  $main::lxdebug->message(LXDebug::DEBUG2, "  mcookie $mcookie\n");

  my $xauthority = "/tmp/.Xauthority-" . $$ . "-" . time() . "-" . int(rand(9999999));
  $ENV{"XAUTHORITY"} = $xauthority;

  $main::lxdebug->message(LXDebug::DEBUG2, "  xauthority $xauthority\n");

  system("xauth add \"${display}\" . \"${mcookie}\"");
  if ($? != 0) {
    $self->{"error"} = "Conversion to PDF failed because OpenOffice could not be started (xauth: $!)";
    $main::lxdebug->leave_sub();
    return undef;
  }

  $main::lxdebug->message(LXDebug::DEBUG2, "  about to fork()\n");

  my $pid = fork();
  if (0 == $pid) {
    $main::lxdebug->message(LXDebug::DEBUG2, "  Child execing\n");
    exec($main::xvfb_bin, $display, "-screen", "0", "640x480x8", "-nolisten", "tcp");
  }
  sleep(3);
  $main::lxdebug->message(LXDebug::DEBUG2, "  parent dont sleeping\n");

  local *OUT;
  my $dfname = $self->{"userspath"} . "/xvfb_display";
  if (!open(OUT, ">$dfname")) {
    $self->{"error"} = "Conversion to PDF failed because OpenOffice could not be started ($dfname: $!)";
    unlink($xauthority);
    kill($pid);
    $main::lxdebug->leave_sub();
    return undef;
  }
  print(OUT "$pid\n$display\n$xauthority\n");
  close(OUT);

  $main::lxdebug->message(LXDebug::DEBUG2, "  parent re-testing\n");

  if (!$self->is_xvfb_running()) {
    $self->{"error"} = "Conversion to PDF failed because OpenOffice could not be started.";
    unlink($xauthority, $dfname);
    kill($pid);
    $main::lxdebug->leave_sub();
    return undef;
  }

  $main::lxdebug->message(LXDebug::DEBUG2, "  spawn OK\n");

  $main::lxdebug->leave_sub();

  return $display;
}

sub is_openoffice_running {
  $main::lxdebug->enter_sub();

  system("./scripts/oo-uno-test-conn.py $main::openofficeorg_daemon_port " .
         "> /dev/null 2> /dev/null");
  my $res = $? == 0;
  $main::lxdebug->message(LXDebug::DEBUG2, "  is_openoffice_running(): $?\n");

  $main::lxdebug->leave_sub();

  return $res;
}

sub spawn_openoffice {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  $main::lxdebug->message(LXDebug::DEBUG2, "spawn_openoffice()\n");

  my ($try, $spawned_oo, $res);

  $res = 0;
  for ($try = 0; $try < 15; $try++) {
    if ($self->is_openoffice_running()) {
      $res = 1;
      last;
    }

    if (!$spawned_oo) {
      my $pid = fork();
      if (0 == $pid) {
        $main::lxdebug->message(LXDebug::DEBUG2, "  Child daemonizing\n");
        chdir('/');
        open(STDIN, '/dev/null');
        open(STDOUT, '>/dev/null');
        my $new_pid = fork();
        exit if ($new_pid);
        my $ssres = setsid();
        $main::lxdebug->message(LXDebug::DEBUG2, "  Child execing\n");
        my @cmdline = ($main::openofficeorg_writer_bin,
                       "-minimized", "-norestore", "-nologo", "-nolockcheck",
                       "-headless",
                       "-accept=socket,host=localhost,port=" .
                       $main::openofficeorg_daemon_port . ";urp;");
        exec(@cmdline);
      }

      $main::lxdebug->message(LXDebug::DEBUG2, "  Parent after fork\n");
      $spawned_oo = 1;
      sleep(3);
    }

    sleep($try >= 5 ? 2 : 1);
  }

  if (!$res) {
    $self->{"error"} = "Conversion from OpenDocument to PDF failed because " .
      "OpenOffice could not be started.";
  }

  $main::lxdebug->leave_sub();

  return $res;
}

sub convert_to_pdf {
  $main::lxdebug->enter_sub();

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

  if (!$self->spawn_xvfb()) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  my @cmdline;
  if (!$main::openofficeorg_daemon) {
    @cmdline = ($main::openofficeorg_writer_bin,
                "-minimized", "-norestore", "-nologo", "-nolockcheck",
                "-headless",
                "file:${filename}.odt",
                "macro://" . (split('/', $filename))[-1] .
                "/Standard.Conversion.ConvertSelfToPDF()");
  } else {
    if (!$self->spawn_openoffice()) {
      $main::lxdebug->leave_sub();
      return 0;
    }

    @cmdline = ("./scripts/oo-uno-convert-pdf.py",
                $main::openofficeorg_daemon_port,
                "${filename}.odt");
  }

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

  $variable = $main::locale->quote_special_chars('Template/OpenDocument', $variable);

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  my $rnd = $self->{"rnd"};
  my %markup_replace = ("b" => "BOLD", "i" => "ITALIC", "s" => "STRIKETHROUGH",
                        "u" => "UNDERLINE", "sup" => "SUPER", "sub" => "SUB");

  foreach my $key (keys(%markup_replace)) {
    my $value = $markup_replace{$key};
    $variable =~ s|\&lt;${key}\&gt;|<text:span text:style-name=\"TLXO${rnd}${value}\">|gi; #"
    $variable =~ s|\&lt;/${key}\&gt;|</text:span>|gi;
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


##########################################################
####
#### XMLTemplate
####
##########################################################

package XMLTemplate;

use vars qw(@ISA);

@ISA = qw(HTMLTemplate);

sub new {
  #evtl auskommentieren
  my $type = shift;

  return $type->SUPER::new(@_);
}

sub format_string {
  my ($self, $variable) = @_;
  my $form = $self->{"form"};

  $variable = $main::locale->quote_special_chars('Template/XML', $variable);

  # Allow no markup to be converted into the output format
  my @markup_replace = ('b', 'i', 's', 'u', 'sub', 'sup');

  foreach my $key (@markup_replace) {
    $variable =~ s/\&lt;(\/?)${key}\&gt;//g;
  }

  return $variable;
}

sub get_mime_type() {
  my ($self) = @_;

  if ($self->{"form"}->{"format"} =~ /elsterwinston/i) {
    return "application/xml ";
  } elsif ($self->{"form"}->{"format"} =~ /elstertaxbird/i) {
    return "application/x-taxbird";
  } else {
    return "text";
  }
}

sub uses_temp_file {
  # tempfile needet for XML Output
  return 1;
}

1;
