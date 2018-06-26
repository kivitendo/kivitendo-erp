package SL::Template::LaTeX;

use parent qw(SL::Template::Simple);

use strict;

use Carp;
use Cwd;
use English qw(-no_match_vars);
use File::Basename;
use File::Temp;
use HTML::Entities ();
use List::MoreUtils qw(any);
use Unicode::Normalize qw();

use SL::DB::Default;

my %text_markup_replace = (
  b => 'textbf',
  i => 'textit',
  u => 'underline',
);

sub _format_text {
  my ($self, $content, %params) = @_;

  $content = $::locale->quote_special_chars('Template/LaTeX', $content);

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  foreach my $key (keys(%text_markup_replace)) {
    my $new   =  $text_markup_replace{$key};
    $content =~ s/\$\<\$${key}\$\>\$(.*?)\$<\$\/${key}\$>\$/\\${new}\{$1\}/gi;
  }

  $content =~ s/[\x00-\x1f]//g;

  return $content;
}

my %html_replace = (
  '</p>'      => "\n\n",
  '<ul>'      => "\\begin{itemize} ",
  '</ul>'     => "\\end{itemize} ",
  '<ol>'      => "\\begin{enumerate} ",
  '</ol>'     => "\\end{enumerate} ",
  '<li>'      => "\\item ",
  '</li>'     => " ",
  '<b>'       => "\\textbf{",
  '</b>'      => "}",
  '<strong>'  => "\\textbf{",
  '</strong>' => "}",
  '<i>'       => "\\textit{",
  '</i>'      => "}",
  '<em>'      => "\\textit{",
  '</em>'     => "}",
  '<u>'       => "\\underline{",
  '</u>'      => "}",
  '<s>'       => "\\sout{",
  '</s>'      => "}",
  '<sub>'     => "\\textsubscript{",
  '</sub>'    => "}",
  '<sup>'     => "\\textsuperscript{",
  '</sup>'    => "}",
  '<br/>'     => "\\newline ",
  '<br>'      => "\\newline ",
);

sub _lb_to_space {
  my ($to_replace) = @_;

  my $vspace = '\vspace*{0.5cm}';
  return $vspace x (length($to_replace) / length($html_replace{'<br>'}));
}

sub _format_html {
  my ($self, $content, %params) = @_;

  $content =~ s{ \r+ }{}gx;
  $content =~ s{ \n+ }{ }gx;
  $content =~ s{ (?:\&nbsp;|\s)+ }{ }gx;
  $content =~ s{ (?:\&nbsp;|\s)+$ }{}gx;
  $content =~ s{ (?: <br/?> )+$ }{}gx;

  my @parts = grep { $_ } map {
    if (substr($_, 0, 1) eq '<') {
      s{ +}{}g;
      $html_replace{$_} || '';

    } else {
      $::locale->quote_special_chars('Template/LaTeX', HTML::Entities::decode_entities($_));
    }
  } split(m{(<.*?>)}x, $content);

  $content =  join '', @parts;
  $content =~ s{ (?: [\n\s] | \\newline )+ $ }{}gx;                                         # remove line breaks at the end of the text
  $content =~ s{ ^ \s+ }{}gx;                                                               # remove white space at the start of the text
  $content =~ s{ ^ ( \\newline \  )+ }{ _lb_to_space($1) }gxe;                              # convert line breaks at the start of the text to vertical space
  $content =~ s{ ( \n\n+ ) ( \\newline \  )+ }{ $1 . _lb_to_space($2) }gxe;                 # convert line breaks at the start of a paragraph to vertical space
  $content =~ s{ ( \\end\{ [^\}]+ \} \h* ) ( \\newline \  )+ }{ $1 . _lb_to_space($2) }gxe; # convert line breaks after LaTeX environments like lists to vertical space
  $content =~ s{ ^ \h+ \\newline }{\\newline}gmx;
  $content =~ s{ \n\n \h* \\newline \h* }{\n\n}gmx;

  return $content;
}

my %formatters = (
  html => \&_format_html,
  text => \&_format_text,
);

sub new {
  my $type = shift;

  my $self = $type->SUPER::new(@_);

  return $self;
}

