# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::ShopPart;

use strict;

use SL::DBUtils;
use SL::DB::MetaSetup::ShopPart;
use SL::DB::Manager::ShopPart;
use SL::DB::Helper::AttrHTML;
#use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;
__PACKAGE__->attr_html('shop_description');

sub get_tax_and_price {
  my ( $self ) = @_;

  require SL::DB::Part;
  my $tax_n_price;
  my ( $price_src_str, $price_src_id ) = split(/\//,$self->active_price_source);
  my $price;
  my $part;
  if ($price_src_str eq "master_data") {
    $part = SL::DB::Manager::Part->find_by( id => $self->part_id );
    $price = $part->$price_src_id;
  }else{
    $part = SL::DB::Manager::Part->find_by( id => $self->part_id );
    $price =  $part->prices->[0]->price;
  }

  my $taxrate;
  my $dbh  = $::form->get_standard_dbh();
  my $b_id = $part->buchungsgruppen_id;
  my $t_id = $self->shop->taxzone_id;

  my $sql_str = "SELECT a.rate AS taxrate from tax a
  WHERE a.taxkey = (SELECT b.taxkey_id
  FROM chart b LEFT JOIN taxzone_charts c ON b.id = c.income_accno_id
  WHERE c.taxzone_id = $t_id
  AND c.buchungsgruppen_id = $b_id)";

  my $rate = selectall_hashref_query($::form, $dbh, $sql_str);
  $taxrate = @$rate[0]->{taxrate}*100;

  $tax_n_price->{price} = $price;
  $tax_n_price->{tax}   = $taxrate;
  return $tax_n_price;
}

sub get_images {
  my ( $self ) = @_;

  require SL::DB::ShopImage;
  my $images = SL::DB::Manager::ShopImage->get_all( where => [ 'files.object_id' => $self->{part_id}, ], with_objects => 'file', sort_by => 'position' );
  my @upload_img = ();
  foreach my $img (@{ $images }) {
    my $file               = SL::File->get(id => $img->file->id );
    my ($path, $extension) = (split /\./, $file->file_name);
    my $content            = File::Slurp::read_file($file->get_file);
    my $temp ={ ( link        => 'data:' . $file->mime_type . ';base64,' . MIME::Base64::encode($content, ""), #$content, # MIME::Base64::encode($content),
                  description => $img->file->title,
                  position    => $img->position,
                  extension   => $extension,
                  path        => $path,
                      )}    ;
    push( @upload_img, $temp);
  }
  return @upload_img;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::DB::ShopPart - Model for the 'shop_parts' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 METHODS

=over 4

=item C<get_tax_and_price>

Returns the price and the taxrate for an shop_article

=item C<get_images>

Returns the images for the shop_article

=back

=head1 TODO

Prices, pricesources, pricerules could be implemented

=head1 AUTHORS

Werner Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
