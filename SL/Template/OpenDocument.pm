package SL::Template::OpenDocument;

use parent qw(SL::Template::Simple);

use Archive::Zip;
use Encode;
use HTML::Entities;
use POSIX 'setsid';
use XML::LibXML;

use SL::Iconv;
use SL::Template::OpenDocument::Styles;

use SL::DB::BankAccount;
use SL::Helper::QrBill;
use SL::Helper::QrBillFunctions qw(get_qrbill_account get_ref_number_formatted
  get_iban_formatted get_amount_formatted);
use SL::Helper::ISO3166;

use Cwd;
# use File::Copy;
# use File::Spec;
# use File::Temp qw(:mktemp);
use IO::File;

use strict;

my %text_markup_replace = (
  b   => "BOLD",
  i   => "ITALIC",
  s   => "STRIKETHROUGH",
  u   => "UNDERLINE",
  sup => "SUPER",
  sub => "SUB",
);

sub _format_text {
  my ($self, $content, %params) = @_;

  $content = $::locale->quote_special_chars('Template/OpenDocument', $content);

  # Allow some HTML markup to be converted into the output format's
  # corresponding markup code, e.g. bold or italic.
  foreach my $key (keys(%text_markup_replace)) {
    my $value = $text_markup_replace{$key};
    $content =~ s|\&lt;${key}\&gt;|<text:span text:style-name=\"TKIVITENDO${value}\">|gi; #"
    $content =~ s|\&lt;/${key}\&gt;|</text:span>|gi;
  }

  return $content;
}

my %html_replace = (
  '</ul>'     => '</text:list>',
  '</ol>'     => '</text:list>',
  '</li>'     => '</text:p></text:list-item>',
  '<b>'       => '<text:span text:style-name="TKIVITENDOBOLD">',
  '</b>'      => '</text:span>',
  '<strong>'  => '<text:span text:style-name="TKIVITENDOBOLD">',
  '</strong>' => '</text:span>',
  '<i>'       => '<text:span text:style-name="TKIVITENDOITALIC">',
  '</i>'      => '</text:span>',
  '<em>'      => '<text:span text:style-name="TKIVITENDOITALIC">',
  '</em>'     => '</text:span>',
  '<u>'       => '<text:span text:style-name="TKIVITENDOUNDERLINE">',
  '</u>'      => '</text:span>',
  '<s>'       => '<text:span text:style-name="TKIVITENDOSTRIKETHROUGH">',
  '</s>'      => '</text:span>',
  '<sub>'     => '<text:span text:style-name="TKIVITENDOSUB">',
  '</sub>'    => '</text:span>',
  '<sup>'     => '<text:span text:style-name="TKIVITENDOSUPER">',
  '</sup>'    => '</text:span>',
  '<br/>'     => '<text:line-break/>',
  '<br>'      => '<text:line-break/>',
);