sub format_string {
  my ($self, $content, $variable) = @_;

  my $formatter =
       $formatters{ $self->{variable_content_types}->{$variable} }
    // $formatters{ $self->{default_content_type} }
    // $formatters{ text };

  $content  =~ s{[^\p{Print}\n]|\p{Cf}}{}g;
  $variable =~ s{[^\p{Print}\n]|\p{Cf}}{}g;

  return $formatter->($self, $content, variable => $variable);
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

  # forech block hasn't given us an array. ignore
  return $new_contents unless ref $ary eq 'ARRAY';

  for (my $i = 0; $i < scalar(@{$ary}); $i++) {
    # do magic markers
    $form->{"__first__"}   = $i == 0;
    $form->{"__last__"}    = ($i + 1) == scalar(@{$ary});
    $form->{"__odd__"}     = (($i + 1) % 2) == 1;
    $form->{"__counter__"} = $i + 1;

  #everything from here to the next marker should be removed after the release of 2.7.0
    if (   ref $description_array       eq 'ARRAY'
        && scalar @{$description_array} == scalar @{$ary}
        && $self->{"chars_per_line"}    != 0)
    {
      my $lines = int(length($description_array->[$i]) / $self->{"chars_per_line"});
      my $lpp;

      $description_array->[$i] =~ s/(\\newline\s?)*$//;
      $lines++ while ($description_array->[$i] =~ m/\\newline/g);
      $lines++;

      if ($current_page == 1) {
        $lpp = $self->{"lines_on_first_page"};
      } else {
        $lpp = $self->{"lines_on_second_page"};
      }

      # Yes we need a manual page break -- or the user has forced one
      if (   (($current_line + $lines) > $lpp)
          || ($description_array->[$i]     =~ /<pagebreak>/)
          || (   ref $longdescription_array eq 'ARRAY'
              && $longdescription_array->[$i] =~ /<pagebreak>/)) {
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
  #stop removing code here.

    if (   ref $linetotal_array eq 'ARRAY'
        && $i < scalar(@{$linetotal_array})) {
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

    if ((substr($text, $keyword_pos, 2) eq 'if') || (substr($text, $keyword_pos, 7) eq 'foreach')) {
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

      if ($contents !~ m|^($self->{tag_start_qm}foreach (.+?)$self->{tag_end_qm})|) {
        $self->{"error"} = "Malformed $self->{tag_start}foreach$self->{tag_end}.";
        $main::lxdebug->leave_sub();
        return undef;
      }

      my $var = $2;

      substr($contents, 0, length($1)) = "";

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
  if ($key eq 'use-template-toolkit') {
    $self->set_use_template_toolkit($value);
  }
}

sub _parse_config_lines {
  my $self  = shift;
  my $lines = shift;

  my ($comment_start, $comment_end) = ("", "");

  if (ref $self eq 'SL::Template::LaTeX') {
    $comment_start = '\s*%';
  } elsif (ref $self eq 'SL::Template::HTML') {
    $comment_start = '\s*<!--';
    $comment_end   = '(?:--)?>\s*';
  } else {
    $comment_start = '\s*\#';
  }

  my $num_lines = scalar @{ $lines };
  my $i         = 0;

  while ($i < $num_lines) {
    my $line = $lines->[$i];

    if ($line !~ m/^${comment_start}\s*config\s*:(.*?)${comment_end}$/i) {
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

  my (%used_packages, $document_start_line, $last_usepackage_line);

  foreach my $i (0 .. scalar @{ $lines } - 1) {
    if ($lines->[$i] =~ m/\\usepackage[^\{]*{(.*?)}/) {
      $used_packages{$1} = 1;
      $last_usepackage_line = $i;

    } elsif ($lines->[$i] =~ m/\\begin\{document\}/) {
      $document_start_line = $i;
      last;

    }
  }

  my $insertion_point = defined($document_start_line)  ? $document_start_line
                      : defined($last_usepackage_line) ? $last_usepackage_line
                      :                                  scalar @{ $lines } - 1;

  foreach my $package (qw(textcomp ulem)) {
    next if $used_packages{$package};
    splice @{ $lines }, $insertion_point, 0, "\\usepackage{${package}}\n";
    $insertion_point++;
  }
}

sub parse {
  my $self = $_[0];
  local *OUT = $_[1];
  my $form = $self->{"form"};

  if (!open(IN, "$form->{templates}/$form->{IN}")) {
    $self->{"error"} = "$form->{templates}/$form->{IN}: $!";
    return 0;
  }
  binmode IN, ":utf8";
  my @lines = <IN>;
  close(IN);

  $self->_parse_config_lines(\@lines);
  $self->_force_mandatory_packages(\@lines) if (ref $self eq 'SL::Template::LaTeX');

  my $contents = join("", @lines);

  # detect pagebreak block and its parameters
  if ($contents =~ /^(.*)($self->{tag_start_qm}pagebreak\s+(\d+)\s+(\d+)\s+(\d+)\s*$self->{tag_end_qm}(.*?)$self->{tag_start_qm}end(\s*pagebreak)?$self->{tag_end_qm})/s) {
    $self->{"chars_per_line"} = $3;
    $self->{"lines_on_first_page"} = $4;
    $self->{"lines_on_second_page"} = $5;
    $self->{"pagebreak_block"} = $6;

    substr($contents, length($1), length($2)) = "";
  }

  $self->{"forced_pagebreaks"} = [];

  my $new_contents;
  if ($self->{use_template_toolkit}) {
    if ($self->{custom_tag_style}) {
      $contents = "[% TAGS $self->{tag_start} $self->{tag_end} %]\n" . $contents;
    }

    my $globals = global_vars();

    $::form->template->process(\$contents, { %$form, %$globals }, \$new_contents) || die $::form->template->error;
  } else {
    $new_contents = $self->parse_block($contents);
  }
  if (!defined($new_contents)) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  binmode OUT, ":utf8";
  print OUT Unicode::Normalize::normalize('C', $new_contents);

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
  local $ENV{TEXINPUTS} = ".:" . $form->{cwd} . "/" . $form->{templates} . ":" . $ENV{TEXINPUTS};

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{tmpfile} =~ s/\Q$userspath\E\///g;

  my $latex = $self->_get_latex_path();
  my $old_home = $ENV{HOME};
  my $old_openin_any = $ENV{openin_any};
  $ENV{HOME}   = $userspath =~ m|^/| ? $userspath : getcwd();
  $ENV{openin_any} = "p";

  for (my $run = 1; $run <= 2; $run++) {
    if (system("${latex} --interaction=nonstopmode $form->{tmpfile} " .
               "> $form->{tmpfile}.err") == -1) {
      die "system call to $latex failed: $!";
    }
    if ($?) {
      $ENV{HOME} = $old_home;
      $ENV{openin_any} = $old_openin_any;
      $self->{"error"} = $form->cleanup($latex);
      return 0;
    }
  }

  $form->{tmpfile} =~ s/tex$/dvi/;

  if (system("dvips $form->{tmpfile} -o -q > /dev/null") == -1) {
    die "system call to dvips failed: $!";
  }
  $ENV{HOME} = $old_home;
  $ENV{openin_any} = $old_openin_any;

  if ($?) {
    $self->{"error"} = "dvips : $?";
    $self->cleanup('dvips');
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
  local $ENV{TEXINPUTS} = ".:" . $form->{cwd} . "/" . $form->{templates} . ":" . $ENV{TEXINPUTS};

  if (!chdir("$userspath")) {
    $self->{"error"} = "chdir : $!";
    $self->cleanup();
    return 0;
  }

  $form->{tmpfile} =~ s/\Q$userspath\E\///g;

  my $latex = $self->_get_latex_path();
  my $old_home = $ENV{HOME};
  my $old_openin_any = $ENV{openin_any};
  $ENV{HOME}   = $userspath =~ m|^/| ? $userspath : getcwd();
  $ENV{openin_any} = "p";

  for (my $run = 1; $run <= 2; $run++) {
    if (system("${latex} --interaction=nonstopmode $form->{tmpfile} " .
               "> $form->{tmpfile}.err") == -1) {
      die "system call to $latex failed: $!";
    }

    if ($?) {
      $ENV{HOME}     = $old_home;
      $ENV{openin_any} = $old_openin_any;
      $self->{error} = $form->cleanup($latex);
      return 0;
    }
  }

  $ENV{HOME} = $old_home;
  $ENV{openin_any} = $old_openin_any;
  $form->{tmpfile} =~ s/tex$/pdf/;

  $self->cleanup();

  return 1;
}

sub _get_latex_path {
  return $::lx_office_conf{applications}->{latex} || 'pdflatex';
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

sub parse_and_create_pdf {
  my ($class, $template_file_name, %params) = @_;

  my $keep_temp                = $::lx_office_conf{debug} && $::lx_office_conf{debug}->{keep_temp_files};
  my ($tex_fh, $tex_file_name) = File::Temp::tempfile(
    'kivitendo-printXXXXXX',
    SUFFIX => '.tex',
    DIR    => $::lx_office_conf{paths}->{userspath},
    UNLINK => $keep_temp ? 0 : 1,,
  );

  my $old_wd               = getcwd();

  my $local_form           = Form->new('');
  $local_form->{cwd}       = $old_wd;
  $local_form->{IN}        = $template_file_name;
  $local_form->{tmpdir}    = $::lx_office_conf{paths}->{userspath};
  $local_form->{tmpfile}   = $tex_file_name;
  $local_form->{templates} = SL::DB::Default->get->templates;

  foreach (keys %params) {
    croak "The parameter '$_' must not be used." if exists $local_form->{$_};
    $local_form->{$_} = $params{$_};
  }

  my $error;
  eval {
    my $template = SL::Template::LaTeX->new(file_name => $template_file_name, form => $local_form);
    my $result   = $template->parse($tex_fh) && $template->convert_to_pdf;

    die $template->{error} unless $result;

    1;
  } or do { $error = $EVAL_ERROR; };

  chdir $old_wd;
  close $tex_fh;

  if ($keep_temp) {
    chmod(((stat $tex_file_name)[2] & 07777) | 0660, $tex_file_name);
  } else {
    my $tmpfile =  $tex_file_name;
    $tmpfile    =~ s/\.\w+$//;
    unlink(grep { !m/\.pdf$/ } <$tmpfile.*>);
  }

  return (error     => $error) if $error;
  return (file_name => do { $tex_file_name =~ s/tex$/pdf/; $tex_file_name });
}

sub global_vars {
  {
    AUTH            => $::auth,
    INSTANCE_CONF   => $::instance_conf,
    LOCALE          => $::locale,
    LXCONFIG        => $::lx_office_conf,
    LXDEBUG         => $::lxdebug,
    MYCONFIG        => \%::myconfig,
  };
}

1;
