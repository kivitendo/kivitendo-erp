package SL::BackgroundJob::ShopPartMassCreate;

use strict;

use parent qw(SL::BackgroundJob::Base);

use List::Util qw(first);
use File::MimeInfo::Magic; # for mimetype
use File::Slurp; # for read_file

use SL::Shop;
use SL::DB::Part;
use SL::DB::ShopPart;
use SL::DB::File;
use SL::CVar;
use SL::File;
use SL::LXDebug;

sub recurse_categories {
  my ($categories, $categories_by_names) = @_;
  foreach my $category (@{ $categories }) {
    ${ $categories_by_names }{$category->{name}} = $category->{id};
    recurse_categories($category->{children}, $categories_by_names);
  }
}

sub get_shop_part {
  my ($part_id, $shop_id) = @_;
  my $exists = SL::DB::Manager::ShopPart->find_by( part_id => $part_id, shop_id => $shop_id );
  if ($exists) {
    return $exists;
  }
  return SL::DB::ShopPart->new( part_id => $part_id, shop_id => $shop_id );
}

sub get_shop_categories {
  my ($cvar_categories, $categories_by_names) = @_;
  # split on the pipe character
  my @categories_names = split(/\|/, $cvar_categories);

  my @shop_categories;
  foreach my $category_name (@categories_names) {
    # if the category exists in the shop
    if (exists $categories_by_names->{$category_name}) {
      push @shop_categories, [
        $categories_by_names->{$category_name},
        $category_name
      ];
    }
  }
  return \@shop_categories;
}

sub sanitize_filename {
    my ($filename) = @_;
    $filename =~ s/\W/_/g;
    return $filename;
}

sub _warn {
  my ($messages, $message) = @_;
  $main::lxdebug->message(LXDebug::WARN(), $message);
  push @$messages, $message;
}

sub run {
  my ($self, $db_obj)     = @_;
  my $data       = $db_obj->data_as_hash;

  # get parameters
  my $shop_id = $data->{shop_id} || 1;
  my $images_import_path = $data->{images_import_path} || 'shopimages/product/';
  my $cvar_categories = $data->{cvar_categories} || 'vm_product_categories';

  my @messages;

  # initialize shop
  my $shop_config = SL::DB::Manager::Shop->get_first( query => [ id => $shop_id ] );
  my $shop = SL::Shop->new( config => $shop_config );

  # get the categories from the shop
  my $connect = $shop->check_connectivity;
  if (!$connect->{success}) {
    return 'Error: could not connect to shop';
  }
  my $categories_shopdata = $shop->connector->get_categories();
  if (!$categories_shopdata) {
    return 'Error: could not get categories from shop';
  }

  # generate a hash of the category names and their ids
  my %categories_by_names;
  recurse_categories($categories_shopdata, \%categories_by_names);

  # get all the parts from the database, that are marked as shop parts
  my $parts = SL::DB::Manager::Part->get_all(query => [ shop => 1 ]);

  # for every part
  for my $part (@{ $parts }) {

    # check if shop part already exists
    my $shop_part = get_shop_part($part->id, $shop_id);

    # get the custom variables from the part
    my $cvars = CVar->get_custom_variables(module => 'IC', trans_id => $part->id);
    my $cvar_categories = first { $_->{name} eq $cvar_categories } @{ $cvars };

    # assign categories
    my $shop_categories = get_shop_categories($cvar_categories->{value}, \%categories_by_names);

    $shop_part->assign_attributes(
      shop_description => '',
      front_page       => '',
      active           => 1,
      shop_category    => $shop_categories,
      active_price_source => 'master_data/sellprice',
      metatag_keywords => '',
      metatag_description => '',
      metatag_title => '',
    );

    $shop_part->save;
    $main::lxdebug->message(LXDebug->DEBUG1(), 'Shop part saved: ' . $shop_part->id);

    if (!$shop_part->id) {
      _warn(\@messages, 'Warning: shop part not saved, part id: ' . $part->id . ' part number: ' . $part->partnumber);
      next;
    }

    # handle the images,
    # the file names are under part->image

    if (!$part->image) {
      # go to next part if no images are found
      next;
    }

    # get existing images from shop part
    my $image_files = SL::DB::Manager::File->get_all( where => [ object_id => $part->id, object_type => 'shop_image' ] );

    my %images_by_names = map { $_->{file_name} => $_ } @{ $image_files };

    for my $image_name (split '\|', $part->image) {

      my $fileobj;
      if (exists $images_by_names{$image_name}) {
        # I tried updating or deleting the file, but that didn't work
        # so for now we'll just skip the image if an image with the same name already exists
        # (atm there doesn't seem to be a mechanism in place to update or delete the files properly)
        next;
      }

      my $image_path = $images_import_path . $image_name;

      # uses File::MimeInfo::Magic
      my $mime_type = mimetype($image_path);

      # check if the file exists
      if (! -e $image_path) {
        _warn(\@messages, 'Warning: image file not found for part: ' . $part->id . ' file: ' . $image_name);
        next;
      }
      # read file data into memory
      my $file_data = File::Slurp::read_file($image_path);

      $fileobj = SL::File->save(
        object_id        => $part->id,
        object_type      => 'shop_image',
        mime_type        => $mime_type,
        source           => 'uploaded',
        file_type        => 'image',
        file_name        => $image_name,
        title            => sanitize_filename(substr($part->description, 0, 45)),
        description      => '',
        file_contents    => $file_data,
        file_path        => $image_path,
      );
      if (!$fileobj) {
        _warn(\@messages, 'Warning: file not saved for part: ' . $part->id . ' file: ' . $image_name);
      }
    }
  }

  if (@messages) {
    return join("\n", @messages);
  }
  return 'Shop parts created successfully';
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::ShopPartMassCreate - Background job to create shop
parts for all parts in the database that are marked as shop parts.

=head1 SYNOPSIS

This background job provides the basic functionality to create shop parts for
all parts in the database that are marked as shop parts.

It can also import images from a directory and assign them to the respective
shop parts. See configuration below.

It also assigns categories to the shop parts based on a custom variable of the
part.

The script may need individual adjustments to fit your specific use case.

=head1 CONFIGURATION

Accepts the following parameters:

=over 4

=item C<shop_id>

The id of the shop to create the shop parts in, defaults to 1

=item C<images_import_path>

The path to the images to import, defaults to 'shopimages/product/'

The file names of the images should be present in the 'image' field of the part,
in the following format:
  image1.jpg|image2.png|image3.gif

The images themselves should be present in the images_import_path.

=item C<cvar_categories>

The name of the custom variable that contains the categories, defaults to 'vm_product_categories'

Expects the Categories to be set in the custom variable of the part in the following format:
  Category1|Category2|Category3

Categories should be present in the shop under the same names.

=back

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@revamp-it.chE<gt>

=cut
