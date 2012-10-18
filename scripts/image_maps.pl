#!/usr/bin/perl

use strict;
use GD;
use Getopt::Long;
use File::Basename;


my $css_file   = 'generated.css';
my $image_file = 'generated.png';
my $class_for_map = 'icon';

GetOptions(
  'css-out=s'    => \$css_file,
  'image-out=s'  => \$image_file,
  'icon-class=s' => \$class_for_map,
);

my @files = @ARGV;
my @gd_images;

GD::Image->trueColor(1);

# read files

for my $filename (@files) {
  my $image = GD::Image->newFromPng($filename);
   if (!defined $image) {
     warn "warning: could not load image '$filename'. skpping...";
     next;
   }
  push @gd_images, {
    gd       => $image,
    filename => $filename,
  };
}

# make target layout
# for simplification thi will check if all the  images have the same dimensions
# and croak if not
my $first_height = $gd_images[0]->{gd}->height;
my $first_width  = $gd_images[0]->{gd}->width;

use Data::Dumper;

for my $img (@gd_images) {
  die 'heights are not equal' if $first_height != $img->{gd}->height;
  die 'widths are not equal'  if $first_width  != $img->{gd}->width;
}

# all equal? nice.
# we'll be lazy and just put them all together left-to-right
my $new_height = $first_height;
my $new_width  = $first_width * @gd_images;

my $new_image = GD::Image->new($new_width, $new_height, 1);
# now copy them all together, and keep a referende to;

$new_image->saveAlpha(1);
$new_image->alphaBlending(0);

my $h_offset = 0;
for (@gd_images) {
  $_->{h_offset} = $h_offset;
  $_->{v_offset} = 0;
  $new_image->copy($_->{gd}, $_->{h_offset}, $_->{v_offset}, 0, 0, $_->{gd}->width, $_->{gd}->height);
} continue {
  $h_offset += $_->{gd}->width;
}

# now write that png...
{
  open my $file, '>:raw', $image_file or die "can't write to $image_file";
  print $file $new_image->png;
}

# make css file
{
  open my $file, ">", $css_file or die "can't write too $css_file";
  print $file ".$class_for_map { background: url(../$image_file) ${first_width}px 0px no-repeat; padding: 0; width: ${first_width}px; height: ${first_height}px; }\n";

  for (@gd_images) {
    my $name = fileparse($_->{filename}, ".png");
    $name =~ s/ /-/g;
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


