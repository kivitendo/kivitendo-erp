#!/usr/bin/perl
#
########################################################
#
# This script creates a 'tags' file in the style of ctags
# out of the SL/ modules.
# Tags file is usable in some editors (vim, joe, emacs, ...). 
# See your editors documentation for more information.
#
# (c) Udo Spallek, Aachen
# Licenced under GNU/GPL.
#
########################################################

use Perl::Tags;
use IO::Dir;
use Data::Dumper;

use strict;
use warnings FATAL =>'all';
use diagnostics;

use Getopt::Long;

my $parse_SL         = 1;
my $parse_binmozilla = 0;
GetOptions("sl!"         => \$parse_SL,
           "pm!"         => \$parse_SL,
           "binmozilla!" => \$parse_binmozilla,
           "pl!"         => \$parse_binmozilla,
           );

my @files = ();
push @files, grep { /\.pm$/ && s{^}{SL/}gxms         } IO::Dir->new("SL/")->read()          if $parse_SL;
push @files, grep { /\.pl$/ && s{^}{bin/mozilla/}gxms} IO::Dir->new("bin/mozilla/")->read() if $parse_binmozilla;

#map { s{^}{SL\/}gxms } @files;

#print Dumper(@files);

#__END__
my $naive_tagger = Perl::Tags::Naive->new( max_level=>1 );
$naive_tagger->process(
         files => [@files],
         refresh=>1 
);

my $tagsfile="tags";

# of course, it may not even output, for example, if there's nothing new to process
$naive_tagger->output( outfile => $tagsfile );


1;
