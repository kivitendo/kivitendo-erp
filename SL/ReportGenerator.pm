package SL::ReportGenerator;

use IO::Wrap;
use List::Util qw(max);
use Text::CSV_XS;
use Text::Iconv;

use SL::Form;

# Cause locales.pl to parse these files:
# parse_html_template('report_generator/html_report')
# parse_html_template('report_generator/pdf_report')

sub new {
  my $type = shift;

  my $self = { };

  $self->{myconfig} = shift;
  $self->{form}     = shift;

  $self->{data}     = [];
  $self->{options}  = {
    'std_column_visibility' => 0,
    'output_format'         => 'HTML',
    'allow_pdf_export'      => 1,
    'allow_csv_export'      => 1,
    'html_template'         => 'report_generator/html_report',
    'pdf_template'          => 'report_generator/pdf_report',
    'pdf_export'            => {
      'paper_size'          => 'a4',
      'orientation'         => 'landscape',
      'font_name'           => 'Verdana',
      'font_size'           => '7',
      'margin_top'          => 1.5,
      'margin_left'         => 1.5,
      'margin_bottom'       => 1.5,
      'margin_right'        => 1.5,
      'number'              => 1,
      'print'               => 0,
      'printer_id'          => 0,
      'copies'              => 1,
    },
    'csv_export'            => {
      'quote_char'          => '"',
      'sep_char'            => ';',
      'escape_char'         => '"',
      'eol_style'           => 'Unix',
      'headers'             => 1,
    },
  };
  $self->{export}   = {
    'nextsub'       => '',
    'variable_list' => [],
  };

  $self->{data_present} = 0;

  bless $self, $type;

  $self->set_options(@_) if (@_);

  $self->_init_escaped_strings_map();

  return $self;
}

sub _init_escaped_strings_map {
  my $self = shift;

  $self->{escaped_strings_map} = {
    '&auml;'  => 'ä',
    '&ouml;'  => 'ö',
    '&uuml;'  => 'ü',
    '&Auml;'  => 'Ä',
    '&Ouml;'  => 'Ö',
    '&Uuml;'  => 'Ü',
    '&szlig;' => 'ß',
    '&gt;'    => '>',
     '&lt;'    => '<',
    '&quot;'  => '"',
  };

  my $iconv = $main::locale->{iconv_iso8859};

  if ($iconv) {
    map { $self->{escaped_strings_map}->{$_} = $iconv->convert($self->{escaped_strings_map}->{$_}) } keys %{ $self->{escaped_strings_map} };
  }
}

sub set_columns {
  my $self    = shift;
  my %columns = @_;

  $self->{columns} = \%columns;

  foreach my $column (values %{ $self->{columns} }) {
    $column->{visible} = $self->{options}->{std_column_visibility} unless defined $column->{visible};
  }

  $self->set_column_order(sort keys %{ $self->{columns} });
}

sub set_column_order {
  my $self    = shift;

  my $order   = 0;
  my %columns = map { $order++; ($_, $order) } @_;

  foreach my $column (sort keys %{ $self->{columns} }) {
    next if $columns{$column};

    $order++;
    $columns{$column} = $order;
  }

  $self->{column_order} = [ sort { $columns{$a} <=> $columns{$b} } keys %columns ];
}

sub set_sort_indicator {
  my $self = shift;

  $self->{options}->{sort_indicator_column}    = shift;
  $self->{options}->{sort_indicator_direction} = shift;
}

sub add_data {
  my $self = shift;

  my $last_row_set;

  while (my $arg = shift) {
    my $row_set;

    if ('ARRAY' eq ref $arg) {
      $row_set = $arg;

    } elsif ('HASH' eq ref $arg) {
      $row_set = [ $arg ];

    } else {
      $self->{form}->error('Incorrect usage -- expecting hash or array ref');
    }

    my @columns_with_default_alignment = grep { defined $self->{columns}->{$_}->{align} } keys %{ $self->{columns} };

    foreach my $row (@{ $row_set }) {
      foreach my $column (@columns_with_default_alignment) {
        $row->{$column}          ||= { };
        $row->{$column}->{align}   = $self->{columns}->{$column}->{align} unless (defined $row->{$column}->{align});
      }

      foreach my $field (qw(data link)) {
        map { $row->{$_}->{$field} = [ $row->{$_}->{$field} ] if (ref $row->{$_}->{$field} ne 'ARRAY') } keys %{ $row };
      }
    }

    push @{ $self->{data} }, $row_set;
    $last_row_set = $row_set;

    $self->{data_present} = 1;
  }

  return $last_row_set;
}

