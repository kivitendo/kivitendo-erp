#!/usr/bin/perl

# Script for test driving SL::XMLInvoice. Use on extracted XML invoice payloads
# (faktur-x.xml) from ZUGFeRD invoices or XRechnung invoices. PDF extraction is
# not supported.

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');
}

use SL::XMLInvoice;

use utf8;

if ( scalar(@ARGV) == 0 )
  {
  die "usage: $0 <xml invoice file> [ ... <xml invoice file> ]\n";
  }

foreach my $xml_file ( @ARGV) {
  my $xml_data = "";

  open F, $xml_file or die "Couldn't open $xml_file for reading: $!\n";

  while (my $line = <F> ) { $xml_data .= $line; }
  close F;

  my $parser = SL::XMLInvoice->new($xml_data);

  if ( ${$parser}{'result'} != SL::XMLInvoice->RES_OK )
    {
    die "Parser creation failed: ${$parser}{'message'}\n";
    }

  foreach my $key ( keys %{$parser->metadata} )
    {
    print "$key: |" . $parser->metadata->{$key} . "|\n";
    }

  foreach my $item ( @{$parser->items} ) {
    my %line_item = %{$item};
      foreach my $field ( keys %line_item ) {
        print "  $field: |$line_item{$field}|\n";
      }
    print "\n";
  }
}