sub _format_html {
  my ($self, $content, %params) = @_;

  my $in_p        = 0;
  my $p_start_tag = qq|<text:p text:style-name="@{[ $self->{current_text_style} ]}">|;
  my $prefix      = '';
  my $suffix      = '';

  my (@tags_to_open, @tags_to_close);
  for (my $idx = scalar(@{ $self->{tag_stack} }) - 1; $idx >= 0; --$idx) {
    my $tag = $self->{tag_stack}->[$idx];

    next if $tag =~ m{/>$};
    last if $tag =~ m{^<table};

    if ($tag =~ m{^<text:p}) {
      $in_p        = 1;
      $p_start_tag = $tag;
      last;

    } else {
      $suffix  =  "${tag}${suffix}";
      $tag     =~ s{ .*>}{>};
      $prefix .=  '</' . substr($tag, 1);
    }
  }

  $content            =~ s{ ^<p> | </p>$ }{}gx if $in_p;
  $content            =~ s{ \r+ }{}gx;
  $content            =~ s{ \n+ }{ }gx;
  $content            =~ s{ (?:\&nbsp;|\s)+ }{ }gx;

  my $ul_start_tag    = qq|<text:list xml:id="list@{[ int rand(9999999999999999) ]}" text:style-name="LKIVITENDOitemize@{[ $self->{current_text_style} ]}">|;
  my $ol_start_tag    = qq|<text:list xml:id="list@{[ int rand(9999999999999999) ]}" text:style-name="LKIVITENDOenumerate@{[ $self->{current_text_style} ]}">|;
  my $ul_li_start_tag = qq|<text:list-item><text:p text:style-name="PKIVITENDOitemize@{[ $self->{current_text_style} ]}">|;
  my $ol_li_start_tag = qq|<text:list-item><text:p text:style-name="PKIVITENDOenumerate@{[ $self->{current_text_style} ]}">|;

  my @parts = map {
    if (substr($_, 0, 1) eq '<') {
      s{ +}{}g;
      if ($_ eq '</p>') {
        $in_p--;
        $in_p == 0 ? '</text:p>' : '';

      } elsif ($_ eq '<p>') {
        $in_p++;
        $in_p == 1 ? $p_start_tag : '';

      } elsif ($_ eq '<ul>') {
        $self->{used_list_styles}->{itemize}->{$self->{current_text_style}}   = 1;
        $html_replace{'<li>'}                                                 = $ul_li_start_tag;
        $ul_start_tag;

      } elsif ($_ eq '<ol>') {
        $self->{used_list_styles}->{enumerate}->{$self->{current_text_style}} = 1;
        $html_replace{'<li>'}                                                 = $ol_li_start_tag;
        $ol_start_tag;

      } else {
        $html_replace{$_} || '';
      }

    } else {
      $::locale->quote_special_chars('Template/OpenDocument', HTML::Entities::decode_entities($_));
    }
  } split(m{(<.*?>)}x, $content);

  my $out  = join('', $prefix, @parts, $suffix);

  # $::lxdebug->dump(0, "prefix parts suffix", [ $prefix, join('', @parts), $suffix ]);

  return $out;
}

my %formatters = (
  html => \&_format_html,
  text => \&_format_text,
);