sub add_separator {
  my $self = shift;

  push @{ $self->{data} }, { 'type' => 'separator' };
}

sub add_control {
  my $self = shift;
  my $data = shift;

  push @{ $self->{data} }, $data;
}

sub clear_data {
  my $self = shift;

  $self->{data}         = [];
  $self->{data_present} = 0;
}

sub set_options {
  my $self    = shift;
  my %options = @_;

  while (my ($key, $value) = each %options) {
    if ($key eq 'pdf_export') {
      map { $self->{options}->{pdf_export}->{$_} = $value->{$_} } keys %{ $value };
    } else {
      $self->{options}->{$key} = $value;
    }
  }
}

sub set_options_from_form {
  my $self     = shift;

  my $form     = $self->{form};
  my $myconfig = $self->{myconfig};

  foreach my $key (qw(output_format)) {
    my $full_key = "report_generator_${key}";
    $self->{options}->{$key} = $form->{$full_key} if (defined $form->{$full_key});
  }

  foreach my $format (qw(pdf csv)) {
    my $opts = $self->{options}->{"${format}_export"};
    foreach my $key (keys %{ $opts }) {
      my $full_key = "report_generator_${format}_options_${key}";
      $opts->{$key} = $key =~ /^margin/ ? $form->parse_amount($myconfig, $form->{$full_key}) : $form->{$full_key};
    }
  }
}

sub set_export_options {
  my $self        = shift;

  $self->{export} = {
    'nextsub'       => shift,
    'variable_list' => [ @_ ],
  };
}

sub get_attachment_basename {
  my $self     = shift;
  my $filename =  $self->{options}->{attachment_basename} || 'report';
  $filename    =~ s|.*\\||;
  $filename    =~ s|.*/||;

  return $filename;
}

sub generate_with_headers {
  my $self   = shift;
  my $format = lc $self->{options}->{output_format};
  my $form   = $self->{form};

  if (!$self->{columns}) {
    $form->error('Incorrect usage -- no columns specified');
  }

  if ($format eq 'html') {
    my $title      = $form->{title};
    $form->{title} = $self->{title} if ($self->{title});
    $form->header();
    $form->{title} = $title;

    print $self->generate_html_content();

  } elsif ($format eq 'csv') {
    my $filename = $self->get_attachment_basename();
    print qq|content-type: text/csv\n|;
    print qq|content-disposition: attachment; filename=${filename}.csv\n\n|;
    $self->generate_csv_content();

  } elsif ($format eq 'pdf') {
    $self->generate_pdf_content();

  } else {
    $form->error('Incorrect usage -- unknown format (supported are HTML, CSV, PDF)');
  }
}

sub get_visible_columns {
  my $self   = shift;
  my $format = shift;

  return grep { my $c = $self->{columns}->{$_}; $c && $c->{visible} && (($c->{visible} == 1) || ($c->{visible} =~ /\Q${format}\E/i)) } @{ $self->{column_order} };
}

sub html_format {
  my $self  = shift;
  my $value = shift;

  $value =  $self->{form}->quote_html($value);
  $value =~ s/\r//g;
  $value =~ s/\n/<br>/g;

  return $value;
}

