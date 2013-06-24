package SL::Template::OpenDocument;

use parent qw(SL::Template::Simple);

use Archive::Zip;
use Encode;
use POSIX 'setsid';

use SL::Iconv;

use Cwd;
# use File::Copy;
# use File::Spec;
# use File::Temp qw(:mktemp);
use IO::File;

use strict;

sub new {
  my $type = shift;

  my $self = $type->SUPER::new(@_);

  $self->{"rnd"}   = int(rand(1000000));

  $self->set_tag_style('&lt;%', '%&gt;');
  $self->{quot_re} = '&quot;';

  return $self;
}

sub parse_foreach {
  my ($self, $var, $text, $start_tag, $end_tag, @indices) = @_;

  my ($form, $new_contents) = ($self->{"form"}, "");

  my $ary = $self->_get_loop_variable($var, 1, @indices);

  for (my $i = 0; $i < scalar(@{$ary || []}); $i++) {
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

        if ($table_row =~ m|\&lt;\%foreachrow\s+(.*?)\%\&gt;|) {
          my $var = $1;

          $contents =~ m|\&lt;\%foreachrow\s+.*?\%\&gt;|;
          substr($contents, length($`), length($&)) = "";

          ($table_row, $contents) = $self->find_end($contents, length($`));
          if (!$table_row) {
            $self->{"error"} = "Unclosed <\%foreachrow\%>." unless ($self->{"error"});
            $main::lxdebug->leave_sub();
            return undef;
          }

          $contents   =~ m|^(.*?)(</table:table-row[^>]*>)|;
          $table_row .=  $1;
          $end_tag    =  $2;

          substr $contents, 0, length($&), '';

          my $new_text = $self->parse_foreach($var, $table_row, $tag, $end_tag, @indices);
          if (!defined($new_text)) {
            $main::lxdebug->leave_sub();
            return undef;
          }
          $new_contents .= $new_text;

        } else {
          substr($contents, 0, length($table_row) + length($end_tag)) = "";
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
  if (Archive::Zip->AZ_OK != $zip->read($file_name)) {
    $self->{"error"} = "File not found/is not a OpenDocument file.";
    $main::lxdebug->leave_sub();
    return 0;
  }

  my $contents = Encode::decode('utf-8-strict', $zip->contents("content.xml"));
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

  my $new_contents;
  if ($self->{use_template_toolkit}) {
    my $additional_params = $::form;

    $::form->init_template->process(\$contents, $additional_params, \$new_contents) || die $::form->template->error;
  } else {
    $new_contents = $self->parse_block($contents);
  }
  if (!defined($new_contents)) {
    $main::lxdebug->leave_sub();
    return 0;
  }

#   $new_contents =~ s|>|>\n|g;

  $zip->contents("content.xml", Encode::encode('utf-8-strict', $new_contents));

  my $styles = Encode::decode('utf-8-strict', $zip->contents("styles.xml"));
  if ($contents) {
    my $new_styles = $self->parse_block($styles);
    if (!defined($new_contents)) {
      $main::lxdebug->leave_sub();
      return 0;
    }
    $zip->contents("styles.xml", Encode::encode('utf-8-strict', $new_styles));
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

  $main::lxdebug->message(LXDebug->DEBUG2(), "    Looking for $dfname\n");
  if ((-f $dfname) && open(IN, $dfname)) {
    my $pid = <IN>;
    chomp($pid);
    $display = <IN>;
    chomp($display);
    my $xauthority = <IN>;
    chomp($xauthority);
    close(IN);

    $main::lxdebug->message(LXDebug->DEBUG2(), "      found with $pid and $display\n");

    if ((! -d "/proc/$pid") || !open(IN, "/proc/$pid/cmdline")) {
      $main::lxdebug->message(LXDebug->DEBUG2(), "  no/wrong process #1\n");
      unlink($dfname, $xauthority);
      $main::lxdebug->leave_sub();
      return undef;
    }
    my $line = <IN>;
    close(IN);
    if ($line !~ /xvfb/i) {
      $main::lxdebug->message(LXDebug->DEBUG2(), "      no/wrong process #2\n");
      unlink($dfname, $xauthority);
      $main::lxdebug->leave_sub();
      return undef;
    }

    $ENV{"XAUTHORITY"} = $xauthority;
    $ENV{"DISPLAY"} = $display;
  } else {
    $main::lxdebug->message(LXDebug->DEBUG2(), "      not found\n");
  }

  $main::lxdebug->leave_sub();

  return $display;
}

sub spawn_xvfb {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  $main::lxdebug->message(LXDebug->DEBUG2, "spawn_xvfb()\n");

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
  $main::lxdebug->message(LXDebug->DEBUG2(), "  display $display\n");

  my $mcookie = `mcookie`;
  die("Installation error: mcookie not found.") if ($? != 0);
  chomp($mcookie);

  $main::lxdebug->message(LXDebug->DEBUG2(), "  mcookie $mcookie\n");

  my $xauthority = "/tmp/.Xauthority-" . $$ . "-" . time() . "-" . int(rand(9999999));
  $ENV{"XAUTHORITY"} = $xauthority;

  $main::lxdebug->message(LXDebug->DEBUG2(), "  xauthority $xauthority\n");

  system("xauth add \"${display}\" . \"${mcookie}\"");
  if ($? != 0) {
    $self->{"error"} = "Conversion to PDF failed because OpenOffice could not be started (xauth: $!)";
    $main::lxdebug->leave_sub();
    return undef;
  }

  $main::lxdebug->message(LXDebug->DEBUG2(), "  about to fork()\n");

  my $pid = fork();
  if (0 == $pid) {
    $main::lxdebug->message(LXDebug->DEBUG2(), "  Child execing\n");
    exec($::lx_office_conf{applications}->{xvfb}, $display, "-screen", "0", "640x480x8", "-nolisten", "tcp");
  }
  sleep(3);
  $main::lxdebug->message(LXDebug->DEBUG2(), "  parent dont sleeping\n");

  local *OUT;
  my $dfname = $self->{"userspath"} . "/xvfb_display";
  if (!open(OUT, ">", $dfname)) {
    $self->{"error"} = "Conversion to PDF failed because OpenOffice could not be started ($dfname: $!)";
    unlink($xauthority);
    kill($pid);
    $main::lxdebug->leave_sub();
    return undef;
  }
  print(OUT "$pid\n$display\n$xauthority\n");
  close(OUT);

  $main::lxdebug->message(LXDebug->DEBUG2(), "  parent re-testing\n");

  if (!$self->is_xvfb_running()) {
    $self->{"error"} = "Conversion to PDF failed because OpenOffice could not be started.";
    unlink($xauthority, $dfname);
    kill($pid);
    $main::lxdebug->leave_sub();
    return undef;
  }

  $main::lxdebug->message(LXDebug->DEBUG2(), "  spawn OK\n");

  $main::lxdebug->leave_sub();

  return $display;
}

sub _run_python_uno {
  my ($self, @args) = @_;

  local $ENV{PYTHONPATH};
  $ENV{PYTHONPATH} = $::lx_office_conf{environment}->{python_uno_path} . ':' . $ENV{PYTHONPATH} if $::lx_office_conf{environment}->{python_uno_path};
  my $cmd          = $::lx_office_conf{applications}->{python_uno} . ' ' . join(' ', @args);
  return `$cmd`;
}

sub is_openoffice_running {
  my ($self) = @_;

  $main::lxdebug->enter_sub();

  my $output = $self->_run_python_uno('./scripts/oo-uno-test-conn.py', $::lx_office_conf{print_templates}->{openofficeorg_daemon_port}, ' 2> /dev/null');
  chomp $output;

  my $res = ($? == 0) || $output;
  $main::lxdebug->message(LXDebug->DEBUG2(), "  is_openoffice_running(): res $res\n");

  $main::lxdebug->leave_sub();

  return $res;
}

sub spawn_openoffice {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  $main::lxdebug->message(LXDebug->DEBUG2(), "spawn_openoffice()\n");

  my ($try, $spawned_oo, $res);

  $res = 0;
  for ($try = 0; $try < 15; $try++) {
    if ($self->is_openoffice_running()) {
      $res = 1;
      last;
    }

    if ($::dispatcher->interface_type eq 'FastCGI') {
      $::dispatcher->{request}->Detach;
    }

    if (!$spawned_oo) {
      my $pid = fork();
      if (0 == $pid) {
        $main::lxdebug->message(LXDebug->DEBUG2(), "  Child daemonizing\n");

        if ($::dispatcher->interface_type eq 'FastCGI') {
          $::dispatcher->{request}->Finish;
          $::dispatcher->{request}->LastCall;
        }
        chdir('/');
        open(STDIN, '/dev/null');
        open(STDOUT, '>/dev/null');
        my $new_pid = fork();
        exit if ($new_pid);
        my $ssres = setsid();
        $main::lxdebug->message(LXDebug->DEBUG2(), "  Child execing\n");
        my @cmdline = ($::lx_office_conf{applications}->{openofficeorg_writer},
                       "-minimized", "-norestore", "-nologo", "-nolockcheck",
                       "-headless",
                       "-accept=socket,host=localhost,port=" .
                       $::lx_office_conf{print_templates}->{openofficeorg_daemon_port} . ";urp;");
        exec(@cmdline);
      } else {
        # parent
        if ($::dispatcher->interface_type eq 'FastCGI') {
          $::dispatcher->{request}->Attach;
        }
      }

      $main::lxdebug->message(LXDebug->DEBUG2(), "  Parent after fork\n");
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

  if (!$::lx_office_conf{print_templates}->{openofficeorg_daemon}) {
    system($::lx_office_conf{applications}->{openofficeorg_writer},
           "-minimized", "-norestore", "-nologo", "-nolockcheck", "-headless",
           "file:${filename}.odt",
           "macro://" . (split('/', $filename))[-1] . "/Standard.Conversion.ConvertSelfToPDF()");
  } else {
    if (!$self->spawn_openoffice()) {
      $main::lxdebug->leave_sub();
      return 0;
    }

    $self->_run_python_uno('./scripts/oo-uno-convert-pdf.py', $::lx_office_conf{print_templates}->{openofficeorg_daemon_port}, "${filename}.odt");
  }

  my $res = $?;
  if ((0 == $?) || (-f "${filename}.pdf" && -s "${filename}.pdf")) {
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

  return $variable;
}

sub get_mime_type() {
  my ($self) = @_;

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
