package PDF::Table;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.9.3';

use List::Util qw(sum);

############################################################
#
# new - Constructor
#
# Parameters are meta information about the PDF
#
# $pdf = PDF::Table->new();
#
############################################################

sub new {
  my ($type) = @_;

  my $class = ref($type) || $type;
  my $self  = {};
  bless ($self, $class);
  return $self;
}

############################################################
#
# text_block - utility method to build multi-paragraph blocks of text
#
############################################################

sub text_block {
  my $self        = shift;
  my $text_object = shift;
  my $text        = shift;          # The text to be displayed
  my %arg         = @_;             # Additional Arguments

  my  ($align, $xpos, $ypos, $xbase, $ybase, $line_width, $wordspace, $endw , $width, $height)
    = (undef , undef, undef, undef , undef , undef      , undef     , undef , undef , undef  );
  my @line  = ();          # Temp data array with words on one line
  my %width = ();          # The width of every unique word in the givven text

  # Try to provide backward compatibility
  foreach my $key (keys %arg) {
    my $newkey = $key;
    if ($newkey =~ s#^-##) {
      $arg{$newkey} = $arg{$key};
      delete $arg{$key};
    }
  }
  #####

  #---
  # Lets check mandatory parameters with no default values
  #---
  $xbase  = $arg{'x'} || -1;
  $ybase  = $arg{'y'} || -1;
  $width  = $arg{'w'} || -1;
  $height = $arg{'h'} || -1;
  unless ( $xbase  > 0 ) { print "Error: Left Edge of Block is NOT defined!\n"; return; }
  unless ( $ybase  > 0 ) { print "Error: Base Line of Block is NOT defined!\n"; return; }
  unless ( $width  > 0 ) { print "Error: Width of Block is NOT defined!\n";     return; }
  unless ( $height > 0 ) { print "Error: Height of Block is NOT defined!\n";    return; }
  # Check if any text to display
  unless ( defined( $text) and length($text) > 0 ) {
    print "Warning: No input text found. Trying to add dummy '-' and not to break everything.\n";
    $text = '-';
  }

  # Strip any <CR> and Split the text into paragraphs
  $text          =~ s/\r//g;
  my @paragraphs =  split(/\n/, $text);

  # Width between lines in pixels
  my $line_space = defined $arg{'lead'} && $arg{'lead'} > 0 ? $arg{'lead'} : 12;

  # Calculate width of all words
  my $space_width = $text_object->advancewidth("\x20");
  my @words       = split(/\s+/, $text);
  foreach (@words) {
    next if exists $width{$_};
    $width{$_} = $text_object->advancewidth($_);
  }

  my @paragraph       = split(' ', shift(@paragraphs));
  my $first_line      = 1;
  my $first_paragraph = 1;

  # Little Init
  $xpos             = $xbase;
  $ypos             = $ybase;
  $ypos             = $ybase + $line_space;
  my $bottom_border = $ybase - $height;
  # While we can add another line
  while ( $ypos >= $bottom_border + $line_space ) {
    # Is there any text to render ?
    unless (@paragraph) {
      # Finish if nothing left
      last unless scalar @paragraphs;
      # Else take one line from the text
      @paragraph  = split(' ', shift( @paragraphs ) );

      $ypos      -= $arg{'parspace'} if $arg{'parspace'};
      last unless $ypos >= $bottom_border;
    }
    $ypos -= $line_space;
    $xpos  = $xbase;

    # While there's room on the line, add another word
    @line       = ();
    $line_width = 0;
    if ( $first_line && exists $arg{'hang'} ) {
      my $hang_width = $text_object->advancewidth($arg{'hang'});

      $text_object->translate( $xpos, $ypos );
      $text_object->text( $arg{'hang'} );

      $xpos          += $hang_width;
      $line_width    += $hang_width;
      $arg{'indent'} += $hang_width if $first_paragraph;

    } elsif ( $first_line && exists $arg{'flindent'} && $arg{'flindent'} > 0 ) {
      $xpos       += $arg{'flindent'};
      $line_width += $arg{'flindent'};

    } elsif ( $first_paragraph && exists $arg{'fpindent'} && $arg{'fpindent'} > 0 ) {
      $xpos       += $arg{'fpindent'};
      $line_width += $arg{'fpindent'};

    } elsif (exists $arg{'indent'} && $arg{'indent'} > 0 ) {
      $xpos       += $arg{'indent'};
      $line_width += $arg{'indent'};
    }

    # Lets take from paragraph as many words as we can put into $width - $indent;. Always take at least one word; otherwise we'd end up in an infinite loop.
    while (!scalar(@line) || (@paragraph && ($text_object->advancewidth( join("\x20", @line)."\x20" . $paragraph[0]) + $line_width < $width))) {
      push(@line, shift(@paragraph));
    }
    $line_width += $text_object->advancewidth(join('', @line));

    # calculate the space width
    if ( $arg{'align'} eq 'fulljustify' or ($arg{'align'} eq 'justify' and @paragraph)) {
      @line      = split(//,$line[0]) if (scalar(@line) == 1) ;
      $wordspace = ($width - $line_width) / (scalar(@line) - 1);
      $align     ='justify';

    } else {
      $align     = ($arg{'align'} eq 'justify') ? 'left' : $arg{'align'};
      $wordspace = $space_width;
    }
    $line_width += $wordspace * (scalar(@line) - 1);

    if ( $align eq 'justify') {
      foreach my $word (@line) {
        $text_object->translate( $xpos, $ypos );
        $text_object->text( $word );
        $xpos += ($width{$word} + $wordspace) if (@line);
      }
      $endw = $width;

    } else {
      # calculate the left hand position of the line
      if ( $align eq 'right' ) {
        $xpos += $width - $line_width;

      } elsif ( $align eq 'center' ) {
        $xpos += ( $width / 2 ) - ( $line_width / 2 );
      }

      # render the line
      $text_object->translate( $xpos, $ypos );
      $endw = $text_object->text( join("\x20", @line));
    }
    $first_line = 0;
  }#End of while(

  unshift(@paragraphs, join(' ',@paragraph)) if scalar(@paragraph);

  return ($endw, $ypos, join("\n", @paragraphs))
}


############################################################
# table - utility method to build multi-row, multicolumn tables
############################################################
sub table {
  my $self  = shift;
  my $pdf   = shift;
  my $page  = shift;
  my $data  = shift;
  my %arg   = @_;

  #=====================================
  # Mandatory Arguments Section
  #=====================================
  unless ($pdf and $page and $data) {
    print "Error: Mandatory parameter is missing pdf/page/data object!\n";
    return;
  }
  # Try to provide backward compatibility
  foreach my $key (keys %arg) {
    my $newkey = $key;
    if ($newkey =~ s#^-##) {
      $arg{$newkey} = $arg{$key};
      delete $arg{$key};
    }
  }
  #TODO: Add code for header props compatibility and col_props comp....
  #####
  my ( $xbase, $ybase, $width, $height ) = ( undef, undef, undef, undef );
  # Could be 'int' or 'real' values
  $xbase  = $arg{'x'    } || -1;
  $ybase  = $arg{'start_y'} || -1;
  $width  = $arg{'w'    } || -1;
  $height = $arg{'start_h'} || -1;

  # Global geometry parameters are also mandatory.
  unless ( $xbase  > 0 ) { print "Error: Left Edge of Table is NOT defined!\n"; return; }
  unless ( $ybase  > 0 ) { print "Error: Base Line of Table is NOT defined!\n"; return; }
  unless ( $width  > 0 ) { print "Error: Width of Table is NOT defined!\n";     return; }
  unless ( $height > 0 ) { print "Error: Height of Table is NOT defined!\n";    return; }

  # Ensure default values for -next_y and -next_h
  my $next_y       = $arg{'next_y'} || $arg{'start_y'} || 0;
  my $next_h       = $arg{'next_h'} || $arg{'start_h'} || 0;

  # Create Text Object
  my $txt          = $page->text;
  # Set Default Properties
  my $fnt_name     = $arg{'font'}            || $pdf->corefont('Times', -encode => 'utf8');
  my $fnt_size     = $arg{'font_size'}       || 12;
  my $max_word_len = $arg{'max_word_length'} || 20;

  #=====================================
  # Table Header Section
  #=====================================
  # Disable header row into the table
  my $header_props;
  my $num_header_rows = 0;
  my (@header_rows, @header_row_cell_props);
  # Check if the user enabled it ?
  if (defined $arg{'header_props'} and ref( $arg{'header_props'}) eq 'HASH') {
    # Transfer the reference to local variable
    $header_props = $arg{'header_props'};
    # Check other params and put defaults if needed
    $header_props->{'repeat'}     = $header_props->{'repeat'}     || 0;
    $header_props->{'font'}       = $header_props->{'font'}       || $fnt_name;
    $header_props->{'font_color'} = $header_props->{'font_color'} || '#000066';
    $header_props->{'font_size'}  = $header_props->{'font_size'}  || $fnt_size + 2;
    $header_props->{'bg_color'}   = $header_props->{'bg_color'}   || '#FFFFAA';

    $num_header_rows              = $arg{'num_header_rows'}       || 1;
  }
  #=====================================
  # Other Parameters check
  #=====================================

  my $lead      = $arg{'lead'}           || $fnt_size;
  my $pad_left  = $arg{'padding_left'}   || $arg{'padding'} || 0;
  my $pad_right = $arg{'padding_right'}  || $arg{'padding'} || 0;
  my $pad_top   = $arg{'padding_top'}    || $arg{'padding'} || 0;
  my $pad_bot   = $arg{'padding_bottom'} || $arg{'padding'} || 0;
  my $pad_w     = $pad_left + $pad_right;
  my $pad_h     = $pad_top  + $pad_bot  ;
  my $line_w    = defined $arg{'border'} ? $arg{'border'} : 1 ;

  my $background_color_even = $arg{'background_color_even'} || $arg{'background_color'} || undef;
  my $background_color_odd  = $arg{'background_color_odd'}  || $arg{'background_color'} || undef;
  my $font_color_even       = $arg{'font_color_even'}       || $arg{'font_color'}       || 'black';
  my $font_color_odd        = $arg{'font_color_odd'}        || $arg{'font_color'}       || 'black';
  my $border_color          = $arg{'border_color'}          || 'black';

  my $min_row_h  = $fnt_size + $pad_top + $pad_bot;
  my $row_h      = defined ($arg{'row_height'}) && ($arg{'row_height'} > $min_row_h) ? $arg{'row_height'} : $min_row_h;

  my $pg_cnt     = 1;
  my $cur_y      = $ybase;
  my $cell_props = $arg{cell_props} || [];   # per cell properties
  my $row_cnt    = $num_header_rows;

  #If there is valid data array reference use it!
  if (ref $data eq 'ARRAY') {
    # Copy the header row if header is enabled
    if (defined $header_props) {
      map { push @header_rows,           $$data[$_] }       (0..$num_header_rows - 1);
      map { push @header_row_cell_props, $$cell_props[$_] } (0..$num_header_rows - 1);
    }
    # Determine column widths based on content

    #  an arrayref whose values are a hashref holding
    #  the minimum and maximum width of that column
    my $col_props =  $arg{'column_props'} || [];

    # An array ref of arrayrefs whose values are
    #  the actual widths of the column/row intersection
    my $row_props = [];
    # An array ref with the widths of the header row
    my @header_row_widths;

    # Scalars that hold sum of the maximum and minimum widths of all columns
    my ( $max_col_w, $min_col_w ) = ( 0,0 );
    my ( $row, $col_name, $col_fnt_size, $space_w );

    # Hash that will hold the width of every word from input text
    my $word_w       = {};
    my $rows_counter = 0;

    foreach $row ( @{$data} ) {
      push(@header_row_widths, []) if ($rows_counter < $num_header_rows);

      my $column_widths = []; #holds the width of each column
      for( my $j = 0; $j < scalar(@$row) ; $j++ ) {
        # look for font information for this column
        $col_fnt_size   =  $col_props->[$j]->{'font_size'} || $fnt_size;
        if ( !$rows_counter and ref $header_props) {
          $txt->font(  $header_props->{'font'}, $header_props->{'font_size'} );

        } elsif ( $col_props->[$j]->{'font'} ) {
          $txt->font( $col_props->[$j]->{'font'}, $col_fnt_size );

        } else {
          $txt->font( $fnt_name, $col_fnt_size );
        }

        # This should fix a bug with very long word like serial numbers etc.
        # $myone is used because $1 gets out of scope in while condition
        my $myone;
        do {
          $myone = 0;
          # This RegEx will split any word that is longer than {25} symbols
          $row->[$j] =~ s#(\b\S{$max_word_len}?)(\S.*?\b)# $1 $2#;
          $myone = 1 if ( defined $2 );
        } while( $myone );
        $row->[$j] =~ s/^\s+//;

        $space_w             = $txt->advancewidth( "\x20" );
        $column_widths->[$j] = 0;
        $max_col_w           = 0;
        $min_col_w           = 0;

        my @words = split( /\s+/, $row->[$j] );

        foreach( @words ) {
          unless ( exists $word_w->{$_} ) { # Calculate the width of every word and add the space width to it
            $word_w->{$_} = $txt->advancewidth( $_ ) + $space_w;
          }
          $column_widths->[$j] += $word_w->{$_};
          $min_col_w            = $word_w->{$_} if $word_w->{$_} > $min_col_w;
          $max_col_w           += $word_w->{$_};
        }
        $min_col_w             += $pad_w;
        $max_col_w             += $pad_w;
        $column_widths->[$j]   += $pad_w;

        # Keep a running total of the overall min and max widths
        $col_props->[$j]->{min_w} = $col_props->[$j]->{min_w} || 0;
        $col_props->[$j]->{max_w} = $col_props->[$j]->{max_w} || 0;

        if ( $min_col_w > $col_props->[$j]->{min_w} ) { # Calculated Minimum Column Width is more than user-defined
          $col_props->[$j]->{min_w}    = $min_col_w ;
        }
        if ( $max_col_w > $col_props->[$j]->{max_w} ) { # Calculated Maximum Column Width is more than user-defined
          $col_props->[$j]->{max_w}    = $max_col_w ;
        }
      }#End of for(my $j....
      $row_props->[$rows_counter] = $column_widths;
      # Copy the calculated row properties of header row.
      if (($rows_counter < $num_header_rows) && $header_props) {
        push(@header_row_widths, [ @{ $column_widths } ]);
      }
      $rows_counter++;
    }
    # Calc real column widths and expand table width if needed.
    my $calc_column_widths;
    ($calc_column_widths, $width) = $self->CalcColumnWidths( $col_props, $width );
    my $num_cols  = scalar @{ $calc_column_widths };
    my $comp_cnt  = 1;
    $rows_counter = 0;

    my ( $gfx   , $gfx_bg   , $background_color , $font_color,        );
    my ( $bot_marg, $table_top_y, $text_start   , $record,  $record_widths  );

    my $remaining_header_rows = $header_props ? $num_header_rows : 0;

    # Each iteration adds a new page as neccessary
    while(scalar(@{$data})) {
      my $page_header;
      if ($pg_cnt == 1) {
        $table_top_y = $ybase;
        $bot_marg = $table_top_y - $height;

      } else {
        if (ref $arg{'new_page_func'}) {
          $page = &{$arg{'new_page_func'}};

        } else {
          $page = $pdf->page;
        }

        $table_top_y = $next_y;
        $bot_marg = $table_top_y - $next_h;

        if ( ref $header_props and $header_props->{'repeat'}) {
          foreach my $idx (0 .. $num_header_rows - 1) {
            unshift @$data,      [ @{ $header_rows[$idx]      } ];
            unshift @$row_props, [ @{ $header_row_widths[$idx] } ];
          }
          $remaining_header_rows = $num_header_rows;
        }
      }

      # Check for safety reasons
      if ( $bot_marg < 0 ) { # This warning should remain i think
#         print "!!! Warning: !!! Incorrect Table Geometry! Setting bottom margin to end of sheet!\n";
        $bot_marg = 0;
      }

      $gfx_bg = $page->gfx;
      $txt = $page->text;
      $txt->font($fnt_name, $fnt_size);
      $gfx = $page->gfx;
      $gfx->strokecolor($border_color);
      $gfx->linewidth($line_w);

      # Draw the top line
      $cur_y = $table_top_y;
      $gfx->move( $xbase , $cur_y );
      $gfx->hline($xbase + $width );

      # Each iteration adds a row to the current page until the page is full
      #  or there are no more rows to add
      while(scalar(@{$data}) and $cur_y-$row_h > $bot_marg) {
        # Remove the next item from $data
        $record = shift @{$data};
        # Added to resolve infite loop bug with returned undef values
        for(my $d = 0; $d < scalar(@{$record}) ; $d++) {
          $record->[$d] = '-' unless ( defined $record->[$d]);
        }

        $record_widths = shift @$row_props;
        next unless $record;

        # Choose colors for this row
        $background_color = $rows_counter % 2 ? $background_color_even  : $background_color_odd;
        $font_color     = $rows_counter % 2 ? $font_color_even    : $font_color_odd;

        if ($remaining_header_rows and ref $header_props) {
          $background_color = $header_props->{'bg_color'}
        }
        $text_start    = $cur_y - $fnt_size - $pad_top;
        my $cur_x    = $xbase;
        my $leftovers    = undef; # Reference to text that is returned from textblock()
        my $do_leftovers = 0;

        my ($colspan, @vertical_lines);

        # Process every column from current row
        for( my $j = 0; $j < scalar( @$record); $j++ ) {
          next unless $col_props->[$j]->{max_w};
          next unless $col_props->[$j]->{min_w};
          $leftovers->[$j] = undef;

          # Choose font color
          if ( $remaining_header_rows and ref $header_props ) {
            $txt->fillcolor( $header_props->{'font_color'} );

          } elsif ( $cell_props->[$row_cnt][$j]{font_color} ) {
            $txt->fillcolor( $cell_props->[$row_cnt][$j]{font_color} );

          } elsif ( $col_props->[$j]->{'font_color'} ) {
            $txt->fillcolor( $col_props->[$j]->{'font_color'} );

          } else {
            $txt->fillcolor($font_color);
          }

          # Choose font size
          if ( $remaining_header_rows and ref $header_props ) {
            $col_fnt_size = $header_props->{'font_size'};

          } elsif ( $col_props->[$j]->{'font_size'} ) {
            $col_fnt_size = $col_props->[$j]->{'font_size'};

          } else {
            $col_fnt_size = $fnt_size;
          }

          # Choose font family
          if ( $remaining_header_rows and ref $header_props ) {
            $txt->font( $header_props->{'font'}, $header_props->{'font_size'});

          } elsif ( $col_props->[$j]->{'font'} ) {
            $txt->font( $col_props->[$j]->{'font'}, $col_fnt_size);

          } else {
            $txt->font( $fnt_name, $col_fnt_size);
          }
          #TODO: Implement Center text align
          $col_props->[$j]->{justify} = $col_props->[$j]->{justify} || 'left';

          my $this_width;
          if (!$remaining_header_rows && $cell_props->[$row_cnt]->[$j]->{colspan}) {
            $colspan = $cell_props->[$row_cnt]->[$j]->{colspan};

          } elsif ($remaining_header_rows && $header_row_cell_props[$num_header_rows - $remaining_header_rows]->[$j]->{colspan}) {
            $colspan = $header_row_cell_props[$num_header_rows - $remaining_header_rows]->[$j]->{colspan};

          }

          if ($colspan) {
            $colspan     = $num_cols - $j if (-1 == $colspan);
            my $last_idx = $j + $colspan - 1;
            $this_width  = sum @{ $calc_column_widths }[$j..$last_idx];

          } else {
            $this_width = $calc_column_widths->[$j];
          }

          # If the content is wider than the specified width, we need to add the text as a text block
          if ($record->[$j] !~ m#(.\n.)# and  $record_widths->[$j] and ($record_widths->[$j] < $this_width)) {
            my $space = $pad_left;
            if ($col_props->[$j]->{justify} eq 'right') {
              $space = $this_width -($txt->advancewidth($record->[$j]) + $pad_right);
            }
            $txt->translate( $cur_x + $space, $text_start );
            $txt->text( $record->[$j] );
          } else { # Otherwise just use the $page->text() method
            my($width_of_last_line, $ypos_of_last_line, $left_over_text) =
              $self->text_block($txt,
                                $record->[$j],
                                'x'     => $cur_x + $pad_left,
                                'y'     => $text_start,
                                'w'     => $this_width - $pad_w,
                                'h'     => $cur_y - $bot_marg - $pad_top - $pad_bot,
                                'align' => $col_props->[$j]->{justify},
                                'lead'  => $lead
              );
            # Desi - Removed $lead because of fixed incorrect ypos bug in text_block
            my $this_row_h = $cur_y - ( $ypos_of_last_line - $pad_bot );
            $row_h = $this_row_h if $this_row_h > $row_h;
            if ( $left_over_text ) {
              $leftovers->[$j] = $left_over_text;
              $do_leftovers    = 1;
            }
          }
          $cur_x += $calc_column_widths->[$j];

          push @vertical_lines, (!$colspan || (1 >= $colspan)) ? 1 : 0;
          $colspan-- if ($colspan);
        }

        if ( $do_leftovers ) {
          unshift @$data, $leftovers;
          unshift @$row_props, $record_widths;
          $rows_counter--;
        }

        # Draw cell bgcolor
        # This has to be separately from the text loop
        #  because we do not know the final height of the cell until all text has been drawn
        $cur_x = $xbase;
        for(my $j =0;$j < scalar(@$record);$j++) {
          if (  $cell_props->[$row_cnt][$j]->{'background_color'} ||
                $col_props->[$j]->{'background_color'} ||
                $background_color ) {
            $gfx_bg->rect( $cur_x, $cur_y-$row_h, $calc_column_widths->[$j], $row_h);
            if ( $cell_props->[$row_cnt][$j]->{'background_color'} && !$remaining_header_rows ) {
              $gfx_bg->fillcolor($cell_props->[$row_cnt][$j]->{'background_color'});

            } elsif ( $col_props->[$j]->{'background_color'} && !$remaining_header_rows  ) {
              $gfx_bg->fillcolor($col_props->[$j]->{'background_color'});

            } else {
              $gfx_bg->fillcolor($background_color);
            }
            $gfx_bg->fill();
          }

          $cur_x += $calc_column_widths->[$j];

          if ($line_w && $vertical_lines[$j] && ($j != (scalar(@{ $record }) - 1))) {
            $gfx->move($cur_x, $cur_y);
            $gfx->vline($cur_y - $row_h);
            $gfx->fillcolor($border_color);
          }
        }#End of for(my $j....

        $cur_y -= $row_h;
        $row_h  = $min_row_h;
        $gfx->move(  $xbase , $cur_y );
        $gfx->hline( $xbase + $width );
        $rows_counter++;
        if ($remaining_header_rows) {
          $remaining_header_rows--;
        } else {
          $row_cnt++;
        }
      }# End of while(scalar(@{$data}) and $cur_y-$row_h > $bot_marg)

      # Draw vertical lines
      if ($line_w) {
        $gfx->move($xbase, $table_top_y);
        $gfx->vline($cur_y);
        $gfx->move($xbase + sum(@{ $calc_column_widths }[0..$num_cols - 1]), $table_top_y);
        $gfx->vline($cur_y);
        $gfx->fillcolor($border_color);
        $gfx->stroke();
      }
      $pg_cnt++;
    }# End of while(scalar(@{$data}))
  }# End of if (ref $data eq 'ARRAY')

  return ($page,--$pg_cnt,$cur_y);
}


# calculate the column widths
sub CalcColumnWidths {
  my $self    = shift;
  my $col_props   = shift;
  my $avail_width = shift;
  my $min_width   = 0;

  my $calc_widths ;
  for(my $j = 0; $j < scalar( @$col_props); $j++) {
    $min_width += $col_props->[$j]->{min_w};
  }

  # I think this is the optimal variant when good view can be guaranateed
  if ($avail_width < $min_width) {
#     print "!!! Warning !!!\n Calculated Mininal width($min_width) > Table width($avail_width).\n",
#       ' Expanding table width to:',int($min_width)+1,' but this could lead to unexpected results.',"\n",
#       ' Possible solutions:',"\n",
#       '  0)Increase table width.',"\n",
#       '  1)Decrease font size.',"\n",
#       '  2)Choose a more narrow font.',"\n",
#       '  3)Decrease "max_word_length" parameter.',"\n",
#       '  4)Rotate page to landscape(if it is portrait).',"\n",
#       '  5)Use larger paper size.',"\n",
#       '!!! --------- !!!',"\n";
    $avail_width = int( $min_width) + 1;

  }

  my $span = 0;
  # Calculate how much can be added to every column to fit the available width
  $span = ($avail_width - $min_width) / scalar( @$col_props);
  for (my $j = 0; $j < scalar(@$col_props); $j++ ) {
    $calc_widths->[$j] = $col_props->[$j]->{min_w} + $span;
  }

  return ($calc_widths,$avail_width);
}
1;

__END__

=pod

=head1 NAME

PDF::Table - A utility class for building table layouts in a PDF::API2 object.

=head1 SYNOPSIS

 use PDF::API2;
 use PDF::Table;

 my $pdftable = new PDF::Table;
 my $pdf = new PDF::API2(-file => "table_of_lorem.pdf");
 my $page = $pdf->page;

 # some data to layout
 my $some_data =[
    ["1 Lorem ipsum dolor",
    "Donec odio neque, faucibus vel",
    "consequat quis, tincidunt vel, felis."],
    ["Nulla euismod sem eget neque.",
    "Donec odio neque",
    "Sed eu velit."],
    #... and so on
 ];

 $left_edge_of_table = 50;
 # build the table layout
 $pdftable->table(
     # required params
     $pdf,
     $page,
     $some_data,
     x => $left_edge_of_table,
     w => 495,
     start_y => 750,
     next_y  => 700,
     start_h => 300,
     next_h  => 500,
     # some optional params
     padding => 5,
     padding_right => 10,
     background_color_odd  => "gray",
     background_color_even => "lightblue", #cell background color for even rows
  );

 # do other stuff with $pdf
 $pdf->saveas();
...

=head1 EXAMPLE

For a complete working example or initial script look into distribution`s 'examples' folder.


=head1 DESCRIPTION

This class is a utility for use with the PDF::API2 module from CPAN.
It can be used to display text data in a table layout within the PDF.
The text data must be in a 2d array (such as returned by a DBI statement handle fetchall_arrayref() call).
The PDF::Table will automatically add as many new pages as necessary to display all of the data.
Various layout properties, such as font, font size, and cell padding and background color can be specified for each column and/or for even/odd rows.
Also a (non)repeated header row with different layout properties can be specified.

See the METHODS section for complete documentation of every parameter.

=head1  METHODS

=head2 new

=over

Returns an instance of the class. There are no parameters.

=back

=head2 table($pdf, $page_obj, $data, %opts)

=over

The main method of this class.
Takes a PDF::API2 instance, a page instance, some data to build the table and formatting options.
The formatting options should be passed as named parameters.
This method will add more pages to the pdf instance as required based on the formatting options and the amount of data.

=back

=over

The return value is a 3 item list where
The first item is the PDF::API2::Page instance that the table ends on,
The second item is the count of pages that the table spans, and
The third item is the y position of the table bottom.

=back

=over

=item Example:

 ($end_page, $pages_spanned, $table_bot_y) = $pdftable->table(
     $pdf,               # A PDF::API2 instance
     $page_to_start_on,  # A PDF::API2::Page instance created with $page_to_start_on = $pdf->page();
     $data,              # 2D arrayref of text strings
     x  => $left_edge_of_table,    #X - coordinate of upper left corner
     w  => 570, # width of table.
     start_y => $initial_y_position_on_first_page,
     next_y  => $initial_y_position_on_every_new_page,
     start_h => $table_height_on_first_page,
     next_h  => $table_height_on_every_new_page,
     #OPTIONAL PARAMS BELOW
     max_word_length=> 20,   # add a space after every 20th symbol in long words like serial numbers
     padding        => 5,    # cell padding
     padding_top    => 10,   # top cell padding, overides padding
     padding_right  => 10,   # right cell padding, overides padding
     padding_left   => 10,   # left cell padding, overides padding
     padding_bottom => 10,   # bottom padding, overides -padding
     border         => 1,    # border width, default 1, use 0 for no border
     border_color   => 'red',# default black
     font           => $pdf->corefont("Helvetica", -encoding => "utf8"), # default font
     font_size      => 12,
     font_color_odd => 'purple',
     font_color_even=> 'black',
     background_color_odd  => 'gray',         #cell background color for odd rows
     background_color_even => 'lightblue',     #cell background color for even rows
     new_page_func  => $code_ref,  # see section TABLE SPANNING
     header_props   => $hdr_props, # see section HEADER ROW PROPERTIES
     column_props   => $col_props, # see section COLUMN PROPERTIES
     cell_props     => $row_props, # see section CELL PROPERTIES
 )

=back

=over

=item HEADER ROW PROPERTIES

If the 'header_props' parameter is used, it should be a hashref.
It is your choice if it will be anonymous inline hash or predefined one.
Also as you can see there is no data variable for the content because the module asumes that the first table row will become the header row. It will copy this row and put it on every new page if 'repeat' param is set.

=back

    $hdr_props =
    {
        # This param could be a pdf core font or user specified TTF.
        #  See PDF::API2 FONT METHODS for more information
        font       => $pdf->corefont("Times", -encoding => "utf8"),
        font_size  => 10,
        font_color => '#006666',
        bg_color   => 'yellow',
        repeat     => 1,    # 1/0 eq On/Off  if the header row should be repeated to every new page
    };

=over

=item COLUMN PROPERTIES

If the 'column_props' parameter is used, it should be an arrayref of hashrefs,
with one hashref for each column of the table. The columns are counted from left to right so the hash reference at $col_props[0] will hold properties for the first column from left to right.
If you DO NOT want to give properties for a column but to give for another just insert and empty hash reference into the array for the column that you want to skip. This will cause the counting to proceed as expected and the properties to be applyed at the right columns.

Each hashref can contain any of the keys shown below:

=back

  $col_props = [
    {},# This is an empty hash so the next one will hold the properties for the second row from left to right.
    {
        min_w => 100,       # Minimum column width.
        justify => 'right', # One of left|right ,
        font => $pdf->corefont("Times", -encoding => "latin1"),
        font_size => 10,
        font_color=> 'blue',
        background_color => '#FFFF00',
    },
    # etc.
  ];

=over

If the 'min_w' parameter is used for 'col_props', have in mind that it can be overwritten
by the calculated minimum cell witdh if the userdefined value is less that calculated.
This is done for safety reasons.
In cases of a conflict between column formatting and odd/even row formatting,
the former will override the latter.

=back

=over

=item CELL PROPERTIES

If the 'cell_props' parameter is used, it should be an arrayref with arrays of hashrefs
(of the same dimension as the data array) with one hashref for each cell of the table.
Each hashref can contain any of keys shown here:

=back

  $cell_props = [
    [ #This array is for the first row. If header_props is defined it will overwrite this settings.
      {#Row 1 cell 1
        background_color => '#AAAA00',
        font_color       => 'blue',
      },
      # etc.
    ],
    [ #Row 2
      {#Row 2 cell 1
        background_color => '#CCCC00',
        font_color       => 'blue',
      },
      {#Row 2 cell 2
        background_color => '#CCCC00',
        font_color       => 'blue',
      },
      # etc.
    ],
  # etc.
  ];

=over

In case of a conflict between column, odd/even and cell formating, cell formating will overwrite the other two.
In case of a conflict between header row cell formating, header formating will win.

=back

=over



=item TABLE SPANNING

If used the parameter 'new_page_func' must be a function reference which when executed will create a new page and will return the object back to the module.
For example you can use it to put Page Title, Page Frame, Page Numbers and other staff that you need.
Also if you need some different type of paper size and orientation than the default A4-Portrait for example B2-Landscape you can use this function ref to set it up for you. For more info about creating pages refer to PDF::API2 PAGE METHODS Section.
Dont forget that your function must return a page object created with PDF::API2 page() method.

=back

=head2 text_block( $txtobj, $string, x => $x, y => $y, w => $width, h => $height)

=over

Utility method to create a block of text. The block may contain multiple paragraphs.
It is mainly used internaly but you can use it from outside for placing formated text anywhere on the sheet.

=back

=over

=item Example:

=back

=over

 # PDF::API2 objects
 my $page = $pdf->page;
 my $txt = $page->text;

=back

=over

 ($width_of_last_line, $ypos_of_last_line, $left_over_text) = $pdftable->text_block(
    $txt,
    $text_to_place,
    #X,Y - coordinates of upper left corner
    x        => $left_edge_of_block,
    y        => $y_position_of_first_line,
    w        => $width_of_block,
    h        => $height_of_block,
    #OPTIONAL PARAMS
    lead     => $font_size | $distance_between_lines,
    align    => "left|right|center|justify|fulljustify",
    hang     => $optional_hanging_indent,
    Only one of the subsequent 3params can be given.
    They override each other.-parspace is the weightest
    parspace => $optional_vertical_space_before_first_paragraph,
    flindent => $optional_indent_of_first_line,
    fpindent => $optional_indent_of_first_paragraph,

    indent   => $optional_indent_of_text_to_every_non_first_line,
 );


=back

=head1 AUTHOR

Daemmon Hughes

=head1 DEVELOPMENT

ALL IMPROVEMENTS and BUGS Since Ver: 0.02

Desislav Kamenov

=head1 VERSION

0.9.3

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Daemmon Hughes, portions Copyright 2004 Stone
Environmental Inc. (www.stone-env.com) All Rights Reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=head1 PLUGS

by Daemmon Hughes

Much of the work on this module was sponsered by
Stone Environmental Inc. (www.stone-env.com).

The text_block() method is a slightly modified copy of the one from
Rick Measham's PDF::API2 tutorial at
http://pdfapi2.sourceforge.net/cgi-bin/view/Main/YourFirstDocument
update: The tutorial is no longer available. Please visit http://pdfapi2.sourceforge.net .

by Desislav Kamenov

The development of this module is sponsored by SEEBURGER AG (www.seeburger.com)

Thanks to my friends Krasimir Berov and Alex Kantchev for helpful tips and QA during development.

=head1 SEE ALSO

L<PDF::API2>

=cut