sub prepare_html_content {
  my $self = shift;

  my ($column, $name, @column_headers);

  my $opts            = $self->{options};
  my @visible_columns = $self->get_visible_columns('HTML');

  foreach $name (@visible_columns) {
    $column = $self->{columns}->{$name};

    my $header = {
      'name'                     => $name,
      'link'                     => $column->{link},
      'text'                     => $column->{text},
      'show_sort_indicator'      => $name eq $opts->{sort_indicator_column},
      'sort_indicator_direction' => $opts->{sort_indicator_direction},
    };

    push @column_headers, $header;
  }

  my ($outer_idx, $inner_idx) = (0, 0);
  my $next_border_top;
  my @rows;

  foreach my $row_set (@{ $self->{data} }) {
    if ('HASH' eq ref $row_set) {
      if ($row_set->{type} eq 'separator') {
        if (! scalar @rows) {
          $next_border_top = 1;
        } else {
          $rows[-1]->{BORDER_BOTTOM} = 1;
        }

        next;
      }

      my $row_data = {
        'IS_CONTROL'      => 1,
        'IS_COLSPAN_DATA' => $row_set->{type} eq 'colspan_data',
        'NUM_COLUMNS'     => scalar @visible_columns,
        'BORDER_TOP'      => $next_border_top,
        'data'            => $row_set->{data},
      };

      push @rows, $row_data;

      $next_border_top = 0;

      next;
    }

    $outer_idx++;

    foreach my $row (@{ $row_set }) {
      $inner_idx++;

      foreach my $col_name (@visible_columns) {
        my $col = $row->{$col_name};
        $col->{CELL_ROWS} = [ ];
        foreach my $i (0 .. scalar(@{ $col->{data} }) - 1) {
          push @{ $col->{CELL_ROWS} }, {
            'data' => $self->html_format($col->{data}->[$i]),
            'link' => $col->{link}->[$i],
          };
        }

        # Force at least a &nbsp; to be displayed so that browsers
        # will format the table cell (e.g. borders etc).
        if (!scalar @{ $col->{CELL_ROWS} }) {
          push @{ $col->{CELL_ROWS} }, { 'data' => '&nbsp;' };
        } elsif ((1 == scalar @{ $col->{CELL_ROWS} }) && (!defined $col->{CELL_ROWS}->[0]->{data} || ($col->{CELL_ROWS}->[0]->{data} eq ''))) {
          $col->{CELL_ROWS}->[0]->{data} = '&nbsp;';
        }
      }

      my $row_data = {
        'COLUMNS'       => [ map { $row->{$_} } @visible_columns ],
        'outer_idx'     => $outer_idx,
        'outer_idx_odd' => $outer_idx % 2,
        'inner_idx'     => $inner_idx,
        'BORDER_TOP'    => $next_border_top,
      };

      push @rows, $row_data;

      $next_border_top = 0;
    }
  }

  my @export_variables = $self->{form}->flatten_variables(@{ $self->{export}->{variable_list} });

  my $allow_pdf_export = $opts->{allow_pdf_export} && (-x $main::html2ps_bin) && (-x $main::ghostscript_bin);

  eval { require PDF::API2; require PDF::Table; };
  $allow_pdf_export |= 1 if (! $@);

  my $variables = {
    'TITLE'                => $opts->{title},
    'TOP_INFO_TEXT'        => $self->html_format($opts->{top_info_text}),
    'RAW_TOP_INFO_TEXT'    => $opts->{raw_top_info_text},
    'BOTTOM_INFO_TEXT'     => $self->html_format($opts->{bottom_info_text}),
    'RAW_BOTTOM_INFO_TEXT' => $opts->{raw_bottom_info_text},
    'ALLOW_PDF_EXPORT'     => $allow_pdf_export,
    'ALLOW_CSV_EXPORT'     => $opts->{allow_csv_export},
    'SHOW_EXPORT_BUTTONS'  => ($allow_pdf_export || $opts->{allow_csv_export}) && $self->{data_present},
    'COLUMN_HEADERS'       => \@column_headers,
    'NUM_COLUMNS'          => scalar @column_headers,
    'ROWS'                 => \@rows,
    'EXPORT_VARIABLES'     => \@export_variables,
    'EXPORT_VARIABLE_LIST' => join(' ', @{ $self->{export}->{variable_list} }),
    'EXPORT_NEXTSUB'       => $self->{export}->{nextsub},
    'DATA_PRESENT'         => $self->{data_present},
  };

  return $variables;
}

sub generate_html_content {
  my $self      = shift;
  my $variables = $self->prepare_html_content();

  return $self->{form}->parse_html_template($self->{options}->{html_template}, $variables);
}

sub _cm2bp {
  # 1 bp = 1/72 in
  # 1 in = 2.54 cm
  return $_[0] * 72 / 2.54;
}

