package SL::ReportGenerator;

use Data::Dumper;
use List::Util qw(max);
use Scalar::Util qw(blessed);
use Text::CSV_XS;
#use PDF::API2;    # these two eat up to .75s on startup. only load them if we actually need them
#use PDF::Table;

use strict;
use SL::Helper::GlAttachments qw(append_gl_pdf_attachments);
use SL::Helper::CreatePDF     qw(merge_pdfs);

# Cause locales.pl to parse these files:
# parse_html_template('report_generator/html_report')

sub new {
  my $type = shift;

  my $self = { };

  $self->{myconfig} = shift;
  $self->{form}     = shift;

  $self->{data}     = [];
  $self->{options}  = {
    'std_column_visibility' => 0,
    'output_format'         => 'HTML',
    'controller_class   '   => '',
    'allow_pdf_export'      => 1,
    'allow_csv_export'      => 1,
    'html_template'         => 'report_generator/html_report',
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
      'encoding'            => 'UTF-8',
    },
  };
  $self->{export}   = {
    'nextsub'       => '',
    'variable_list' => [],
  };

  $self->{data_present} = 0;

  bless $self, $type;

  $self->set_options(@_) if (@_);

  return $self;
}

sub set_columns {
  my $self    = shift;
  my %columns = @_;

  $self->{columns} = \%columns;

  foreach my $column (values %{ $self->{columns} }) {
    $column->{visible} = $self->{options}->{std_column_visibility} unless defined $column->{visible};
  }

  if( $::form->{report_generator_csv_options_for_import} ) {
    foreach my $key (keys %{ $self->{columns} }) {
      $self->{columns}{$key}{text} = $key;
    }
  }

  $self->set_column_order(sort keys %{ $self->{columns} });
}

