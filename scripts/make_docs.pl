#!/usr/bin/perl

use strict;

use Pod::Html;
use File::Find;
use FindBin;

chdir($FindBin::Bin . '/..');

my $doc_path     = "doc/online";
#my $pod2html_bin = `which pod2html` or die 'cannot find pod2html on your system';

find({no_chdir => 1, wanted => sub {
  next unless -f;
  next unless /\.pod$/;
  print "processing $_,$/";
  my $html_file = $_;
  $html_file =~ s/\.pod$/.html/;
  pod2html(
#    $pod2html_bin,
    '--noindex',
    '--css=../../../css/lx-office-erp.css',
    "--infile=$_",
    "--outfile=$html_file",
  );
}}, $doc_path);

1;
