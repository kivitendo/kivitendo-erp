#!/usr/bin/perl

use strict;
use Getopt::Long;
use File::Basename;

my $css_file   = 'generated.css';
my $image_file = 'generated.png';
my $class_for_map = 'icon';

my $convert_bin  = 'convert';
my $identify_bin = 'identify';

GetOptions(
  'css-out=s'    => \$css_file,
  'image-out=s'  => \$image_file,
  'icon-class=s' => \$class_for_map,
);

my @files = @ARGV;
my @images;

# read files

for my $filename (sort @files) {
   my $image = `$identify_bin $filename`;
   if (!defined $image) {
     warn "warning: could not identify image '$filename'. skipping...";
     next;
   }
  $image =~ /^(?<filename>\S+) \s (?<type>\S+) \s (?<width>\d+) x (?<height>\d+)/x;
  push @images, {
    filename => $filename,
    type     => $+{type},
    width    => $+{width},
    height   => $+{height},
  };
}

# make target layout
# for simplification thi will check if all the  images have the same dimensions
# and croak if not
my $first_height = $images[0]->{height};
my $first_width  = $images[0]->{width};

use Data::Dumper;

for my $img (@images) {
  die 'heights are not equal' if $first_height != $img->{height};
  die 'widths are not equal'  if $first_width  != $img->{width};
}

# all equal? nice.
# we'll be lazy and just put them all together left-to-right
my $new_height = $first_height;
my $new_width  = $first_width * @images;

# now copy them all together, and keep a referende to;

my $convert_string = "$convert_bin ";

my $h_offset = 0;
for (@images) {
  $_->{h_offset} = $h_offset;
  $_->{v_offset} = 0;
  $convert_string .= ' +append ' . $_->{filename};
} continue {
  $h_offset += $_->{width};
}

$convert_string .= " -background none +append $image_file";

# now write that png...
system($convert_string);

# make css file
{
  open my $file, ">", $css_file or die "can't write too $css_file";
  print $file ".$class_for_map { background: url(../$image_file) ${first_width}px 0px no-repeat; padding: 0; width: ${first_width}px; height: ${first_height}px; }\n";

  for (@images) {
    my $name = fileparse($_->{filename}, ".png");

    # the full grammar for valid css class names is completely bonkers (to put it mildly).
    # so instead of trying to punch filenames into those class names, we'll
    # just reduce them to a nice minimal set of lower case /[a-z0-9_-]*/
    $name = lc $name;
    $name =~ s/[^a-z0-9_-]/-/g;
    print $file ".$class_for_map.$name { background-position: -$_->{h_offset}px 0px; }\n";
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

image_maps - generates image maps for css sprites from images in a directory

=head1 SYNOPSIS

  scripts/image_maps.pl \
    --out-css=css/icons_16.css \
    --out-image= image/maps/icons_16.png \
    image/icons/16x16/*

=head1 DESCRIPTION

=head1 OPTIONS

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut


