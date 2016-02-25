package PDF::Table;

use 5.006;
use strict;
use warnings;
use Carp;
our $VERSION = '0.9.10';

print __PACKAGE__.' is version: '.$VERSION.$/ if($ENV{'PDF_TABLE_DEBUG'});

############################################################
#
# new - Constructor
#
# Parameters are meta information about the PDF
#
# $pdf = PDF::Table->new();
#
############################################################

sub new
{
    my $type = shift(@_);
    my $class = ref($type) || $type;
    my $self  = {};
    bless ($self, $class);

    # Pass all the rest to init for validation and initialisation
    $self->_init(@_);

    return $self;
}

sub _init
{
    my ($self, $pdf, $page, $data, %options ) = @_;

    # Check and set default values 
    $self->set_defaults();

    # Check and set mandatory params
    $self->set_pdf($pdf);
    $self->set_page($page);
    $self->set_data($data);
    $self->set_options(\%options);

    return;
}

sub set_defaults{
	my $self = shift;
	
	$self->{'font_size'} = 12;
}

sub set_pdf{
    my ($self, $pdf) = @_;
    $self->{'pdf'} = $pdf;
}

sub set_page{
    my ($self, $page) = @_;
    if ( defined($page) && ref($page) ne 'PDF::API2::Page' ){

        if( ref($self->{'pdf'}) eq 'PDF::API2' ){
            $self->{'page'} = $self->{'pdf'}->page();
        } else {
            carp 'Warning: Page must be a PDF::API2::Page object but it seems to be: '.ref($page).$/;
            carp 'Error: Cannot set page from passed PDF object either as it is invalid!'.$/;
        }
        return;
    }
    $self->{'page'} = $page;

}

sub set_data{
    my ($self, $data) = @_;
    #TODO: implement
}

sub set_options{
    my ($self, $options) = @_;
    #TODO: implement
}

############################################################
#
# text_block - utility method to build multi-paragraph blocks of text
#
############################################################