sub render_pdf_with_pdf_api2 {
  my $self       = shift;
  my $variables  = $self->prepare_html_content();
  my $form       = $self->{form};
  my $myconfig   = $self->{myconfig};

  my $opts       = $self->{options};
  my $params     = $opts->{pdf_export};

  my (@data, @column_props, @cell_props);

  my $data_row        = [];
  my $cell_props_row  = [];
  my @visible_columns = $self->get_visible_columns('HTML');

  foreach $name (@visible_columns) {
    $column = $self->{columns}->{$name};

    push @{ $data_row },       $column->{text};
    push @{ $cell_props_row }, {};
    push @column_props,        { 'justify' => $column->{align} eq 'right' ? 'right' : 'left' };
  }

  push @data,       $data_row;
  push @cell_props, $cell_props_row;

  my $num_columns = scalar @column_props;

  foreach my $row_set (@{ $self->{data} }) {
    if ('HASH' eq ref $row_set) {
      if ($row_set->{type} eq 'colspan_data') {
        push @data, [ $row_set->{data} ];

        $cell_props_row = [];
        push @cell_props, $cell_props_row;

        foreach (0 .. $num_columns - 1) {
          push @{ $cell_props_row }, { 'background_color' => '#000000',
                                       'font_color'       => '#ffffff', };
        }
      }
      next;
    }

    foreach my $row (@{ $row_set }) {
      $data_row = [];
      push @data, $data_row;

      my $col_idx = 0;
      foreach my $col_name (@visible_columns) {
        my $col = $row->{$col_name};
        push @{ $data_row }, join("\n", @{ $col->{data} });

        $column_props[$col_idx]->{justify} = 'right' if ($col->{align} eq 'right');

        $col_idx++;
      }

      $cell_props_row = [];
      push @cell_props, $cell_props_row;

      foreach (0 .. $num_columns - 1) {
        push @{ $cell_props_row }, { };
      }
    }
  }

  foreach my $i (0 .. scalar(@data) - 1) {
    my $aref             = $data[$i];
    my $num_columns_here = scalar @{ $aref };

    if ($num_columns_here < $num_columns) {
      push @{ $aref }, ('') x ($num_columns - $num_columns_here);
    } elsif ($num_columns_here > $num_columns) {
      splice @{ $aref }, $num_columns;
    }
  }

  my $papersizes = {
    'a3'         => [ 842, 1190 ],
    'a4'         => [ 595,  842 ],
    'a5'         => [ 420,  595 ],
    'letter'     => [ 612,  792 ],
    'legal'      => [ 612, 1008 ],
  };

  my %supported_fonts = map { $_ => 1 } qw(courier georgia helvetica times verdana);

  my $paper_size  = defined $params->{paper_size} && defined $papersizes->{lc $params->{paper_size}} ? lc $params->{paper_size} : 'a4';
  my ($paper_width, $paper_height);

  if (lc $params->{orientation} eq 'landscape') {
    ($paper_width, $paper_height) = @{$papersizes->{$paper_size}}[1, 0];
  } else {
    ($paper_width, $paper_height) = @{$papersizes->{$paper_size}}[0, 1];
  }

  my $margin_top        = _cm2bp($params->{margin_top}    || 1.5);
  my $margin_bottom     = _cm2bp($params->{margin_bottom} || 1.5);
  my $margin_left       = _cm2bp($params->{margin_left}   || 1.5);
  my $margin_right      = _cm2bp($params->{margin_right}  || 1.5);

  my $table             = PDF::Table->new();
  my $pdf               = PDF::API2->new();
  my $page              = $pdf->page();

  $pdf->mediabox($paper_width, $paper_height);

  my $font              = $pdf->corefont(defined $params->{font_name} && $supported_fonts{lc $params->{font_name}} ? ucfirst $params->{font_name} : 'Verdana',
                                         '-encoding' => $main::dbcharset || 'ISO-8859-15');
  my $font_size         = $params->{font_size} || 7;
  my $title_font_size   = $font_size + 1;
  my $padding           = 1;
  my $font_height       = $font_size + 2 * $padding;
  my $title_font_height = $font_size + 2 * $padding;

  my $header_height     = 2 * $title_font_height if ($opts->{title});
  my $footer_height     = 2 * $font_height       if ($params->{number});

  my $top_text_height   = 0;

  if ($self->{options}->{top_info_text}) {
    my $top_text     =  $self->{options}->{top_info_text};
    $top_text        =~ s/\r//g;
    $top_text        =~ s/\n+$//;

    my @lines        =  split m/\n/, $top_text;
    $top_text_height =  $font_height * scalar @lines;

    foreach my $line_no (0 .. scalar(@lines) - 1) {
      my $y_pos    = $paper_height - $margin_top - $header_height - $line_no * $font_height;
      my $text_obj = $page->text();

      $text_obj->font($font, $font_size);
      $text_obj->translate($margin_left, $y_pos);
      $text_obj->text($lines[$line_no]);
    }
  }

  $table->table($pdf,
                $page,
                \@data,
                'x'                     => $margin_left,
                'w'                     => $paper_width - $margin_left - $margin_right,
                'start_y'               => $paper_height - $margin_top                  - $header_height                  - $top_text_height,
                'next_y'                => $paper_height - $margin_top                  - $header_height,
                'start_h'               => $paper_height - $margin_top - $margin_bottom - $header_height - $footer_height - $top_text_height,
                'next_h'                => $paper_height - $margin_top - $margin_bottom - $header_height - $footer_height,
                'padding'               => 1,
                'background_color_odd'  => '#ffffff',
                'background_color_even' => '#eeeeee',
                'font'                  => $font,
                'font_size'             => $font_size,
                'font_color'            => '#000000',
                'header_props'          => {
                  'bg_color'            => '#ffffff',
                  'repeat'              => 1,
                  'font_color'          => '#000000',
                },
                'column_props'          => \@column_props,
                'cell_props'            => \@cell_props,
    );

  foreach my $page_num (1..$pdf->pages()) {
    my $curpage  = $pdf->openpage($page_num);

    if ($params->{number}) {
      my $label    = $main::locale->text("Page #1/#2", $page_num, $pdf->pages());
      my $text_obj = $curpage->text();

      $text_obj->font($font, $font_size);
      $text_obj->translate(($paper_width - $margin_left - $margin_right) / 2 + $margin_left - $text_obj->advancewidth($label) / 2, $margin_bottom);
      $text_obj->text($label);
    }

    if ($opts->{title}) {
      my $text_obj = $curpage->text();

      $text_obj->font($font, $title_font_size);
      $text_obj->translate(($paper_width - $margin_left - $margin_right) / 2 + $margin_left - $text_obj->advancewidth($opts->{title}) / 2,
                           $paper_height - $margin_top);
      $text_obj->text($opts->{title}, '-underline' => 1);
    }
  }

  my $content = $pdf->stringify();

  my $printer_command;
  if ($params->{print} && $params->{printer_id}) {
    $form->{printer_id} = $params->{printer_id};
    $form->get_printer_code($myconfig);
    $printer_command = $form->{printer_command};
  }

  if ($printer_command) {
    $self->_print_content('printer_command' => $printer_command,
                          'content'         => $content,
                          'copies'          => $params->{copies});
    $form->{report_generator_printed} = 1;

  } else {
    my $filename = $self->get_attachment_basename();

    print qq|content-type: application/pdf\n|;
    print qq|content-disposition: attachment; filename=${filename}.pdf\n\n|;

    print $content;
  }
}