sub new {
  my $type = shift;

  my $self = $type->SUPER::new(@_);

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
      $contents =~ m|^(<[^>]+>)|;
      my $tag = $1;
      substr($contents, 0, length($1)) = "";

      $self->{current_text_style} = $1 if $tag =~ m|text:style-name\s*=\s*"([^"]+)"|;

      push @{ $self->{tag_stack} }, $tag;

      if ($tag =~ m|<table:table-row|) {
        $contents =~ m|^(.*?)(</table:table-row[^>]*>)|;
        my $table_row = $1;
        my $end_tag = $2;

        if ($table_row =~ m|\&lt;\%foreachrow\s+(.*?)\%\&gt;|) {
          my $var = $1;

          $contents =~ m|^(.*?)(\&lt;\%foreachrow\s+.*?\%\&gt;)|;
          substr($contents, length($1), length($2)) = "";

          ($table_row, $contents) = $self->find_end($contents, length($1));
          if (!$table_row) {
            $self->{"error"} = "Unclosed <\%foreachrow\%>." unless ($self->{"error"});
            $main::lxdebug->leave_sub();
            return undef;
          }

          $contents   =~ m|^(.*?)(</table:table-row[^>]*>)|;
          $table_row .=  $1;
          $end_tag    =  $2;

          substr $contents, 0, length($1) + length($2), '';

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

      if ($tag =~ m{^</ | />$}x) {
        # $::lxdebug->message(0, "popping top tag is $tag top " . $self->{tag_stack}->[-1]);
        pop @{ $self->{tag_stack} };
      }

    } else {
      $contents =~ /^([^<]+)/;
      my $text = $1;

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

        if ($contents !~ m|^(\&lt;\%foreach (.*?)\%\&gt;)|) {
          $self->{"error"} = "Malformed <\%foreach\%>.";
          $main::lxdebug->leave_sub();
          return undef;
        }

        my $var = $2;

        substr($contents, 0, length($1)) = "";

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

  my $is_qr_bill = $::instance_conf->get_create_qrbill_invoices &&
                   $form->{formname} eq 'invoice' &&
                   $form->{'template_meta'}->{'printer'}->{'template_code'} =~ m/qr/ ?
                   1 : 0;

  my $qr_image_path;
  if ($is_qr_bill) {
    # the biller account information, biller address and the reference number,
    # are needed in the template aswell as in the qr-code generation, therefore
    # assemble these and add to $::form
    $qr_image_path = $self->generate_qr_code;
  }

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

  $self->{current_text_style} =  '';
  $self->{used_list_styles}   =  {
    itemize                   => {},
    enumerate                 => {},
  };

  my $new_contents;
  if ($self->{use_template_toolkit}) {
    my $additional_params = $::form;

    $::form->template->process(\$contents, $additional_params, \$new_contents) || die $::form->template->error;
  } else {
    $self->{tag_stack} = [];
    $new_contents = $self->parse_block($contents);
  }
  if (!defined($new_contents)) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  my $new_styles = SL::Template::OpenDocument::Styles->get_style('text_basic');

  foreach my $type (qw(itemize enumerate)) {
    foreach my $parent (sort { $a cmp $b } keys %{ $self->{used_list_styles}->{$type} }) {
      $new_styles .= SL::Template::OpenDocument::Styles->get_style('text_list_item', TYPE => $type, PARENT => $parent)
                   .  SL::Template::OpenDocument::Styles->get_style("list_${type}",  TYPE => $type, PARENT => $parent);
    }
  }

  # $::lxdebug->dump(0, "new_Styles", $new_styles);

  $new_contents =~ s|</office:automatic-styles>|${new_styles}</office:automatic-styles>|;
  $new_contents =~ s|[\n\r]||gm;

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

  if ($is_qr_bill) {
    # get placeholder path from odt XML
    my $qr_placeholder_path;
    my $dom = XML::LibXML->load_xml(string => $contents);
    my @nodelist = $dom->getElementsByTagName("draw:frame");
    for my $node (@nodelist) {
      my $attr = $node->getAttribute('draw:name');
      if ($attr eq 'QRCodePlaceholder') {
        my @children = $node->getChildrenByTagName('draw:image');
        $qr_placeholder_path = $children[0]->getAttribute('xlink:href');
      }
    }
    if (!defined($qr_placeholder_path)) {
      $::form->error($::locale->text('QR-Code placeholder image: QRCodePlaceholder not found in template.'));
    }
    # replace QR-Code Placeholder Image in zip file (odt) with generated one
    $zip->updateMember(
     $qr_placeholder_path,
     $qr_image_path
    );
  }

  $zip->writeToFileNamed($form->{"tmpfile"}, 1);

  my $res = 1;
  if ($form->{"format"} =~ /pdf/) {
    $res = $self->convert_to_pdf();
  }

  $main::lxdebug->leave_sub();
  return $res;
}

sub generate_qr_code {
  $main::lxdebug->enter_sub();
  my $self = $_[0];
  my $form = $self->{"form"};

  # assemble data for QR-Code

  # get qr-account data
  my ($qr_account, $error) = get_qrbill_account();
  if (!$qr_account) {
    $::form->error($error);
  }

  my %biller_information = (
    'iban' => $qr_account->{'iban'}
  );

  my $biller_country = $::instance_conf->get_address_country() || 'CH';
  my $biller_countrycode = SL::Helper::ISO3166::map_name_to_alpha_2_code($biller_country);
  if (!$biller_countrycode) {
    $::form->error($::locale->text('Error mapping biller countrycode.'));
  }
  my %biller_data = (
    'address_type' => 'K',
    'company' => $::instance_conf->get_company(),
    'address_row1' => $::instance_conf->get_address_street1(),
    'address_row2' => $::instance_conf->get_address_zipcode() . ' ' . $::instance_conf->get_address_city(),
    'countrycode' => $biller_countrycode,
  );

  my ($amount, $amount_formatted);
  if ($form->{'qrbill_without_amount'}) {
    $amount = '';
    $amount_formatted = '';
  } else {
    $amount = sprintf("%.2f", $form->parse_amount(\%::myconfig, $form->{'total'}));

    # format amount for template
    $amount_formatted = get_amount_formatted($amount);
    if (!$amount_formatted) {
      $::form->error($::locale->text('Amount has wrong format.'));
    }
  }

  my %payment_information = (
    'amount' => $amount,
    'currency' => $form->{'currency'},
  );

  my $customer_country = $form->{'country'} || 'CH';
  my $customer_countrycode = SL::Helper::ISO3166::map_name_to_alpha_2_code($customer_country);
  if (!$customer_countrycode) {
    $::form->error($::locale->text('Error mapping customer countrycode.'));
  }
  my %invoice_recipient_data = (
    'address_type' => 'K',
    'name' => $form->{'name'},
    'address_row1' => $form->{'street'},
    'address_row2' => $form->{'zipcode'} . ' ' . $form->{'city'},
    'countrycode' => $customer_countrycode,
  );

  my %ref_nr_data;
  if ($::instance_conf->get_create_qrbill_invoices == 1) {
    %ref_nr_data = (
      'type' => 'QRR',
      'ref_number' => $form->{'qr_reference'},
    );
    # get ref. number/iban formatted with spaces and set into form for template
    # processing
    $form->{'ref_number'} = $form->{'qr_reference'};
    $form->{'ref_number_formatted'} = get_ref_number_formatted($form->{'qr_reference'});
  } elsif ($::instance_conf->get_create_qrbill_invoices == 2) {
    %ref_nr_data = (
      'type' => 'NON',
      'ref_number' => '',
    );
  } else {
    $::form->error($::locale->text('Error getting QR-Bill type.'));
  }

  # set into form for template processing
  $form->{'biller_information'} = \%biller_information;
  $form->{'biller_data'} = \%biller_data;
  $form->{'iban_formatted'} = get_iban_formatted($qr_account->{'iban'});
  $form->{'amount_formatted'} = $amount_formatted;
  
  # set outfile
  my $outfile = $form->{"tmpdir"} . '/' . 'qr-code.png';

  # generate QR-Code Image
  eval {
   my $qr_image = SL::Helper::QrBill->new(
     \%biller_information,
     \%biller_data,
     \%payment_information,
     \%invoice_recipient_data,
     \%ref_nr_data,
   );
   $qr_image->generate($outfile);
  } or do {
   local $_ = $@; chomp; my $error = $_;
   $::form->error($::locale->text('QR-Image generation failed: ' . $error));
  };

  $main::lxdebug->leave_sub();
  return $outfile;
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

  if (system("xauth add \"${display}\" . \"${mcookie}\"") == -1) {
    die "system call to xauth failed: $!";
  }
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
    if (system($::lx_office_conf{applications}->{openofficeorg_writer},
               "-minimized", "-norestore", "-nologo", "-nolockcheck", "-headless",
               "file:${filename}.odt",
               "macro://" . (split('/', $filename))[-1] . "/Standard.Conversion.ConvertSelfToPDF()") == -1) {
      die "system call to $::lx_office_conf{applications}->{openofficeorg_writer} failed: $!";
    }
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
  my ($self, $content, $variable) = @_;

  my $formatter =
       $formatters{ $self->{variable_content_types}->{$variable} }
    // $formatters{ $self->{default_content_type} }
    // $formatters{ text };

  return $formatter->($self, $content, variable => $variable);
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
