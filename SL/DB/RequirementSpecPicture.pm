package SL::DB::RequirementSpecPicture;

use strict;

use Carp;
use GD;
use Image::Info;
use List::MoreUtils qw(apply);
use List::Util qw(max);
use Rose::DB::Object::Util;
use SL::DB::MetaSetup::RequirementSpecPicture;
use SL::DB::Manager::RequirementSpecPicture;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(requirement_spec_id text_block_id)]);

__PACKAGE__->before_save(\&_create_picture_number);
__PACKAGE__->before_save(\&_update_thumbnail);

our %supported_mime_types = (
  'image/gif'  => { extension => 'gif', convert_to_png => 1, },
  'image/png'  => { extension => 'png' },
  'image/jpeg' => { extension => 'jpg' },
);

sub _create_picture_number {
  my ($self) = @_;

  return 1 if  $self->number;
  return 0 if !$self->requirement_spec_id;

  my $next_number = $self->requirement_spec->previous_picture_number + 1;

  $self->requirement_spec->update_attributes(previous_picture_number => $next_number) || return 0;

  $self->number($next_number);

  return 1;
}

sub _update_thumbnail {
  my ($self) = @_;

  return 1 if !$self->picture_content || !$self->picture_content_type || !Rose::DB::Object::Util::get_column_value_modified($self, 'picture_content');
  $self->create_thumbnail;
  return 1;
}

sub create_thumbnail {
  my ($self) = @_;

  croak "No picture set yet" if !$self->picture_content;

  my $image            = GD::Image->new($self->picture_content);
  my ($width, $height) = $image->getBounds;
  my $max_dim          = 64;
  my $curr_max         = max $width, $height, 1;
  my $factor           = $curr_max <= $max_dim ? 1 : $curr_max / $max_dim;
  my $new_width        = int($width  / $factor + 0.5);
  my $new_height       = int($height / $factor + 0.5);
  my $thumbnail        = GD::Image->new($new_width, $new_height);

  $thumbnail->copyResized($image, 0, 0, 0, 0, $new_width, $new_height, $width, $height);

  $self->thumbnail_content($thumbnail->png);
  $self->thumbnail_content_type('image/png');
  $self->thumbnail_width($new_width);
  $self->thumbnail_height($new_height);

  return 1;
}

sub update_type_and_dimensions {
  my ($self) = @_;

  return () if !$self->picture_content;
  return () if $self->picture_content_type && $self->picture_width && $self->picture_height && !Rose::DB::Object::Util::get_column_value_modified($self, 'picture_content');

  my @errors = $self->probe_type;
  return @errors if @errors;

  my $info = $supported_mime_types{ $self->picture_content_type };
  if ($info->{convert_to_png}) {
    $self->picture_content(GD::Image->new($self->picture_content)->png);
    $self->picture_content_type('image/png');
    $self->picture_file_name(apply { s/\.[^\.]+$//;  $_ .= '.png'; } $self->picture_file_name);
  }

  return ();
}

sub probe_type {
  my ($self) = @_;

  return (t8("No picture uploaded yet")) if !$self->picture_content;

  my $info = Image::Info::image_info(\$self->{picture_content});
  if (!$info || $info->{error} || !$info->{file_media_type} || !$supported_mime_types{ $info->{file_media_type} }) {
    $::lxdebug->warn("Image::Info error: " . $info->{error}) if $info && $info->{error};
    return (t8('Unsupported image type (supported types: #1)', join(' ', sort keys %supported_mime_types)));
  }

  $self->picture_content_type($info->{file_media_type});
  $self->picture_width($info->{width});
  $self->picture_height($info->{height});
  $self->picture_mtime(DateTime->now_local);

  $self->create_thumbnail;

  return ();
}

sub get_default_file_name_extension {
  my ($self) = @_;

  my $info = $supported_mime_types{ $self->picture_content_type } || croak("Unsupported content type " . $self->picture_content_type);
  return $info->{extension};
}

sub validate {
  my ($self) = @_;

  my @errors;

  push @errors, t8('The file name is missing') if !$self->picture_file_name;

  if (!length($self->picture_content // '')) {
    push @errors, t8('No picture has been uploaded');

  } else {
    push @errors, $self->update_type_and_dimensions;
  }

  return @errors;
}

1;
