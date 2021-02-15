package SL::Controller::Helper::ThumbnailCreator;

use strict;

use SL::Locale::String qw(t8);
use Carp;
use GD;
use Image::Info;
use File::MimeInfo::Magic;
use List::MoreUtils qw(apply);
use List::Util qw(max);
use Rose::DB::Object::Util;

require Exporter;
our @ISA      = qw(Exporter);
our @EXPORT   = qw(file_create_thumbnail file_update_thumbnail file_probe_type file_probe_image_type file_update_type_and_dimensions);

our %supported_mime_types = (
  'image/gif'  => { extension => 'gif', convert_to_png => 1, },
  'image/png'  => { extension => 'png' },
  'image/jpeg' => { extension => 'jpg' },
  'image/tiff' => { extension => 'tif'},
);

sub file_create_thumbnail {
  my ($thumb) = @_;
  croak "No picture set yet" if !$thumb->{content};
  my $image            = GD::Image->new($thumb->{content});
  my ($width, $height) = $image->getBounds;
  my $max_dim          = 64;
  my $curr_max         = max $width, $height, 1;
  my $factor           = $curr_max <= $max_dim ? 1 : $curr_max / $max_dim;
  my $new_width        = int($width  / $factor + 0.5);
  my $new_height       = int($height / $factor + 0.5);
  my $thumbnail        = GD::Image->new($new_width, $new_height);

  $thumbnail->copyResized($image, 0, 0, 0, 0, $new_width, $new_height, $width, $height);

  $thumb->{thumbnail_img_content} = $thumbnail->png;
  $thumb->{thumbnail_img_content_type} = "image/png";
  $thumb->{thumbnail_img_width} = $new_width;
  $thumb->{thumbnail_img_height} = $new_height;
  return $thumb;

}

sub file_update_thumbnail {
  my ($self) = @_;

  return 1 if !$self->file_content || !$self->file_content_type || !Rose::DB::Object::Util::get_column_value_modified($self, 'file_content');
  $self->file_create_thumbnail;
  return 1;
}

sub file_probe_image_type {
  my ($self, $mime_type, $basefile) = @_;

  if ( !$supported_mime_types{ $mime_type } ) {
    $self->js->flash('error',t8('file \'#1\' has unsupported image type \'#2\' (supported types: #3)',
                                $basefile, $mime_type, join(' ', sort keys %supported_mime_types)));
    return 1;
  }
  return 0;
}

sub file_probe_type {
  my ($content) = @_;
  return (t8("No file uploaded yet")) if !$content;
  my $info = Image::Info::image_info(\$content);
  if (!$info || $info->{error} || !$info->{file_media_type} || !$supported_mime_types{ $info->{file_media_type} }) {
    $::lxdebug->warn("Image::Info error: " . $info->{error}) if $info && $info->{error};
    return (t8('Unsupported image type (supported types: #1)', join(' ', sort keys %supported_mime_types)));
  }

  my $thumbnail;
  $thumbnail->{file_content_type} = $info->{file_media_type};
  $thumbnail->{file_image_width} = $info->{width};
  $thumbnail->{file_image_height} = $info->{height};
  $thumbnail->{content} = $content;

  $thumbnail = &file_create_thumbnail($thumbnail);

  return $thumbnail;
}

sub file_update_type_and_dimensions {
  my ($self) = @_;

  return () if !$self->file_content;
  return () if $self->file_content_type && $self->files_img_width && $self->files_img_height && !Rose::DB::Object::Util::get_column_value_modified($self, 'file_content');

  my @errors = $self->file_probe_type;
  return @errors if @errors;

  my $info = $supported_mime_types{ $self->file_content_type };
  if ($info->{convert_to_png}) {
    $self->file_content(GD::Image->new($self->file_content)->png);
    $self->file_content_type('image/png');
    $self->filename(apply { s/\.[^\.]+$//;  $_ .= '.png'; } $self->filename);
  }
  return ();
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::ThumbnailCreator - Helper for Fileuploads

=head1 SYNOPSIS

use SL::Controller::Helper::ThumbnailCreator;

=head1 AUTHOR

Werner Hahn E<lt>wh@futureworldsearch.netE<gt>