sub verify_paper_size {
  my $self                 = shift;
  my $requested_paper_size = lc shift;
  my $default_paper_size   = shift;

  my %allowed_paper_sizes  = map { $_ => 1 } qw(a3 a4 letter legal);

  return $allowed_paper_sizes{$requested_paper_size} ? $requested_paper_size : $default_paper_size;
}

sub render_pdf_with_html2ps {
  my $self      = shift;
  my $variables = $self->prepare_html_content();
  my $form      = $self->{form};
  my $myconfig  = $self->{myconfig};
  my $opt       = $self->{options}->{pdf_export};

  my $opt_number     = $opt->{number}                     ? 'number : 1'    : '';
  my $opt_landscape  = $opt->{orientation} eq 'landscape' ? 'landscape : 1' : '';

  my $opt_paper_size = $self->verify_paper_size($opt->{paper_size}, 'a4');

  my $html2ps_config = <<"END"
\@html2ps {
  option {
    titlepage: 0;
    hyphenate: 0;
    colour: 1;
    ${opt_landscape};
    ${opt_number};
  }
  paper {
    type: ${opt_paper_size};
  }
  break-table: 1;
}

\@page {
  margin-top:    $opt->{margin_top}cm;
  margin-left:   $opt->{margin_left}cm;
  margin-bottom: $opt->{margin_bottom}cm;
  margin-right:  $opt->{margin_right}cm;
}

BODY {
  font-family: Helvetica;
  font-size:   $opt->{font_size}pt;
}

END
  ;

  my $printer_command;
  if ($opt->{print} && $opt->{printer_id}) {
    $form->{printer_id} = $opt->{printer_id};
    $form->get_printer_code($myconfig);
    $printer_command = $form->{printer_command};
  }

  my $cfg_file_name = Common::tmpname() . '-html2ps-config';
  my $cfg_file      = IO::File->new($cfg_file_name, 'w') || $form->error($locale->text('Could not write the html2ps config file.'));

  $cfg_file->print($html2ps_config);
  $cfg_file->close();

  my $html_file_name = Common::tmpname() . '.html';
  my $html_file      = IO::File->new($html_file_name, 'w');

  if (!$html_file) {
    unlink $cfg_file_name;
    $form->error($locale->text('Could not write the temporary HTML file.'));
  }

  $html_file->print($form->parse_html_template($self->{options}->{pdf_template}, $variables));
  $html_file->close();

  my $cmdline =
    "\"${main::html2ps_bin}\" -f \"${cfg_file_name}\" \"${html_file_name}\" | " .
    "\"${main::ghostscript_bin}\" -q -dSAFER -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sPAPERSIZE=${opt_paper_size} -sOutputFile=- -c .setpdfwrite -";

  my $gs = IO::File->new("${cmdline} |");
  if ($gs) {
    my $content;

    if (!$printer_command) {
      my $filename = $self->get_attachment_basename();
      print qq|content-type: application/pdf\n|;
      print qq|content-disposition: attachment; filename=${filename}.pdf\n\n|;

      while (my $line = <$gs>) {
        print $line;
      }

    } else {
      while (my $line = <$gs>) {
        $content .= $line;
      }
    }

    $gs->close();
    unlink $cfg_file_name, $html_file_name;

    if ($printer_command && $content) {
      $self->_print_content('printer_command' => $printer_command,
                            'content'         => $content,
                            'copies'          => $opt->{copies});
      $form->{report_generator_printed} = 1;
    }

  } else {
    unlink $cfg_file_name, $html_file_name;
    $form->error($locale->text('Could not spawn html2ps or GhostScript.'));
  }
}

