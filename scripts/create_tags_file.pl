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

my $dir = IO::Dir->new("SL/");

my @files = grep {/\.pm$/} $dir->read();

@files = grep { s{^}{SL\/}gxms } @files;

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