sub set_column_order {
  my $self    = shift;
  my %seen;
  $self->{column_order} = [ grep { !$seen{$_}++ } @_, sort keys %{ $self->{columns} } ];
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

      foreach my $field (qw(data link link_class)) {
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
      $self->{options}->{pdf_export}->{$_} = $value->{$_} for keys %{ $value };
    } elsif ($key eq 'csv_export') {
      $self->{options}->{csv_export}->{$_} = $value->{$_} for keys %{ $value };
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

sub set_custom_headers {
  my $self = shift;

  if (@_) {
    $self->{custom_headers} = [ @_ ];
  } else {
    delete $self->{custom_headers};
  }
}

sub get_attachment_basename {
  my $self     = shift;
  my $filename =  $self->{options}->{attachment_basename} || 'report';

  # FIXME: this is bonkers. add a real sluggify method somewhere or import one.
  $filename    =~ s|.*\\||;
  $filename    =~ s|.*/||;
  $filename    =~ s| |_|g;

  return $filename;
}

sub generate_with_headers {
  my ($self, %params) = @_;
  my $format = lc $self->{options}->{output_format};
  my $form   = $self->{form};

  if (!$self->{columns}) {
    $form->error('Incorrect usage -- no columns specified');
  }

  if ($format eq 'html') {
    my $content    = $self->generate_html_content(%params);
    my $title      = $form->{title};
    $form->{title} = $self->{title} if ($self->{title});
    $form->header(no_layout => $params{no_layout});
    $form->{title} = $title;

    print $content;

  } elsif ($format eq 'csv') {
    # FIXME: don't do mini http in here
    my $filename = $self->get_attachment_basename();
    print qq|content-type: text/csv\n|;
    print qq|content-disposition: attachment; filename=${filename}.csv\n\n|;
    $::locale->with_raw_io(\*STDOUT, sub {
      $self->generate_csv_content();
    });

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

  $value =  $main::locale->quote_special_chars('HTML', $value);
  $value =~ s/\r//g;
  $value =~ s/\n/<br>/g;

  return $value;
}

sub prepare_html_content {
  my ($self, %params) = @_;

  my ($column, $name, @column_headers);

  my $opts            = $self->{options};
  my @visible_columns = $self->get_visible_columns('HTML');

  foreach $name (@visible_columns) {
    $column = $self->{columns}->{$name};

    my $header = {
      'name'                     => $name,
      'align'                    => $column->{align},
      'link'                     => $column->{link},
      'text'                     => $column->{text},
      'raw_header_data'          => $column->{raw_header_data},
      'show_sort_indicator'      => $name eq $opts->{sort_indicator_column},
      'sort_indicator_direction' => $opts->{sort_indicator_direction},
    };

    push @column_headers, $header;
  }

  my $header_rows;
  if ($self->{custom_headers}) {
    $header_rows = $self->{custom_headers};
  } else {
    $header_rows = [ \@column_headers ];
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

      my $output_columns = [ ];
      my $skip_next      = 0;
      foreach my $col_name (@visible_columns) {
        if ($skip_next) {
          $skip_next--;
          next;
        }

        my $col = $row->{$col_name} || { data => [] };
        $col->{CELL_ROWS} = [ ];
        foreach my $i (0 .. scalar(@{ $col->{data} }) - 1) {
          push @{ $col->{CELL_ROWS} }, {
            'data' => '' . $self->html_format($col->{data}->[$i]),
            'link' => $col->{link}->[$i],
            link_class => $col->{link_class}->[$i],
          };
        }

        # Force at least a &nbsp; to be displayed so that browsers
        # will format the table cell (e.g. borders etc).
        if (!scalar @{ $col->{CELL_ROWS} }) {
          push @{ $col->{CELL_ROWS} }, { 'data' => '&nbsp;' };
        } elsif ((1 == scalar @{ $col->{CELL_ROWS} }) && (!defined $col->{CELL_ROWS}->[0]->{data} || ($col->{CELL_ROWS}->[0]->{data} eq ''))) {
          $col->{CELL_ROWS}->[0]->{data} = '&nbsp;';
        }

        push @{ $output_columns }, $col;
        $skip_next = $col->{colspan} ? $col->{colspan} - 1 : 0;
      }

      my $row_data = {
        'COLUMNS'       => $output_columns,
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

  my $allow_pdf_export = $opts->{allow_pdf_export};

  my $variables = {
    'TITLE'                => $opts->{title},
    'TOP_INFO_TEXT'        => $self->html_format($opts->{top_info_text}),
    'RAW_TOP_INFO_TEXT'    => $opts->{raw_top_info_text},
    'BOTTOM_INFO_TEXT'     => $self->html_format($opts->{bottom_info_text}),
    'RAW_BOTTOM_INFO_TEXT' => $opts->{raw_bottom_info_text},
    'ALLOW_PDF_EXPORT'     => $allow_pdf_export,
    'ALLOW_CSV_EXPORT'     => $opts->{allow_csv_export},
    'SHOW_EXPORT_BUTTONS'  => ($allow_pdf_export || $opts->{allow_csv_export}) && $self->{data_present},
    'HEADER_ROWS'          => $header_rows,
    'NUM_COLUMNS'          => scalar @column_headers,
    'ROWS'                 => \@rows,
    'EXPORT_VARIABLES'     => \@export_variables,
    'EXPORT_VARIABLE_LIST' => join(' ', @{ $self->{export}->{variable_list} }),
    'EXPORT_NEXTSUB'       => $self->{export}->{nextsub},
    'DATA_PRESENT'         => $self->{data_present},
    'CONTROLLER_DISPATCH'  => $opts->{controller_class},
    'TABLE_CLASS'          => $opts->{table_class},
    'SKIP_BUTTONS'         => !!$params{action_bar},
  };

  return $variables;
}

sub create_action_bar_actions {
  my ($self, $variables) = @_;

  my @actions;
  foreach my $type (qw(pdf csv)) {
    next unless $variables->{"ALLOW_" . uc($type) . "_EXPORT"};

    my $key   = $variables->{CONTROLLER_DISPATCH} ? 'action' : 'report_generator_dispatch_to';
    my $value = "report_generator_export_as_${type}";
    $value    = $variables->{CONTROLLER_DISPATCH} . "/${value}" if $variables->{CONTROLLER_DISPATCH};

    push @actions, action => [
      $type eq 'pdf' ? $::locale->text('PDF export') : $::locale->text('CSV export'),
      submit => [ '#report_generator_form', { $key => $value } ],
    ];
  }

  if (scalar(@actions) > 1) {
    @actions = (
      combobox => [
        action => [ $::locale->text('Export') ],
        @actions,
      ],
    );
  }

  return @actions;
}

sub setup_action_bar {
  my ($self, $variables, %params) = @_;

  my @actions = $self->create_action_bar_actions($variables);

  if ($params{action_bar_setup_hook}) {
    $params{action_bar_setup_hook}->(@actions);

  } elsif (@actions) {
    my $action_bar = blessed($params{action_bar}) ? $params{action_bar} : ($::request->layout->get('actionbar'))[0];
    $action_bar->add(@actions);
  }
}

sub generate_html_content {
  my ($self, %params) = @_;

  $params{action_bar} //= 1;

  my $variables = $self->prepare_html_content(%params);

  $self->setup_action_bar($variables, %params) if $params{action_bar};

  my $stuff  = $self->{form}->parse_html_template($self->{options}->{html_template}, $variables);
  return $stuff;
}

sub _cm2bp {
  # 1 bp = 1/72 in
  # 1 in = 2.54 cm
  return $_[0] * 72 / 2.54;
}

sub generate_pdf_content {
  eval {
    require PDF::API2;
    require PDF::Table;
  };

  my $self       = shift;
  my $variables  = $self->prepare_html_content();
  my $form       = $self->{form};
  my $myconfig   = $self->{myconfig};

  my $opts       = $self->{options};
  my $pdfopts    = $opts->{pdf_export};

  my (@data, @column_props, @cell_props);

  my ($data_row, $cell_props_row);
  my @visible_columns = $self->get_visible_columns('PDF');
  my $num_columns     = scalar @visible_columns;
  my $num_header_rows = 1;

  my $font_encoding   = 'UTF-8';

  foreach my $name (@visible_columns) {
    push @column_props, { 'justify' => $self->{columns}->{$name}->{align} eq 'right' ? 'right' : 'left' };
  }

  if (!$self->{custom_headers}) {
    $data_row       = [];
    $cell_props_row = [];
    push @data,       $data_row;
    push @cell_props, $cell_props_row;

    foreach my $name (@visible_columns) {
      my $column = $self->{columns}->{$name};

      push @{ $data_row },       $column->{text};
      push @{ $cell_props_row }, {};
    }

  } else {
    $num_header_rows = scalar @{ $self->{custom_headers} };

    foreach my $custom_header_row (@{ $self->{custom_headers} }) {
      $data_row       = [];
      $cell_props_row = [];
      push @data,       $data_row;
      push @cell_props, $cell_props_row;

      foreach my $custom_header_col (@{ $custom_header_row }) {
        push @{ $data_row }, $custom_header_col->{text};

        my $num_output  = ($custom_header_col->{colspan} * 1 > 1) ? $custom_header_col->{colspan} : 1;
        if ($num_output > 1) {
          push @{ $data_row },       ('') x ($num_output - 1);
          push @{ $cell_props_row }, { 'colspan' => $num_output };
          push @{ $cell_props_row }, ({ }) x ($num_output - 1);

        } else {
          push @{ $cell_props_row }, {};
        }
      }
    }
  }

  foreach my $row_set (@{ $self->{data} }) {
    if ('HASH' eq ref $row_set) {
      if ($row_set->{type} eq 'colspan_data') {
        push @data, [ $row_set->{data} ];

        $cell_props_row = [];
        push @cell_props, $cell_props_row;

        foreach (0 .. $num_columns - 1) {
          push @{ $cell_props_row }, { 'background_color' => '#666666',
               #  BUG PDF:Table  -> 0.9.12:
               # font_color is used in next row, so dont set font_color
               #                       'font_color'       => '#ffffff',
                                       'colspan'          => $_ == 0 ? -1 : undef, };
        }
      }
      next;
    }

    foreach my $row (@{ $row_set }) {
      $data_row       = [];
      $cell_props_row = [];

      push @data,       $data_row;
      push @cell_props, $cell_props_row;

      my $col_idx = 0;
      foreach my $col_name (@visible_columns) {
        my $col = $row->{$col_name};
        push @{ $data_row }, join("\n", @{ $col->{data} || [] });

        $column_props[$col_idx]->{justify} = 'right' if ($col->{align} eq 'right');

        my $cell_props = { };
        push @{ $cell_props_row }, $cell_props;

        if ($col->{colspan} && $col->{colspan} > 1) {
          $cell_props->{colspan} = $col->{colspan};
        }

        $col_idx++;
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

  my $paper_size  = defined $pdfopts->{paper_size} && defined $papersizes->{lc $pdfopts->{paper_size}} ? lc $pdfopts->{paper_size} : 'a4';
  my ($paper_width, $paper_height);

  if (lc $pdfopts->{orientation} eq 'landscape') {
    ($paper_width, $paper_height) = @{$papersizes->{$paper_size}}[1, 0];
  } else {
    ($paper_width, $paper_height) = @{$papersizes->{$paper_size}}[0, 1];
  }

  my $margin_top        = _cm2bp($pdfopts->{margin_top}    || 1.5);
  my $margin_bottom     = _cm2bp($pdfopts->{margin_bottom} || 1.5);
  my $margin_left       = _cm2bp($pdfopts->{margin_left}   || 1.5);
  my $margin_right      = _cm2bp($pdfopts->{margin_right}  || 1.5);

  my $table             = PDF::Table->new();
  my $pdf               = PDF::API2->new();
  my $page              = $pdf->page();

  $pdf->mediabox($paper_width, $paper_height);

  my $font              = $pdf->corefont(defined $pdfopts->{font_name} && $supported_fonts{lc $pdfopts->{font_name}} ? ucfirst $pdfopts->{font_name} : 'Verdana',
                                         '-encoding' => $font_encoding);
  my $font_size         = $pdfopts->{font_size} || 7;
  my $title_font_size   = $font_size + 1;
  my $padding           = 1;
  my $font_height       = $font_size + 2 * $padding;
  my $title_font_height = $font_size + 2 * $padding;

  my $header_height     = $opts->{title}     ? 2 * $title_font_height : undef;
  my $footer_height     = $pdfopts->{number} ? 2 * $font_height       : undef;

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
                'num_header_rows'       => $num_header_rows,
                'header_props'          => {
                  'bg_color'            => '#ffffff',
                  'repeat'              => 1,
                  'font_color'          => '#000000',
                },
                'column_props'          => \@column_props,
                'cell_props'            => \@cell_props,
                'max_word_length'       => 60,
                'border'                => 0.5,
    );

  foreach my $page_num (1..$pdf->pages()) {
    my $curpage  = $pdf->openpage($page_num);

    if ($pdfopts->{number}) {
      my $label    = $main::locale->text("Page #1/#2", $page_num, $pdf->pages());
      my $text_obj = $curpage->text();

      $text_obj->font($font, $font_size);
      $text_obj->translate(($paper_width - $margin_left - $margin_right) / 2 + $margin_left - $text_obj->advancewidth($label) / 2, $margin_bottom);
      $text_obj->text($label);
    }

    if ($opts->{title}) {
      my $title    = $opts->{title};
      my $text_obj = $curpage->text();

      $text_obj->font($font, $title_font_size);
      $text_obj->translate(($paper_width - $margin_left - $margin_right) / 2 + $margin_left - $text_obj->advancewidth($title) / 2,
                           $paper_height - $margin_top);
      $text_obj->text($title, '-underline' => 1);
    }
  }

  my $content = $pdf->stringify();

  $main::lxdebug->message(LXDebug->DEBUG2(),"addattachments ?? =".$form->{report_generator_addattachments}." GL=".$form->{GL});
  if ($form->{report_generator_addattachments} && $form->{GL}) {
    $content = $self->append_gl_pdf_attachments($form,$content);
  }

  my $printer_command;
  if ($pdfopts->{print} && $pdfopts->{printer_id}) {
    $form->{printer_id} = $pdfopts->{printer_id};
    $form->get_printer_code($myconfig);
    $printer_command = $form->{printer_command};
  }

  if ($printer_command) {
    $self->_print_content('printer_command' => $printer_command,
                          'content'         => $content,
                          'copies'          => $pdfopts->{copies});
    $form->{report_generator_printed} = 1;

  } else {
    my $filename = $self->get_attachment_basename();

    print qq|content-type: application/pdf\n|;
    print qq|content-disposition: attachment; filename=${filename}.pdf\n\n|;

    $::locale->with_raw_io(\*STDOUT, sub {
      print $content;
    });
  }
}

sub verify_paper_size {
  my $self                 = shift;
  my $requested_paper_size = lc shift;
  my $default_paper_size   = shift;

  my %allowed_paper_sizes  = map { $_ => 1 } qw(a3 a4 a5 letter legal);

  return $allowed_paper_sizes{$requested_paper_size} ? $requested_paper_size : $default_paper_size;
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

sub _handle_quoting_and_encoding {
  my ($self, $text, $do_unquote, $encoding) = @_;

  $text = $main::locale->unquote_special_chars('HTML', $text) if $do_unquote;
  $text = Encode::encode($encoding || 'UTF-8', $text);

  return $text;
}

sub generate_csv_content {
  my $self   = shift;
  my $stdout = ($::dispatcher->get_standard_filehandles)[1];

  # Text::CSV_XS seems to downgrade to bytes already (see
  # SL/FCGIFixes.pm). Therefore don't let FCGI do that again.
  $::locale->with_raw_io($stdout, sub { $self->_generate_csv_content($stdout) });
}

sub _generate_csv_content {
  my ($self, $stdout) = @_;

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

  my @visible_columns = $self->get_visible_columns('CSV');

  if ($opts->{headers}) {
    if (!$self->{custom_headers}) {
      $csv->print($stdout, [ map { $self->_handle_quoting_and_encoding($self->{columns}->{$_}->{text}, 1, $opts->{encoding}) } @visible_columns ]);

    } else {
      foreach my $row (@{ $self->{custom_headers} }) {
        my $fields = [ ];

        foreach my $col (@{ $row }) {
          my $num_output = ($col->{colspan} && ($col->{colspan} > 1)) ? $col->{colspan} : 1;
          push @{ $fields }, ($self->_handle_quoting_and_encoding($col->{text}, 1, $opts->{encoding})) x $num_output;
        }

        $csv->print($stdout, $fields);
      }
    }
  }

  foreach my $row_set (@{ $self->{data} }) {
    next if ('ARRAY' ne ref $row_set);
    foreach my $row (@{ $row_set }) {
      my @data;
      my $skip_next = 0;
      foreach my $col (@visible_columns) {
        if ($skip_next) {
          $skip_next--;
          next;
        }

        my $num_output = ($row->{$col}{colspan} && ($row->{$col}->{colspan} > 1)) ? $row->{$col}->{colspan} : 1;
        $skip_next     = $num_output - 1;

        push @data, join($eol, map { s/\r?\n/$eol/g; $self->_handle_quoting_and_encoding($_, 0, $opts->{encoding}) } @{ $row->{$col}->{data} });
        push @data, ('') x $skip_next if ($skip_next);
      }

      $csv->print($stdout, \@data);
    }
  }
}

sub check_for_pdf_api {
  return eval { require PDF::API2; 1; } ? 1 : 0;
}

1;

__END__

=head1 NAME

SL::ReportGenerator.pm: the kivitendo way of getting data in shape

=head1 SYNOPSIS

  my $report = SL::ReportGenerator->new(\%myconfig, $form);
     $report->set_options(%options);                         # optional
     $report->set_columns(%column_defs);
     $report->set_sort_indicator($column, $direction);       # optional
     $report->add_data($row1, $row2, @more_rows);
     $report->generate_with_headers();

This creates a report object, sets a few columns, adds some data and generates a standard report.
Sorting of columns will be alphabetic, and options will be set to their defaults.
The report will be printed including table headers, html headers and http headers.

=head1 DESCRIPTION

Imagine the following scenario:
There's a simple form, which loads some data from the database, and needs to print it out. You write a template for it.
Then there may be more than one line. You add a loop in the template.
Then there are some options made by the user, such as hidden columns. You add more to the template.
Then it lacks usability. You want it to be able to sort the data. You add code for that.
Then there are too many results, you need pagination, you want to print or export that data..... and so on.

The ReportGenerator class was designed because this exact scenario happened about half a dozen times in kivitendo.
It's purpose is to manage all those formating, culling, sorting, and templating.
Which makes it almost as complicated to use as doing the work by yourself.

=head1 FUNCTIONS

=over 4

=item new \%myconfig,$form,%options

Creates a new ReportGenerator object, sets all given options, and returns it.

=item set_columns %columns

Sets the columns available to this report.

=item set_column_order @columns

Sets the order of columns. Any columns not present here are appended in alphabetic order.

=item set_sort_indicator $column,$direction

Sets sorting of the table by specifying a column and a direction, where the direction will be evaluated to ascending if true.
Note that this is only for displaying. The data has to have already been sorted when it was added.

=item add_data \@data

=item add_data \%data

Adds data to the report. A given hash_ref is interpreted as a single line of
data, every array_ref as a collection of lines.  Every line will be expected to
be in a key => value format. Note that the rows have to already have been
sorted.

The ReportGenerator is only able to display pre-sorted data and to indicate by
which column and in which direction the data has been sorted via visual clues
in the column headers. It also provides links to invert the sort direction.

=item add_separator

Adds a separator line to the report.

=item add_control \%data

Adds a control element to the data. Control elements are an experimental feature to add functionality to a report the regular data cannot.
Every control element needs to set IS_CONTROL_DATA, in order to be recognized by the template.
Currently the only control element is a colspan element, which can be used as a mini header further down the report.

=item clear_data

Deletes all data added to the report, but keeps options set.

=item set_options %options

Sets options. For an incomplete list of options, see section configuration.

=item set_options_from_form

Tries to import options from the $form object given at creation

=item set_export_options $next_sub,@variable_list

Sets next_sub and additional variables needed for export.

=item get_attachment_basename

Returns the set attachment_basename option, or 'report' if nothing was set. See configuration for the option.

=item generate_with_headers

Parses the report, adds headers and prints it out. Headers depend on the option 'output_format',
for example 'HTML' will add proper table headers, html headers and http headers. See configuration for this option.

=item get_visible_columns $format

Returns a list of columns that will be visible in the report after considering all options or match the given format.

=item html_format $value

Escapes HTML characters in $value and substitutes newlines with '<br>'. Returns the escaped $value.

=item prepare_html_content $column,$name,@column_headers

Parses the data, and sets internal data needed for certain output format. Must be called once before the template is invoked.
Should not be called externally, since all render and generate functions invoke it anyway.

=item generate_html_content

The html generation function. Is invoked by generate_with_headers.

=item generate_pdf_content

The PDF generation function. It is invoked by generate_with_headers and renders the PDF with the PDF::API2 library.

=item generate_csv_content

The CSV generation function. Uses XS_CSV to parse the information into csv.

=back

=head1 CONFIGURATION

These are known options and their defaults. Options for pdf export and csv export need to be set as a hashref inside the export option.

=head2 General Options

=over 4

=item std_column_visibility

Standard column visibility. Used if no visibility is set. Use this to save the trouble of enabling every column. Default is no.

=item output_format

Output format. Used by generate_with_headers to determine the format. Supported options are HTML, CSV, and PDF. Default is HTML.

=item allow_pdf_export

Used to determine if a button for PDF export should be displayed. Default is yes.

=item allow_csv_export

Used to determine if a button for CSV export should be displayed. Default is yes.

=item html_template

The template to be used for HTML reports. Default is 'report_generator/html_report'.

=item controller_class

If this is used from a C<SL::Controller::Base> based controller class, pass the
class name here and make sure C<SL::Controller::Helper::ReportGenerator> is
used in the controller. That way the exports stay functional.

=back

=head2 PDF Options

=over 4

=item paper_size

Paper size. Default is a4. Supported paper sizes are a3, a4, a5, letter and legal.

=item orientation (landscape)

Landscape or portrait. Default is landscape.

=item font_name

Default is Verdana. Supported font names are Courier, Georgia, Helvetica, Times and Verdana. This option only affects the rendering with PDF::API2.

=item font_size

Default is 7. This option only affects the rendering with PDF::API2.

=item margin_top

=item margin_left

=item margin_bottom

=item margin_right

The paper margins in cm. They all default to 1.5.

=item number

Set to a true value if the pages should be numbered. Default is 1.

=item print

If set then the resulting PDF will be output to a printer. If not it will be downloaded by the user. Default is no.

=item printer_id

Default 0.

=item copies

Default 1.

=back

=head2 CSV Options

=over 4

=item quote_char

Character to enclose entries. Default is double quote (").

=item sep_char

Character to separate entries. Default is semicolon (;).

=item escape_char

Character to escape the quote_char. Default is double quote (").

=item eol_style

End of line style. Default is Unix.

=item headers

Include headers? Default is yes.

=item encoding

Character encoding. Default is UTF-8.

=back

=head1 SEE ALO

C<Template.pm>

=head1 MODULE AUTHORS

Moritz Bunkus E<lt>mbunkus@linet-services.deE<gt>

L<http://linet-services.de>