sub _print_content {
  my $self   = shift;
  my %params = @_;

  foreach my $i (1 .. max $params{copies}, 1) {
    my $printer = IO::File->new("| $params{printer_command}");
    $main::form->error($main::locale->text('Could not spawn the printer command.')) if (!$printer);
    $printer->print($params{content});
    $printer->close();
  }
}

sub generate_pdf_content {
  my $self = shift;

  eval { require PDF::API2; require PDF::Table; };

  if ($@) {
    return $self->render_pdf_with_html2ps(@_);
  } else {
    return $self->render_pdf_with_pdf_api2(@_);
  }
}

sub unescape_string {
  my $self = shift;
  my $text = shift;

  foreach my $key (keys %{ $self->{escaped_strings_map} }) {
    $text =~ s/\Q$key\E/$self->{escaped_strings_map}->{$key}/g;
  }

  $text =~ s/\Q&amp;\E/&/g;

  return $text;
}

sub generate_csv_content {
  my $self = shift;

  my %valid_sep_chars    = (';' => ';', ',' => ',', ':' => ':', 'TAB' => "\t");
  my %valid_escape_chars = ('"' => 1, "'" => 1);
  my %valid_quote_chars  = ('"' => 1, "'" => 1);

  my $opts        = $self->{options}->{csv_export};
  my $eol         = $opts->{eol_style} eq 'DOS'               ? "\r\n"                              : "\n";
  my $sep_char    = $valid_sep_chars{$opts->{sep_char}}       ? $valid_sep_chars{$opts->{sep_char}} : ';';
  my $escape_char = $valid_escape_chars{$opts->{escape_char}} ? $opts->{escape_char}                : '"';
  my $quote_char  = $valid_quote_chars{$opts->{quote_char}}   ? $opts->{quote_char}                 : '"';

  $escape_char    = $quote_char if ($opts->{escape_char} eq 'QUOTE_CHAR');

  my $csv = Text::CSV_XS->new({ 'binary'      => 1,
                                'sep_char'    => $sep_char,
                                'escape_char' => $escape_char,
                                'quote_char'  => $quote_char,
                                'eol'         => $eol, });

  my $stdout          = wraphandle(\*STDOUT);
  my @visible_columns = $self->get_visible_columns('CSV');

  if ($opts->{headers}) {
    $csv->print($stdout, [ map { $self->unescape_string($self->{columns}->{$_}->{text}) } @visible_columns ]);
  }

  foreach my $row_set (@{ $self->{data} }) {
    next if ('ARRAY' ne ref $row_set);
    foreach my $row (@{ $row_set }) {
      my @data;
      foreach my $col (@visible_columns) {
        push @data, join($eol, map { s/\r?\n/$eol/g; $_ } @{ $row->{$col}->{data} });
      }
      $csv->print($stdout, \@data);
    }
  }
}

1;