sub text_block
{
    my $self        = shift;
    my $text_object = shift;
    my $text        = shift;    # The text to be displayed
    my %arg         = @_;       # Additional Arguments

    my  ( $align, $xpos, $ypos, $xbase, $ybase, $line_width, $wordspace, $endw , $width, $height) = 
        ( undef , undef, undef, undef , undef , undef      , undef     , undef , undef , undef  );
    my @line        = ();       # Temp data array with words on one line 
    my %width       = ();       # The width of every unique word in the givven text

    # Try to provide backward compatibility
    foreach my $key (keys %arg)
    {
        my $newkey = $key;
        if($newkey =~ s#^-##)
        {
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
    unless( $xbase  > 0 ){ carp "Error: Left Edge of Block is NOT defined!\n";  return; }
    unless( $ybase  > 0 ){ carp "Error: Base Line of Block is NOT defined!\n"; return; }
    unless( $width  > 0 ){ carp "Error: Width of Block is NOT defined!\n";  return; }
    unless( $height > 0 ){ carp "Error: Height of Block is NOT defined!\n"; return; }
    # Check if any text to display
    unless( defined( $text) and length($text) > 0 )
    {
        carp "Warning: No input text found. Trying to add dummy '-' and not to break everything.\n";
        $text = '-';
    }

    # Strip any <CR> and Split the text into paragraphs
    $text =~ s/\r//g;
    my @paragraphs  = split(/\n/, $text);

    # Width between lines in pixels
    my $line_space = defined $arg{'lead'} && $arg{'lead'} > 0 ? $arg{'lead'} : 12;

    # Calculate width of all words
    my $space_width = $text_object->advancewidth("\x20");
    my @words = split(/\s+/, $text);
    foreach (@words) 
    {
        next if exists $width{$_};
        $width{$_} = $text_object->advancewidth($_);
    }

    my @paragraph = split(' ', shift(@paragraphs));
    my $first_line = 1;
    my $first_paragraph = 1;

    # Little Init
    $xpos = $xbase;
    $ypos = $ybase;
    $ypos = $ybase + $line_space;
    my $bottom_border = $ypos - $height; 
    # While we can add another line
    while ( $ypos >= $bottom_border + $line_space ) 
    {
        # Is there any text to render ?
        unless (@paragraph) 
        {
            # Finish if nothing left
            last unless scalar @paragraphs;
            # Else take one line from the text
            @paragraph = split(' ', shift( @paragraphs ) );

            $ypos -= $arg{'parspace'} if $arg{'parspace'};
            last unless $ypos >= $bottom_border;
        }
        $ypos -= $line_space;
        $xpos = $xbase;

        # While there's room on the line, add another word
        @line = ();
        $line_width = 0;
        if( $first_line && exists $arg{'hang'} ) 
        {
            my $hang_width = $text_object->advancewidth($arg{'hang'});
    
            $text_object->translate( $xpos, $ypos );
            $text_object->text( $arg{'hang'} );
    
            $xpos         += $hang_width;
            $line_width   += $hang_width;
            $arg{'indent'} += $hang_width if $first_paragraph;
        }
        elsif( $first_line && exists $arg{'flindent'} && $arg{'flindent'} > 0 ) 
        {
            $xpos += $arg{'flindent'};
            $line_width += $arg{'flindent'};
        }
        elsif( $first_paragraph && exists $arg{'fpindent'} && $arg{'fpindent'} > 0 ) 
        {
            $xpos += $arg{'fpindent'};
            $line_width += $arg{'fpindent'};
        }
        elsif (exists $arg{'indent'} && $arg{'indent'} > 0 ) 
        {
            $xpos += $arg{'indent'};
            $line_width += $arg{'indent'};
        }
    
        # Lets take from paragraph as many words as we can put into $width - $indent; 
        while ( @paragraph and $text_object->advancewidth( join("\x20", @line)."\x20" . $paragraph[0]) + 
                                $line_width < $width ) 
        {
            push(@line, shift(@paragraph));
        }
        $line_width += $text_object->advancewidth(join('', @line));
            
        # calculate the space width
        if( $arg{'align'} eq 'fulljustify' or ($arg{'align'} eq 'justify' and @paragraph)) 
        {
            @line = split(//,$line[0]) if (scalar(@line) == 1) ;
            $wordspace = ($width - $line_width) / (scalar(@line) - 1);
            $align='justify';
        } 
        else 
        {
            $align=($arg{'align'} eq 'justify') ? 'left' : $arg{'align'};
            $wordspace = $space_width;
        }
        $line_width += $wordspace * (scalar(@line) - 1);
    
        if( $align eq 'justify') 
        {
            foreach my $word (@line) 
            {
                $text_object->translate( $xpos, $ypos );
                $text_object->text( $word );
                $xpos += ($width{$word} + $wordspace) if (@line);
            }
            $endw = $width;
        } 
        else 
        {
            # calculate the left hand position of the line
            if( $align eq 'right' ) 
            {
                $xpos += $width - $line_width;
            } 
            elsif( $align eq 'center' ) 
            {
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


################################################################
# table - utility method to build multi-row, multicolumn tables
################################################################
sub table
{
    my $self    = shift;
    my $pdf     = shift;
    my $page    = shift;
    my $data    = shift;
    my %arg     = @_;

    #=====================================
    # Mandatory Arguments Section
    #=====================================
    unless($pdf and $page and $data)
    {
        carp "Error: Mandatory parameter is missing pdf/page/data object!\n";
        return;
    }

    # Validate mandatory argument data type
    croak "Error: Invalid pdf object received."  unless (ref($pdf) eq 'PDF::API2');
    croak "Error: Invalid page object received." unless (ref($page) eq 'PDF::API2::Page');
    croak "Error: Invalid data received."        unless ((ref($data) eq 'ARRAY') && scalar(@$data));
    croak "Error: Missing required settings."    unless (scalar(keys %arg));

    # Validate settings key
    my %valid_settings_key = (
	x                     => 1,
        w                     => 1,
        start_y               => 1,
        start_h               => 1,
        next_y                => 1,
        next_h                => 1,
        lead                  => 1,
        padding               => 1,
        padding_right         => 1,
        padding_left          => 1,
        padding_top           => 1,
        padding_bottom        => 1,
        background_color      => 1,
        background_color_odd  => 1,
        background_color_even => 1,
        border                => 1,
        border_color          => 1,
        horizontal_borders    => 1,
        vertical_borders      => 1,
        font                  => 1,
        font_size             => 1,
        font_color            => 1,
        font_color_even       => 1,
        background_color_odd  => 1,
        background_color_even => 1,
        row_height            => 1,
        new_page_func         => 1,
        header_props          => 1,
        column_props          => 1,
        cell_props            => 1,
        max_word_length       => 1,
    );
    foreach my $key (keys %arg) {
	croak "Error: Invalid setting key '$key' received." 
            unless (exists $valid_settings_key{$key});
    }

    # Try to provide backward compatibility
    foreach my $key (keys %arg)
    {
        my $newkey = $key;
        if($newkey =~ s#^-##)
        {
            $arg{$newkey} = $arg{$key};
            delete $arg{$key};
        }
    }
    
    ######
    #TODO: Add code for header props compatibility and col_props comp....
    ######
    my ( $xbase, $ybase, $width, $height ) = ( undef, undef, undef, undef );
    # Could be 'int' or 'real' values
    $xbase  = $arg{'x'      } || -1;    
    $ybase  = $arg{'start_y'} || -1;
    $width  = $arg{'w'      } || -1;
    $height = $arg{'start_h'} || -1;

    # Global geometry parameters are also mandatory. 
    unless( $xbase  > 0 ){ carp "Error: Left Edge of Table is NOT defined!\n";  return; }
    unless( $ybase  > 0 ){ carp "Error: Base Line of Table is NOT defined!\n"; return; }
    unless( $width  > 0 ){ carp "Error: Width of Table is NOT defined!\n";  return; }
    unless( $height > 0 ){ carp "Error: Height of Table is NOT defined!\n"; return; }

    # Ensure default values for -next_y and -next_h
    my $next_y  = $arg{'next_y'} || $arg{'start_y'} || 0;
    my $next_h  = $arg{'next_h'} || $arg{'start_h'} || 0;

    # Create Text Object
    my $txt     = $page->text;

    # Set Default Properties
    my $fnt_name    = $arg{'font'            } || $pdf->corefont('Times',-encode => 'utf8');
    my $fnt_size    = $arg{'font_size'       } || 12;
    my $max_word_len= $arg{'max_word_length' } || 20;

    #=====================================
    # Table Header Section
    #=====================================
    # Disable header row into the table
    my $header_props = undef;

    # Check if the user enabled it ?
    if(defined $arg{'header_props'} and ref( $arg{'header_props'}) eq 'HASH')
    {
        # Transfer the reference to local variable
        $header_props = $arg{'header_props'};

        # Check other params and put defaults if needed
        $header_props->{'repeat'        } = $header_props->{'repeat'        } || 0;
        $header_props->{'font'          } = $header_props->{'font'          } || $fnt_name;
        $header_props->{'font_color'    } = $header_props->{'font_color'    } || '#000066';
        $header_props->{'font_size'     } = $header_props->{'font_size'     } || $fnt_size + 2;
        $header_props->{'bg_color'      } = $header_props->{'bg_color'      } || '#FFFFAA';
        $header_props->{'justify'       } = $header_props->{'justify'       };
    }

    my $header_row  = undef;
    #=====================================
    # Other Parameters check
    #=====================================
    my $lead          = $arg{'lead'          } || $fnt_size;
    my $pad_left      = $arg{'padding_left'  } || $arg{'padding'} || 0;
    my $pad_right     = $arg{'padding_right' } || $arg{'padding'} || 0;
    my $pad_top       = $arg{'padding_top'   } || $arg{'padding'} || 0;
    my $pad_bot       = $arg{'padding_bottom'} || $arg{'padding'} || 0;
    my $line_w        = defined $arg{'border'} ? $arg{'border'} : 1 ;
    my $horiz_borders = defined $arg{'horizontal_borders'}
        ? $arg{'horizontal_borders'}
        : $line_w;
    my $vert_borders  = defined $arg{'vertical_borders'}
        ? $arg{'vertical_borders'}
        : $line_w;
    
    my $background_color_even   = $arg{'background_color_even'  } || $arg{'background_color'} || undef;
    my $background_color_odd    = $arg{'background_color_odd'   } || $arg{'background_color'} || undef;
    my $font_color_even         = $arg{'font_color_even'        } || $arg{'font_color'      } || 'black';
    my $font_color_odd          = $arg{'font_color_odd'         } || $arg{'font_color'      } || 'black';
    my $border_color            = $arg{'border_color'           } || 'black';

    my $min_row_h   = $fnt_size + $pad_top + $pad_bot;
    my $row_h       = defined ($arg{'row_height'}) 
                                && 
                    ($arg{'row_height'} > $min_row_h) 
                                ? 
                     $arg{'row_height'} : $min_row_h;

    my $pg_cnt      = 1;
    my $cur_y       = $ybase;
    my $cell_props  = $arg{cell_props} || [];   # per cell properties

    #If there is no valid data array reference warn and return!
    if(ref $data ne 'ARRAY')
    {
        carp "Passed table data is not an ARRAY reference. It's actually a ref to ".ref($data);
        return ($page,0,$cur_y);
    }

    # Copy the header row if header is enabled
    @$header_row = $$data[0] if defined $header_props;
    # Determine column widths based on content

    #  an arrayref whose values are a hashref holding 
    #  the minimum and maximum width of that column
    my $col_props =  $arg{'column_props'} || [];

    # An array ref of arrayrefs whose values are 
    #  the actual widths of the column/row intersection
    my $row_col_widths = [];
    # An array ref with the widths of the header row 
    my $header_row_props = [];
 
    # Scalars that hold sum of the maximum and minimum widths of all columns 
    my ( $max_col_w  , $min_col_w   ) = ( 0,0 );
    my ( $row, $col_name, $col_fnt_size, $space_w );

    my $word_widths  = {};
    my $rows_height  = [];
    my $first_row    = 1;

    for( my $row_idx = 0; $row_idx < scalar(@$data) ; $row_idx++ )
    {
        my $column_widths = []; #holds the width of each column
        # Init the height for this row
        $rows_height->[$row_idx] = 0;
        
        for( my $column_idx = 0; $column_idx < scalar(@{$data->[$row_idx]}) ; $column_idx++ )
        {
            # look for font information for this column
            my ($cell_font, $cell_font_size);
            
            if( !$row_idx and ref $header_props )
            {   
                $cell_font      = $header_props->{'font'};
                $cell_font_size = $header_props->{'font_size'};
            }
            
            # Get the most specific value if none was already set from header_props
            $cell_font      ||= $cell_props->[$row_idx][$column_idx]->{'font'} 
                            ||  $col_props->[$column_idx]->{'font'}
                            ||  $fnt_name;
                              
            $cell_font_size ||= $cell_props->[$row_idx][$column_idx]->{'font_size'}
                            ||  $col_props->[$column_idx]->{'font_size'}
                            ||  $fnt_size;
                              
            # Set Font
            $txt->font( $cell_font, $cell_font_size ); 
            
            # Set row height to biggest font size from row's cells
            if( $cell_font_size  > $rows_height->[$row_idx] )
            {   
                $rows_height->[$row_idx] = $cell_font_size;
            }

            # This should fix a bug with very long words like serial numbers etc.
            if( $max_word_len > 0 )
            {
                $data->[$row_idx][$column_idx] =~ s#(\S{$max_word_len})(?=\S)#$1 #g;
            }

            # Init cell size limits
            $space_w                      = $txt->advancewidth( "\x20" );
            $column_widths->[$column_idx] = 0;
            $max_col_w                    = 0;
            $min_col_w                    = 0;

            my @words = split( /\s+/, $data->[$row_idx][$column_idx] );

            foreach( @words ) 
            {
                unless( exists $word_widths->{$_} )
                {   # Calculate the width of every word and add the space width to it
                    $word_widths->{$_} = $txt->advancewidth( $_ ) + $space_w;
                }
                
                $column_widths->[$column_idx] += $word_widths->{$_};
                $min_col_w                     = $word_widths->{$_} if( $word_widths->{$_} > $min_col_w );
                $max_col_w                    += $word_widths->{$_};
            }
            
            $min_col_w                    += $pad_left + $pad_right;
            $max_col_w                    += $pad_left + $pad_right;
            $column_widths->[$column_idx] += $pad_left + $pad_right;

            # Keep a running total of the overall min and max widths
            $col_props->[$column_idx]->{'min_w'} ||= 0;
            $col_props->[$column_idx]->{'max_w'} ||= 0;

            if( $min_col_w > $col_props->[$column_idx]->{'min_w'} )
            {   # Calculated Minimum Column Width is more than user-defined
                $col_props->[$column_idx]->{'min_w'} = $min_col_w ;
            }
            
            if( $max_col_w > $col_props->[$column_idx]->{'max_w'} )
            {   # Calculated Maximum Column Width is more than user-defined
                $col_props->[$column_idx]->{'max_w'} = $max_col_w ;
            }
        }#End of for(my $column_idx....
        
        $row_col_widths->[$row_idx] = $column_widths;
        
        # Copy the calculated row properties of header row. 
        @$header_row_props = @$column_widths if(!$row_idx and ref $header_props);
    }

    # Calc real column widths and expand table width if needed.
    my $calc_column_widths; 
    ($calc_column_widths, $width) = CalcColumnWidths( $col_props, $width );

    # Lets draw what we have!
    my $row_index    = 0;
    # Store header row height for later use if headers have to be repeated
    my $header_row_height = $rows_height->[0];

    my ( $gfx, $gfx_bg, $background_color, $font_color, $bot_marg, $table_top_y, $text_start);

    # Each iteration adds a new page as neccessary
    while(scalar(@{$data}))
    {
        my ($page_header, $columns_number);

        if($pg_cnt == 1)
        {
            $table_top_y = $ybase;
            $bot_marg = $table_top_y - $height;
        }
        else
        {
            if(ref $arg{'new_page_func'})
            {   
                $page = &{$arg{'new_page_func'}};   
            }
            else
            {   
                $page = $pdf->page; 
            }
    
            $table_top_y = $next_y;
            $bot_marg = $table_top_y - $next_h;

            if( ref $header_props and $header_props->{'repeat'})
            {
                # Copy Header Data
                @$page_header = @$header_row;
                my $hrp ;
                @$hrp = @$header_row_props ;
                # Then prepend it to master data array
                unshift @$data, @$page_header;
                unshift @$row_col_widths, $hrp;
                unshift @$rows_height, $header_row_height;

                $first_row = 1; # Means YES
                $row_index--; # Rollback the row_index because a new header row has been added
            }
        }

        # Check for safety reasons
        if( $bot_marg < 0 )
        {   # This warning should remain i think
            carp "!!! Warning: !!! Incorrect Table Geometry! Setting bottom margin to end of sheet!\n";
            $bot_marg = 0;
        }

        $gfx_bg = $page->gfx;
        $txt = $page->text;
        $txt->font($fnt_name, $fnt_size); 

        $cur_y = $table_top_y;

        if ($line_w)
        {
            $gfx = $page->gfx;
            $gfx->strokecolor($border_color);
            $gfx->linewidth($line_w);

            # Draw the top line
            if ($horiz_borders) 
            {
                $gfx->move( $xbase , $cur_y );
                $gfx->hline($xbase + $width );
            }
        }
        else
        {
            $gfx = undef;
        }

        # Each iteration adds a row to the current page until the page is full 
        #  or there are no more rows to add
        # Row_Loop
        while(scalar(@{$data}) and $cur_y-$row_h > $bot_marg)
        {
            # Remove the next item from $data
            my $record = shift @{$data};
            
            # Get columns number to know later how many vertical lines to draw
            # TODO: get the max number of columns per page as currently last row's columns overrides
            $columns_number = scalar(@$record);

            # Get the next set of row related settings
            # Row Height
            my $pre_calculated_row_height = shift @$rows_height;

            # Row cell widths
            my $record_widths = shift @$row_col_widths;

            # Row coloumn props - TODO in another commit

            # Row cell props - TODO in another commit

            # Added to resolve infite loop bug with returned undef values
            for(my $d = 0; $d < scalar(@{$record}) ; $d++)
            { 
                $record->[$d] = '-' unless( defined $record->[$d]); 
            }

            # Choose colors for this row
            $background_color = $row_index % 2 ? $background_color_even  : $background_color_odd;
            $font_color       = $row_index % 2 ? $font_color_even        : $font_color_odd;

            #Determine current row height
            my $current_row_height = $pad_top + $pre_calculated_row_height + $pad_bot;

            # $row_h is the calculated global user requested row height.
            # It will be honored, only if it has bigger value than the calculated one.
            # TODO: It's questionable if padding should be inclided in this calculation or not
            if($current_row_height < $row_h){
                $current_row_height = $row_h;
            }

            # Define the font y base position for this line.
            $text_start      = $cur_y - ($current_row_height - $pad_bot);

            my $cur_x        = $xbase;
            my $leftovers    = undef;   # Reference to text that is returned from textblock()
            my $do_leftovers = 0;

            # Process every cell(column) from current row
            for( my $column_idx = 0; $column_idx < scalar( @$record); $column_idx++ ) 
            {
                next unless $col_props->[$column_idx]->{'max_w'};
                next unless $col_props->[$column_idx]->{'min_w'};  
                $leftovers->[$column_idx] = undef;

                # look for font information for this cell
                my ($cell_font, $cell_font_size, $cell_font_color, $justify);
                                    
                if( $first_row and ref $header_props)
                {   
                    $cell_font       = $header_props->{'font'};
                    $cell_font_size  = $header_props->{'font_size'};
                    $cell_font_color = $header_props->{'font_color'};
                    $justify         = $header_props->{'justify'};
                }
                
                # Get the most specific value if none was already set from header_props
                $cell_font       ||= $cell_props->[$row_index][$column_idx]->{'font'} 
                                 ||  $col_props->[$column_idx]->{'font'}
                                 ||  $fnt_name;
                                  
                $cell_font_size  ||= $cell_props->[$row_index][$column_idx]->{'font_size'}
                                 ||  $col_props->[$column_idx]->{'font_size'}
                                 ||  $fnt_size;
                                  
                $cell_font_color ||= $cell_props->[$row_index][$column_idx]->{'font_color'}
                                 ||  $col_props->[$column_idx]->{'font_color'}
                                 ||  $font_color;
                                
                $justify         ||= $cell_props->[$row_index][$column_idx]->{'justify'}
                                 ||  $col_props->[$column_idx]->{'justify'}
                                 ||  $arg{'justify'}
                                 ||  'left';                                    
                
                # Init cell font object
                $txt->font( $cell_font, $cell_font_size );
                $txt->fillcolor($cell_font_color);
 
                # If the content is wider than the specified width, we need to add the text as a text block
                if( $record->[$column_idx] !~ m/(.\n.)/ and
                    $record_widths->[$column_idx] and 
                    $record_widths->[$column_idx] <= $calc_column_widths->[$column_idx]
                ){
                    my $space = $pad_left;
                    if ($justify eq 'right')
                    {
                        $space = $calc_column_widths->[$column_idx] -($txt->advancewidth($record->[$column_idx]) + $pad_right);
                    }
                    elsif ($justify eq 'center')
                    {
                        $space = ($calc_column_widths->[$column_idx] - $txt->advancewidth($record->[$column_idx])) / 2;
                    }
                    $txt->translate( $cur_x + $space, $text_start );
                    $txt->text( $record->[$column_idx] );
                }
                # Otherwise just use the $page->text() method
                else
                {
                    my ($width_of_last_line, $ypos_of_last_line, $left_over_text) = $self->text_block(
                        $txt,
                        $record->[$column_idx],
                        x        => $cur_x + $pad_left,
                        y        => $text_start,
                        w        => $calc_column_widths->[$column_idx] - $pad_left - $pad_right,
                        h        => $cur_y - $bot_marg - $pad_top - $pad_bot,
                        align    => $justify,
                        lead     => $lead
                    );
                    # Desi - Removed $lead because of fixed incorrect ypos bug in text_block
                    my  $current_cell_height = $cur_y - $ypos_of_last_line + $pad_bot;
                    if( $current_cell_height > $current_row_height )
                    {
                        $current_row_height = $current_cell_height;
                    }
                    
                    if( $left_over_text )
                    {
                        $leftovers->[$column_idx] = $left_over_text;
                        $do_leftovers = 1;
                    }
                }
                $cur_x += $calc_column_widths->[$column_idx];
            }
            if( $do_leftovers )
            {
                unshift @$data, $leftovers;
                unshift @$row_col_widths, $record_widths;
                unshift @$rows_height, $pre_calculated_row_height;
            }
            
            # Draw cell bgcolor
            # This has to be separately from the text loop 
            #  because we do not know the final height of the cell until all text has been drawn
            $cur_x = $xbase;
            for(my $column_idx = 0 ; $column_idx < scalar(@$record) ; $column_idx++)
            {
                my $cell_bg_color;
                                    
                if( $first_row and ref $header_props)
                {                                  #Compatibility                 Consistency with other props    
                    $cell_bg_color = $header_props->{'bg_color'} || $header_props->{'background_color'};
                }
                
                # Get the most specific value if none was already set from header_props
                $cell_bg_color ||= $cell_props->[$row_index][$column_idx]->{'background_color'} 
                               ||  $col_props->[$column_idx]->{'background_color'}
                               ||  $background_color;

                if ($cell_bg_color)
                {
                    $gfx_bg->rect( $cur_x, $cur_y-$current_row_height, $calc_column_widths->[$column_idx], $current_row_height);
                    $gfx_bg->fillcolor($cell_bg_color);
                    $gfx_bg->fill();
                }
                $cur_x += $calc_column_widths->[$column_idx];
            }#End of for(my $column_idx....

            $cur_y -= $current_row_height;
            if ($gfx && $horiz_borders)
            {
                $gfx->move(  $xbase , $cur_y );
                $gfx->hline( $xbase + $width );
            }

            $row_index++ unless ( $do_leftovers );
            $first_row = 0;
        }# End of Row_Loop

        if ($gfx)
        {
            # Draw vertical lines
            if ($vert_borders) 
            {
                $gfx->move(  $xbase, $table_top_y);
                $gfx->vline( $cur_y );
                my $cur_x = $xbase;
                for( my $j = 0; $j < $columns_number; $j++ )
                {
                    $cur_x += $calc_column_widths->[$j];
                    $gfx->move(  $cur_x, $table_top_y );
                    $gfx->vline( $cur_y );
                }
            }

            # ACTUALLY draw all the lines
            $gfx->fillcolor( $border_color);
            $gfx->stroke;
        }
        $pg_cnt++;
    }# End of while(scalar(@{$data}))

    return ($page,--$pg_cnt,$cur_y);
}


# calculate the column widths
sub CalcColumnWidths
{
    my $col_props   = shift;
    my $avail_width = shift;
    my $min_width   = 0;

    my $calc_widths ;

    for(my $j = 0; $j < scalar( @$col_props); $j++)
    {
        $min_width += $col_props->[$j]->{min_w} || 0;
    }

    # I think this is the optimal variant when good view can be guaranateed
    if($avail_width < $min_width)
    {
        carp "!!! Warning !!!\n Calculated Mininal width($min_width) > Table width($avail_width).\n",
            ' Expanding table width to:',int($min_width)+1,' but this could lead to unexpected results.',"\n",
            ' Possible solutions:',"\n",
            '  0)Increase table width.',"\n",
            '  1)Decrease font size.',"\n",
            '  2)Choose a more narrow font.',"\n",
            '  3)Decrease "max_word_length" parameter.',"\n",
            '  4)Rotate page to landscape(if it is portrait).',"\n",
            '  5)Use larger paper size.',"\n",
            '!!! --------- !!!',"\n";
        $avail_width = int( $min_width) + 1;

    }

    # Calculate how much can be added to every column to fit the available width.
    for(my $j = 0; $j < scalar(@$col_props); $j++ )
    {
        $calc_widths->[$j] = $col_props->[$j]->{min_w} || 0;;
    }

    # Allow columns to expand to max_w before applying extra space equally.
    my $is_last_iter;
    for (;;)
    {
        my $span = ($avail_width - $min_width) / scalar( @$col_props);
        last if $span <= 0;

        $min_width = 0;
        my $next_will_be_last_iter = 1;
        for(my $j = 0; $j < scalar(@$col_props); $j++ )
        {
            my $new_w = $calc_widths->[$j] + $span;

            if (!$is_last_iter && $new_w > $col_props->[$j]->{max_w})
            {
                $new_w = $col_props->[$j]->{max_w}
            }
            if ($calc_widths->[$j] != $new_w )
            {
                $calc_widths->[$j] = $new_w;
                $next_will_be_last_iter = 0;
            }
            $min_width += $new_w;
        }
        last if $is_last_iter;
        $is_last_iter = $next_will_be_last_iter;
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
     start_y => 500,
     start_h => 300,
     # some optional params
     next_y  => 750,
     next_h  => 500,
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
It can be used to display text data in a table layout within a PDF. 
The text data must be in a 2D array (such as returned by a DBI statement handle fetchall_arrayref() call). 
The PDF::Table will automatically add as many new pages as necessary to display all of the data. 
Various layout properties, such as font, font size, and cell padding and background color can be specified for each column and/or for even/odd rows. 
Also a (non)repeated header row with different layout properties can be specified. 

See the L</METHODS> section for complete documentation of every parameter.

=head1 METHODS

=head2 new()

    my $pdf_table = new PDF::Table;

=over

=item Description

Creates a new instance of the class. (to be improved)

=item Parameters

There are no parameters. 

=item Returns

Reference to the new instance

=back

=head2 table()

    my ($final_page, $number_of_pages, $final_y) = table($pdf, $page, $data, %settings)
    
=over

=item Description

Generates a multi-row, multi-column table into an existing PDF document based on provided data set and settings.

=item Parameters

    $pdf      - a PDF::API2 instance representing the document being created
    $page     - a PDF::API2::Page instance representing the current page of the document
    $data     - an ARRAY reference to a 2D data structure that will be used to build the table
    %settings - HASH with geometry and formatting parameters. 

For full %settings description see section L</Table settings> below.

This method will add more pages to the pdf instance as required based on the formatting options and the amount of data.

=item Reuturns

The return value is a 3 items list where 

    $final_page - The first item is a PDF::API2::Page instance that the table ends on
    $number_of_pages - The second item is the count of pages that the table spans on
    $final_y - The third item is the Y coordinate of the table bottom so that additional content can be added in the same document.

=item Example

    my $pdf  = new PDF::API2;
    my $page = $pdf->page();
    my $data = [
        ['foo1','bar1','baz1'],
        ['foo2','bar2','baz2']
    ];
    my %settings = (
        x       => 10,
        w       => 570,
        start_y => 220,
        start_h => 180,
    );
    
    my ($final_page, $number_of_pages, $final_y) = $pdftable->table( $pdf, $page, $data, %options );

=back

=head3 Table settings

=head4 Mandatory

There are some mandatory parameteres for setting table geometry and position across page(s)

=over 

=item B<x> - X coordinate of upper left corner of the table. Left edge of the sheet is 0.

B<Value:> can be any whole number satisfying 0 =< X < PageWidth
B<Default:> No default value 

    x => 10

=item B<start_y> - Y coordinate of upper left corner of the table at the initial page.

B<Value:> can be any whole number satisfying 0 < start_y < PageHeight (depending on space availability when embedding a table)
B<Default:> No default value

    start_y => 327

=item B<w> - width of the table starting from X.

B<Value:> can be any whole number satisfying 0 < w < PageWidth - x
B<Default:> No default value

    w  => 570

=item B<start_h> - Height of the table on the initial page

B<Value:> can be any whole number satisfying 0 < start_h < PageHeight - Current Y position
B<Default:> No default value

    start_h => 250
    
=back

=head4 Optional

=over

=item B<next_h> - Height of the table on any additional page

B<Value:> can be any whole number satisfying 0 < next_h < PageHeight
B<Default:> Value of param B<'start_h'>

    next_h  => 700

=item B<next_y> - Y coordinate of upper left corner of the table at any additional page.

B<Value:> can be any whole number satisfying 0 < next_y < PageHeight
B<Default:> Value of param B<'start_y'>

    next_y  => 750

=item B<max_word_length> - Breaks long words (like serial numbers hashes etc.) by adding a space after every Nth symbol 

B<Value:> can be any whole positive number
B<Default:> 20

    max_word_length => 20    # Will add a space after every 20 symbols

=item B<padding> - Padding applied to every cell 

=item B<padding_top>    - top cell padding, overrides 'padding'

=item B<padding_right>  - right cell padding, overrides 'padding'

=item B<padding_left>   - left cell padding, overrides 'padding'

=item B<padding_bottom> - bottom padding, overrides 'padding'

B<Value:> can be any whole positive number

B<Default padding:> 0

B<Default padding_*> $padding
    
    padding        => 5      # all sides cell padding
    padding_top    => 8,     # top cell padding, overrides 'padding'
    padding_right  => 6,     # right cell padding, overrides 'padding'
    padding_left   => 2,     # left cell padding, overrides 'padding'
    padding_bottom => undef  # bottom padding will be 5 as it will fallback to 'padding'

=item B<border> - Width of table border lines. 

=item B<horizontal_borders> - Width of horizontal border lines. Overrides 'border' value.

=item B<vertical_borders> -  Width of vertical border lines. Overrides 'border' value.

B<Value:> can be any whole positive number. When set to 0 will disable border lines.
B<Default:> 1
      
    border             => 3     # border width is 3
    horizontal_borders => 1     # horizontal borders will be 1 overriding 3
    vertical_borders   => undef # vertical borders will be 3 as it will fallback to 'border'

=item B<vertical_borders> -  Width of vertical border lines. Overrides 'border' value.

B<Value:> Color specifier as 'name' or 'HEX'
B<Default:> 'black'

    border_color => 'red'

=item B<font> - instance of PDF::API2::Resource::Font defining the fontf to be used in the table

B<Value:> can be any PDF::API2::Resource::* type of font
B<Default:> 'Times' with UTF8 encoding

    font => $pdf->corefont("Helvetica", -encoding => "utf8")

=item B<font_size> - Default size of the font that will be used across the table

B<Value:> can be any positive number
B<Default:> 12
    
    font_size => 16

=item B<font_color> - Font color for all rows

=item B<font_color_odd> - Font color for odd rows

=item B<font_color_even> - Font color for even rows 

=item B<background_color_odd> - Background color for odd rows

=item B<background_color_even> - Background color for even rows

B<Value:> Color specifier as 'name' or 'HEX'
B<Default:> 'black' font on 'white' background

    font_color            => '#333333'
    font_color_odd        => 'purple'
    font_color_even       => '#00FF00'
    background_color_odd  => 'gray'     
    background_color_even => 'lightblue'

=item B<row_height> - Desired row height but it will be honored only if row_height > font_size + padding_top + padding_bottom

B<Value:> can be any whole positive number
B<Default:> font_size + padding_top + padding_bottom
    
    row_height => 24
 
=item B<new_page_func> - CODE reference to a function that returns a PDF::API2::Page instance.

If used the parameter 'new_page_func' must be a function reference which when executed will create a new page and will return the object back to the module.
For example you can use it to put Page Title, Page Frame, Page Numbers and other staff that you need.
Also if you need some different type of paper size and orientation than the default A4-Portrait for example B2-Landscape you can use this function ref to set it up for you. For more info about creating pages refer to PDF::API2 PAGE METHODS Section.
Don't forget that your function must return a page object created with PDF::API2 page() method.

    new_page_func  => $code_ref
    
=item B<header_props> - HASH reference to specific settings for the Header row of the table. See section L</Header Row Properties> below
    
    header_props => $hdr_props

=item B<column_props> - HASH reference to specific settings for each column of the table. See section L</Column Properties> below

    column_props => $col_props

=item B<cell_props> - HASH reference to specific settings for each column of the table. See section L</Cell Properties> below
    
    cell_props => $cel_props

=back

=head4 Header Row Properties

If the 'header_props' parameter is used, it should be a hashref. Passing an empty HASH will trigger a header row initialised with Default values.
There is no 'data' variable for the content, because the module asumes that first table row will become the header row. It will copy this row and put it on every new page if 'repeat' param is set.

=over

=item B<font> - instance of PDF::API2::Resource::Font defining the fontf to be used in the header row

B<Value:> can be any PDF::API2::Resource::* type of font
B<Default:> 'font' of the table. See table parameter 'font' for more details.

=item B<font_size> - Font size of the header row

B<Value:> can be any positive number
B<Default:> 'font_size' of the table + 2  

=item B<font_color> - Font color of the header row

B<Value:> Color specifier as 'name' or 'HEX'
B<Default:> '#000066'

=item B<bg_color> - Background color of the header row

B<Value:> Color specifier as 'name' or 'HEX'
B<Default:> #FFFFAA

=item B<repeat> - Flag showing if header row should be repeated on every new page

B<Value:> 0,1   1-Yes/True, 0-No/False 
B<Default:> 0

=item B<justify> - Alignment of text in the header row.

B<Value:> One of 'left', 'right', 'center'
B<Default:> Same as column alignment (or 'left' if undefined)

    my $hdr_props = 
    {
        font       => $pdf->corefont("Helvetica", -encoding => "utf8"),
        font_size  => 18,
        font_color => '#004444',
        bg_color   => 'yellow', 
        repeat     => 1,    
        justify    => 'center'
    };

=back

=head4 Column Properties

If the 'column_props' parameter is used, it should be an arrayref of hashrefs, 
with one hashref for each column of the table. The columns are counted from left to right so the hash reference at $col_props[0] will hold properties for the first column from left to right. 
If you DO NOT want to give properties for a column but to give for another just insert and empty hash reference into the array for the column that you want to skip. This will cause the counting to proceed as expected and the properties to be applyed at the right columns.

Each hashref can contain any of the keys shown below:

=over

=item B<min_w> - Minimum width of this column. Auto calculation will try its best to honour this param but aplying it is NOT guaranteed.

B<Value:> can be any whole number satisfying 0 < min_w < w
B<Default:> Auto calculated

=item B<max_w> - Maximum width of this column. Auto calculation will try its best to honour this param but aplying it is NOT guaranteed.

B<Value:> can be any whole number satisfying 0 < max_w < w
B<Default:> Auto calculated

=item B<font> - instance of PDF::API2::Resource::Font defining the fontf to be used in this column

B<Value:> can be any PDF::API2::Resource::* type of font
B<Default:> 'font' of the table. See table parameter 'font' for more details.

=item B<font_size> - Font size of this column

B<Value:> can be any positive number
B<Default:> 'font_size' of the table.

=item B<font_color> - Font color of this column

B<Value:> Color specifier as 'name' or 'HEX'
B<Default:> 'font_color' of the table.

=item B<background_color> - Background color of this column

B<Value:> Color specifier as 'name' or 'HEX'
B<Default:> undef

=item B<justify> - Alignment of text in this column

B<Value:> One of 'left', 'right', 'center'
B<Default:> 'left'

Example:

    my $col_props = [
        {},# This is an empty hash so the next one will hold the properties for the second column from left to right.
        {
            min_w => 100,       # Minimum column width of 100.
            max_w => 150,       # Maximum column width of 150 .
            justify => 'right', # Right text alignment
            font => $pdf->corefont("Helvetica", -encoding => "latin1"),
            font_size => 10,
            font_color=> 'blue',
            background_color => '#FFFF00',
        },
        # etc.
    ];

=back

NOTE: If 'min_w' and/or 'max_w' parameter is used in 'col_props', have in mind that it may be overriden by the calculated minimum/maximum cell witdh so that table can be created.
When this happens a warning will be issued with some advises what can be done.
In cases of a conflict between column formatting and odd/even row formatting, 'col_props' will override odd/even.

=head4 Cell Properties

If the 'cell_props' parameter is used, it should be an arrayref with arrays of hashrefs
(of the same dimension as the data array) with one hashref for each cell of the table.

Each hashref can contain any of the keys shown below:

=over

=item B<font> - instance of PDF::API2::Resource::Font defining the fontf to be used in this cell

B<Value:> can be any PDF::API2::Resource::* type of font
B<Default:> 'font' of the table. See table parameter 'font' for more details.

=item B<font_size> - Font size of this cell

B<Value:> can be any positive number
B<Default:> 'font_size' of the table.

=item B<font_color> - Font color of this cell

B<Value:> Color specifier as 'name' or 'HEX'
B<Default:> 'font_color' of the table.

=item B<background_color> - Background color of this cell

B<Value:> Color specifier as 'name' or 'HEX'
B<Default:> undef

=item B<justify> - Alignment of text in this cell

B<Value:> One of 'left', 'right', 'center'
B<Default:> 'left'

Example:

    my $cell_props = [
        [ #This array is for the first row. If header_props is defined it will overwrite these settings.
            {    #Row 1 cell 1
                background_color => '#AAAA00',
                font_color       => 'yellow',
            },

            # etc.
        ],
        [#Row 2
            {    #Row 2 cell 1
                background_color => '#CCCC00',
                font_color       => 'blue',
            },
            {    #Row 2 cell 2
                background_color => '#BBBB00',
                font_color       => 'red',
            },
            # etc.
        ],
        # etc.
    ];

    OR
    
    my $cell_props = [];
    $cell_props->[1][0] = {
        #Row 2 cell 1
        background_color => '#CCCC00',
        font_color       => 'blue',
    };

=back
    
NOTE: In case of a conflict between column, odd/even and cell formating, cell formating will overwrite the other two.
In case of a conflict between header row and cell formating, header formating will override cell.

=head2 text_block()

    my ($width_of_last_line, $ypos_of_last_line, $left_over_text) = text_block( $txt, $data, %settings)

=over

=item Description

Utility method to create a block of text. The block may contain multiple paragraphs.
It is mainly used internaly but you can use it from outside for placing formated text anywhere on the sheet.

NOTE: This method will NOT add more pages to the pdf instance if the space is not enough to place the string inside the block.
Leftover text will be returned and has to be handled by the caller - i.e. add a new page and a new block with the leftover.

=item Parameters

    $txt  - a PDF::API2::Page::Text instance representing the text tool
    $data - a string that will be placed inside the block
    %settings - HASH with geometry and formatting parameters.
     
=item Reuturns

The return value is a 3 items list where 

    $width_of_last_line - Width of last line in the block
    $final_y - The Y coordinate of the block bottom so that additional content can be added after it
    $left_over_text - Text that was did not fit in the provided box geometry.
    
=item Example

    # PDF::API2 objects
    my $page = $pdf->page;
    my $txt  = $page->text;

    my %settings = (
        x => 10,
        y => 570,
        w => 220,
        h => 180
        
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
    
    my ( $width_of_last_line, $final_y, $left_over_text ) = $pdftable->text_block( $txt, $data, %settings );
 
=back

=head1 VERSION

0.9.7

=head1 AUTHOR

Daemmon Hughes

=head1 DEVELOPMENT

Further development since Ver: 0.02 - Desislav Kamenov

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Daemmon Hughes, portions Copyright 2004 Stone
Environmental Inc. (www.stone-env.com) All Rights Reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=head1 PLUGS

=over 

=item by Daemmon Hughes

Much of the work on this module was sponsered by
Stone Environmental Inc. (www.stone-env.com).

The text_block() method is a slightly modified copy of the one from
Rick Measham's PDF::API2 L<tutorial|http://rick.measham.id.au/pdf-api2>.

=item by Desislav Kamenov (@deskata on Twitter)

The development of this module was supported by SEEBURGER AG (www.seeburger.com) till year 2007

Thanks to my friends Krasimir Berov and Alex Kantchev for helpful tips and QA during development of versions 0.9.0 to 0.9.5

Thanks to all GitHub contributors!

=back

=head1 CONTRIBUTION

Hey PDF::Table is on GitHub. You are more than welcome to contribute!

https://github.com/kamenov/PDF-Table

=head1 SEE ALSO

L<PDF::API2>

=cut

