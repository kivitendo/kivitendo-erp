#!/usr/bin/perl -w

use strict;
use Pod::Usage;
use List::Util qw(reduce);
use List::MoreUtils qw(zip);

use constant DEBUG => 0;

unless ( caller(0) ) {
  pod2usage(2) unless @ARGV;
  migrate_file(@ARGV);
};

sub migrate_file {
  my $file = shift or return;

  my $contents = do { local( @ARGV, $/ ) = $file ; <> }
    or die "cannot read file";

  my %substitutions = (
    "<translate>"  => "[% '",
    "</translate>" => "' | \$T8 %]",
  );

  my $last_match = '';
  my $num_matches;
  my $in_template;
  my $inline_counter = 0;

  # now replace <translate> with [% '
  # and </translate> with ' | $T8 %]
  while ($contents =~ m# ( < /? translate> | \[% | %\] ) #xg) {
    my $match  = $1;
    my $pos    = pos $contents;

    if ($match eq '[%') {
      $in_template = 1;
      DEBUG && warn "entering [% block %] at pos $pos";
      next;
    }
    if ($match eq '%]') {
      $in_template = 0;
      DEBUG && warn "leaving [% block %] at pos $pos";
      next;
    }

    if ($in_template) {
      $inline_counter++ if $match eq '<translate>';
      next;
    }

    DEBUG && warn "found token $match at pos $pos";

    my $sub_by = $substitutions{$match};

    unless ($sub_by) {
      DEBUG && warn "found token $& but got no substitute";
      next;
    }

    die "unbalanced tokens - two times '$match' in file $file"
      if $last_match eq $match;

    $last_match = $match;
    $num_matches++;

    # alter string. substr is faster than s/// for strings of this size.
    substr $contents, $-[0], $+[0] - $-[0], $sub_by;

    # set match pos for m//g matching on the altered string.
    pos $contents = $-[0] + length $sub_by;
  }

  warn "found $inline_counter occurances of inline translates in file $file $/"
    if $inline_counter;

  exit 0 unless $num_matches;

  die "unbalanced tokens in file $file" if $num_matches % 2;

  if ($contents !~ m/\[%-? USE T8 %\]/) {
    $contents = "[%- USE T8 %]$/" . $contents;
  }

  # all fine? spew back

  do {
    open my $fh, ">$file" or die "can't write $file $!";
    print $fh $contents;
  };
}

1;

__END__

=head1 NAME

migrate_template_to_t8.pl - helper script to migrate templates to T8 module

=head1 SYNOPSIS

  # single:
  scripts/migrate_template_to_t8.pl <file>

  # bash:
  for file in `find templates | grep master\.html`;
    do scripts/migrate_template_to_t8.pl $file;
  done;

  # as a lib:
  require "scripts/migrate_template_to_t8.pl";
  migrate_file($file);

=head1 DESCRIPTION

This script will do the following actions in a template file

=over 8

=item 1.

Change every occurance of C<<< <translate>Text</translate> >>> to C<<< [%
'Text' | $T8 %] >>>

=item 2.

Add [%- USE T8 %] at the top if something needs to be translated

=back

Note! This script is written to help with the process of migrating old
templates. It is assumed that anyone working on Lx-Office is working with a
version control system. This script will change your files. You have been
warned.

Due to the nature of the previous locale system, it is not easily possible to
migrate translates in other template blocks. As of this writing this is used in
about 20 occurances throughout the code. If such a construct is found, a
warning will be generated. lib uses of this will have to trap the warning.

=head1 DIAGNOSIS

=head2 found I<NUM> occurances of inline translates in file I<FILE>

If a processed file has <translate> blocks in template blocks, these will be
ignored.  This warning is thrown at the end of processing.

=head2 unbalanced tokens in file I<FILE>

The script could not resolve pairs of <translate> </translate>s. The file will
not be changed in this case.

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
