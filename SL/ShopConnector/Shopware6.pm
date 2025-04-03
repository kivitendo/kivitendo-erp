package SL::ShopConnector::Shopware6;

use strict;

use parent qw(SL::ShopConnector::Base);

use Carp;
use Encode qw(encode);
use List::Util qw(first);
use REST::Client;
use Try::Tiny;

use SL::JSON;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(connector) ],
);

sub all_open_orders {
  my ($self) = @_;

  my $assoc = {
              'associations' => {
                'deliveries'   => {
                  'associations' => {
                    'shippingMethod' => [],
                      'shippingOrderAddress' => {
                        'associations' => {
                                            'salutation'   => [],
                                            'country'      => [],
                                            'countryState' => []
                                          }
                                                }
                                     }
                                   }, # end deliveries
                'language' => [],
                'orderCustomer' => [],
                'addresses' => {
                  'associations' => {
                                      'salutation'   => [],
                                      'countryState' => [],
                                      'country'      => []
                                    }
                                },
                'tags' => [],
                'lineItems' => {
                  'associations' => {
                    'product' => {
                      'associations' => {
                                          'tax' => []
                                        }
                                 }
                                    }
                                }, # end line items
                'salesChannel' => [],
                  'documents' => {          # currently not used
                    'associations' => {
                      'documentType' => []
                                      }
                                 },
                'transactions' => {
                  'associations' => {
                    'paymentMethod' => []
                                    }
                                  },
                'currency' => []
            }, # end associations
         'limit' => $self->config->orders_to_fetch ? $self->config->orders_to_fetch : undef,
        # 'page' => 1,
     'aggregations' => [
                            {
                              'field'      => 'billingAddressId',
                              'definition' => 'order_address',
                              'name'       => 'BillingAddress',
                              'type'       => 'entity'
                            }
                          ],
        'filter' => [
                     {
                        'value' => 'open', # open or completed (mind the past)
                        'type' => 'equals',
                        'field' => 'order.stateMachineState.technicalName'
                      }
                    ],
        'total-count-mode' => 0
      };
  return $assoc;
}

# used for get_new_orders and get_one_order
sub get_fetched_order_structure {
  my ($self) = @_;
  # set known params for the return structure
  my %fetched_order  = (
      shop_id          => $self->config->id,
      shop_description => $self->config->description,
      message          => '',
      error            => '',
      number_of_orders => 0,
    );
  return %fetched_order;
}

sub update_part {
  my ($self, $shop_part, $todo) = @_;

  #shop_part is passed as a param
  croak t8("Need a valid Shop Part for updating Part") unless ref($shop_part) eq 'SL::DB::ShopPart';
  croak t8("Invalid todo for updating Part")           unless $todo =~ m/(price|stock|price_stock|active|all)/;

  my $part = SL::DB::Part->new(id => $shop_part->part_id)->load;
  die "Shop Part but no kivi Part?" unless ref $part eq 'SL::DB::Part';

  my $tax_n_price = $shop_part->get_tax_and_price;
  my $price       = $tax_n_price->{price};
  my $taxrate     = $tax_n_price->{tax};

  # simple calc for both cases, always give sw6 the calculated gross price
  my ($net, $gross);
  if ($self->config->pricetype eq 'brutto') {
    $gross = $price;
    $net   = $price / (1 + $taxrate/100);
  } elsif ($self->config->pricetype eq 'netto') {
    $net   = $price;
    $gross = $price * (1 + $taxrate/100);
  } else { die "Invalid state for price type"; }

  my $update_p;
  $update_p->{productNumber} = $part->partnumber;
  $update_p->{name}          = _u8($part->description);
  $update_p->{description}   =   $shop_part->shop->use_part_longdescription
                               ? _u8($part->notes)
                               : _u8($shop_part->shop_description);

  $update_p->{metaTitle}       = _u8($shop_part->metatag_title)       if $shop_part->metatag_title;
  $update_p->{metaDescription} = _u8($shop_part->metatag_description) if $shop_part->metatag_description;
  $update_p->{keywords}        = _u8($shop_part->metatag_keywords)    if $shop_part->metatag_keywords;

  # locales simple check for english
  my $english = SL::DB::Manager::Language->get_first(query => [ description   => { ilike => 'Englisch' },
                                                        or => [ template_code => { ilike => 'en' } ],
                                                    ]);
  if (ref $english eq 'SL::DB::Language') {
    # add english translation for product
    # TODO (or not): No Translations for shop_part->shop_description available
    my $translation = first { $english->id == $_->language_id } @{ $part->translations };
    $update_p->{translations}->{'en-GB'}->{name}        = _u8($translation->{translation});
    $update_p->{translations}->{'en-GB'}->{description} = _u8($translation->{longdescription});
  }

  $update_p->{stock}  = $::form->round_amount($part->onhand, 0) if ($todo =~ m/(stock|all)/);
  # JSON::true JSON::false
  # These special values become JSON true and JSON false values, respectively.
  # You can also use \1 and \0 directly if you want
  $update_p->{active} = (!$part->obsolete && $part->shop) ? \1 : \0 if ($todo =~ m/(active|all)/);

  # 1. check if there is already a product
  my $product_filter = {
          'filter' => [
                        {
                          'value' => $part->partnumber,
                          'type'  => 'equals',
                          'field' => 'productNumber'
                        }
                      ]
    };
  my $ret = $self->connector->POST('api/search/product', to_json($product_filter));
  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;

  my $one_d; # maybe empty
  try {
    $one_d = from_json($ret->responseContent())->{data}->[0];
  } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };
  # edit or create if not found
  if ($one_d->{id}) {
    #update
    # we need price object structure and taxId
    $update_p->{$_} = $one_d->{$_} foreach qw(taxId price);
    if ($todo =~ m/(price|all)/) {
      $update_p->{price}->[0]->{gross} = $gross;
    }
    undef $update_p->{partNumber}; # we dont need this one
    $ret = $self->connector->PATCH('api/product/' . $one_d->{id}, to_json($update_p));
    $self->_die_on_error($part, $ret) unless (204 == $ret->responseCode());
  } else {
    # create part
    # 1. get the correct tax for this product
    my $tax_filter = {
          'filter' => [
                        {
                          'value' => $taxrate,
                          'type' => 'equals',
                          'field' => 'taxRate'
                        }
                      ]
        };
    $ret = $self->connector->POST('api/search/tax', to_json($tax_filter));
    die "Search for Tax with rate: " .  $part->partnumber . " failed: " . $ret->responseContent() unless (200 == $ret->responseCode());
    try {
      $update_p->{taxId} = from_json($ret->responseContent())->{data}->[0]->{id};
    } catch { die "Malformed JSON Data or Taxkey entry missing: $_ " . $ret->responseContent();  };

    # 2. get the correct currency for this product
    my $currency_filter = {
        'filter' => [
                      {
                        'value' => SL::DB::Default->get_default_currency,
                        'type' => 'equals',
                        'field' => 'isoCode'
                      }
                    ]
      };
    $ret = $self->connector->POST('api/search/currency', to_json($currency_filter));
    die "Search for Currency with ISO Code: " . SL::DB::Default->get_default_currency . " failed: "
      . $ret->responseContent() unless (200 == $ret->responseCode());

    try {
      $update_p->{price}->[0]->{currencyId} = from_json($ret->responseContent())->{data}->[0]->{id};
    } catch { die "Malformed JSON Data or Currency ID entry missing: $_ " . $ret->responseContent();  };

    # 3. add net and gross price and allow variants
    $update_p->{price}->[0]->{gross}  = $gross;
    $update_p->{price}->[0]->{net}    = $net;
    $update_p->{price}->[0]->{linked} = \1; # link product variants

    $ret = $self->connector->POST('api/product', to_json($update_p));
    $self->_die_on_error($part, $ret) unless (204 == $ret->responseCode());
  }

  # if there are images try to sync this with the shop_part
  try {
    $self->sync_all_images(shop_part => $shop_part, set_cover => 1, delete_orphaned => 1);
  } catch { die "Could not sync images for Part " . $part->partnumber . " Reason: $_" };

  # if there are categories try to sync this with the shop_part
  try {
    $self->sync_all_categories(shop_part => $shop_part);
  } catch { die "Could not sync Categories for Part " . $part->partnumber . " Reason: $_" };

  return 1; # no invalid response code -> success
}

sub _die_on_error {
  my ($self, $part, $ret) = @_;

  die t8('Part Description is too long for this Shopware version. It should have lower than 255 characters.')
     if $ret->responseContent() =~ m/Diese Zeichenkette ist zu lang. Sie sollte.*255 Zeichen/
     && $ret->responseContent() =~ m/description/;
  die t8('Part Metatag Title is too long for this Shopware version. It should have lower than 255 characters.')
     if $ret->responseContent() =~ m/Diese Zeichenkette ist zu lang. Sie sollte.*255 Zeichen/
     && $ret->responseContent() =~ m/metaTitle/;
  die t8('Part Metatag Description is too long for this Shopware version. It should have lower than 255 characters.')
     if $ret->responseContent() =~ m/Diese Zeichenkette ist zu lang. Sie sollte.*255 Zeichen/
     && $ret->responseContent() =~ m/metaDescription/;
  die t8("Action for part #1 failed: #2", $part->partnumber, $ret->responseContent());
};

sub sync_all_categories {
  my ($self, %params) = @_;

  my $shop_part = delete $params{shop_part};
  croak "Need a valid Shop Part for updating Images" unless ref($shop_part) eq 'SL::DB::ShopPart';

  my $partnumber = $shop_part->part->partnumber;
  die "Shop Part but no kivi Partnumber" unless $partnumber;

  my ($ret, $response_code);
  # 1 get  uuid for product
  my $product_filter = {
          'filter' => [
                        {
                          'value' => $partnumber,
                          'type'  => 'equals',
                          'field' => 'productNumber'
                        }
                      ]
    };

  $ret = $self->connector->POST('api/search/product', to_json($product_filter));
  $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;
  my ($product_id, $category_tree);
  try {
    $product_id    = from_json($ret->responseContent())->{data}->[0]->{id};
    $category_tree = from_json($ret->responseContent())->{data}->[0]->{categoryIds};
  } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };
  my $cat;
  # if the part is connected to a category at all
  if ($shop_part->shop_category) {
    foreach my $row_cat (@{ $shop_part->shop_category }) {
      $cat->{@{ $row_cat }[0]} = @{ $row_cat }[1];
    }
  }
  # delete
  foreach my $shopware_cat (@{ $category_tree }) {
    if ($cat->{$shopware_cat}) {
      # cat exists and no delete
      delete $cat->{$shopware_cat};
      next;
    }
    # cat exists and delete
    $ret = $self->connector->DELETE("api/product/$product_id/categories/$shopware_cat");
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 204;
  }
  # now add only new categories
  my $p;
  $p->{id}  = $product_id;
  $p->{categories} = ();
  foreach my $new_cat (keys %{ $cat }) {
    push @{ $p->{categories} }, {id => $new_cat};
  }
    $ret = $self->connector->PATCH("api/product/$product_id", to_json($p));
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 204;
}

sub sync_all_images {
  my ($self, %params) = @_;

  $params{set_cover}       //= 1;
  $params{delete_orphaned} //= 0;

  my $shop_part = delete $params{shop_part};
  croak "Need a valid Shop Part for updating Images" unless ref($shop_part) eq 'SL::DB::ShopPart';

  my $partnumber = $shop_part->part->partnumber;
  die "Shop Part but no kivi Partnumber" unless $partnumber;

  my @upload_img  = $shop_part->get_images(want_binary => 1);

  return unless (@upload_img); # there are no images, but delete wont work TODO extract to method

  my ($ret, $response_code);
  # 1. get part uuid and get media associations
  # 2. create or update the media entry for the filename
  # 2.1 if no media entry exists create one
  # 2.2 update file
  # 2.2 create or update media_product and set position
  # 3. optional set cover image
  # 4. optional delete images in shopware which are not in kivi

  # 1 get mediaid uuid for prodcut
  my $product_filter = {
              'associations' => {
                'media'   => []
              },
          'filter' => [
                        {
                          'value' => $partnumber,
                          'type'  => 'equals',
                          'field' => 'productNumber'
                        }
                      ]
    };

  $ret = $self->connector->POST('api/search/product', to_json($product_filter));
  $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;
  my ($product_id, $media_data);
  try {
    $product_id = from_json($ret->responseContent())->{data}->[0]->{id};
    # $media_data = from_json($ret->responseContent())->{data}->[0]->{media};
  } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };

  # 2 iterate all kivi images and save distinct name for later sync
  my %existing_images;
  foreach my $img (@upload_img) {
    die $::locale->text("Need a image title") unless $img->{description};
    my $distinct_media_name = $partnumber . '_' . $img->{description};
    $existing_images{$distinct_media_name} = 1;
    my $image_filter = {  'filter' => [
                          {
                            'value' => $distinct_media_name,
                            'type'  => 'equals',
                            'field' => 'fileName'
                          }
                        ]
                      };
    $ret           = $self->connector->POST('api/search/media', to_json($image_filter));
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;
    my $current_image_id; # maybe empty
    try {
      $current_image_id = from_json($ret->responseContent())->{data}->[0]->{id};
    } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };

    # 2.1 no image with this title, create metadata for media and upload image
    if (!$current_image_id) {
      # get media folder id
      $ret = $self->connector->GET('api/media-folder');
      $response_code = $ret->responseCode();
      die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;
      my $media_folder_id;
      try {
        $media_folder_id = from_json($ret->responseContent())->{data}->[0]->{id};
      } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };

      # not yet uploaded, create media entry
      $ret = $self->connector->POST("/api/media?_response=true", to_json({"mediaFolderId" => $media_folder_id}));
      $response_code = $ret->responseCode();
      die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;
      try {
        $current_image_id = from_json($ret->responseContent())->{data}{id};
      } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };
    }
    # 2.2 update the image data (current_image_id was found or created)
    $ret = $self->connector->POST("/api/_action/media/$current_image_id/upload?fileName=$distinct_media_name&extension=$img->{extension}",
                                    $img->{link},
                                   {
                                    "Content-Type"  => "image/$img->{extension}",
                                   });
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 204;

    # 2.3 check if a product media entry exists for this id
    my $product_media_filter = {
              'filter' => [
                        {
                          'value' => $product_id,
                          'type' => 'equals',
                          'field' => 'productId'
                        },
                        {
                          'value' => $current_image_id,
                          'type' => 'equals',
                          'field' => 'mediaId'
                        },
                      ]
        };
    $ret = $self->connector->POST('api/search/product-media', to_json($product_media_filter));
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;
    my ($has_product_media, $product_media_id);
    try {
      $has_product_media = from_json($ret->responseContent())->{total};
      $product_media_id  = from_json($ret->responseContent())->{data}->[0]->{id};
    } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };

    # 2.4 ... and either update or create the entry
    #     set shopware position to kivi position
    my $product_media;
    $product_media->{position} = $img->{position}; # position may change

    if ($has_product_media == 0) {
      # 2.4.1 new entry. link product to media
      $product_media->{productId} = $product_id;
      $product_media->{mediaId}   = $current_image_id;
      $ret = $self->connector->POST('api/product-media', to_json($product_media));
    } elsif ($has_product_media == 1 && $product_media_id) {
      $ret = $self->connector->PATCH("api/product-media/$product_media_id", to_json($product_media));
    } else {
      die "Invalid state, please inform Shopware master admin at product-media filter: $product_media_filter";
    }
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 204;
  }
  # 3. optional set image with position 1 as cover image
  if ($params{set_cover}) {
    # set cover if position == 1
    my $product_media_filter = {
              'filter' => [
                        {
                          'value' => $product_id,
                          'type' => 'equals',
                          'field' => 'productId'
                        },
                        {
                          'value' => '1',
                          'type' => 'equals',
                          'field' => 'position'
                        },
                          ]
                             };

    $ret = $self->connector->POST('api/search/product-media', to_json($product_media_filter));
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;
    my $cover;
    try {
      $cover->{coverId} = from_json($ret->responseContent())->{data}->[0]->{id};
    } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };
    $ret = $self->connector->PATCH('api/product/' . $product_id, to_json($cover));
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 204;
  }
  # 4. optional delete orphaned images in shopware
  if ($params{delete_orphaned}) {
    # delete orphaned images
    my $product_media_filter = {
              'filter' => [
                        {
                          'value' => $product_id,
                          'type' => 'equals',
                          'field' => 'productId'
                        }, ] };
    $ret = $self->connector->POST('api/search/product-media', to_json($product_media_filter));
    $response_code = $ret->responseCode();
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 200;
    my $img_ary;
    try {
      $img_ary = from_json($ret->responseContent())->{data};
    } catch { die "Malformed JSON Data: $_ " . $ret->responseContent();  };

    if (scalar @{ $img_ary} > 0) { # maybe no images at all
      my %existing_img;
      $existing_img{$_->{media}->{fileName}}= $_->{media}->{id} for @{ $img_ary };

      while (my ($name, $id) = each %existing_img) {
        next if $existing_images{$name};
        $ret = $self->connector->DELETE("api/media/$id");
        $response_code = $ret->responseCode();
        die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code == 204;
      }
    }
  }
  return;
}

sub get_categories {
  my ($self) = @_;

  my $ret           = $self->connector->POST('api/search/category');
  my $response_code = $ret->responseCode();

  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

  my $import;
  try {
    $import = decode_json $ret->responseContent();
  } catch {
    die "Malformed JSON Data: $_ " . $ret->responseContent();
  };

  my @daten      = @{ $import->{data} };
  my %categories = map { ($_->{id} => $_) } @daten;

  my @categories_tree;
  for (@daten) {
    my $parent = $categories{$_->{parentId}};
    if ($parent) {
      $parent->{children} ||= [];
      push @{ $parent->{children} }, $_;
    } else {
      push @categories_tree, $_;
    }
  }
  return \@categories_tree;
}

sub get_one_order  {
  my ($self, $ordnumber) = @_;

  croak t8("No Order Number") unless $ordnumber;
  # set known params for the return structure
  my %fetched_order  = $self->get_fetched_order_structure;
  my $assoc          = $self->all_open_orders();

  # overwrite filter for exactly one ordnumber
  $assoc->{filter}->[0]->{value} = $ordnumber;
  $assoc->{filter}->[0]->{type}  = 'equals';
  $assoc->{filter}->[0]->{field} = 'orderNumber';

  # 1. fetch the order and import it as a kivi order
  # 2. return the number of processed order (1)
  my $one_order = $self->connector->POST('api/search/order', to_json($assoc));

  # 1. check for bad request or connection problems
  if ($one_order->responseCode() != 200) {
    $fetched_order{error}   = 1;
    $fetched_order{message} = $one_order->responseCode() . ' ' . $one_order->responseContent();
    return \%fetched_order;
  }

  # 1.1 parse json or exit
  my $content;
  try {
    $content = from_json($one_order->responseContent());
  } catch {
    $fetched_order{error}   = 1;
    $fetched_order{message} = "Malformed JSON Data: $_ " . $one_order->responseContent();
    return \%fetched_order;
  };

  # 2. check if we found ONE order at all
  my $total = $content->{total};
  if ($total == 0) {
    $fetched_order{number_of_orders} = 0;
    return \%fetched_order;
  } elsif ($total != 1) {
    $fetched_order{error}   = 1;
    $fetched_order{message} = "More than one Order returned. Invalid State: $total";
    return \%fetched_order;
  }

  # 3. there is one valid order, try to import this one
  if ($self->import_data_to_shop_order($content->{data}->[0])) {
    %fetched_order = (shop_description => $self->config->description, number_of_orders => 1);
  } else {
    $fetched_order{message} = "Error: $@";
    $fetched_order{error}   = 1;
  }
  return \%fetched_order;
}

sub get_new_orders {
  my ($self) = @_;

  my %fetched_order  = $self->get_fetched_order_structure;
  my $assoc          = $self->all_open_orders();

  # 1. fetch all open orders and try to import it as a kivi order
  # 2. return the number of processed order $total
  my $open_orders = $self->connector->POST('api/search/order', to_json($assoc));

  # 1. check for bad request or connection problems
  if ($open_orders->responseCode() != 200) {
    $fetched_order{error}   = 1;
    $fetched_order{message} = $open_orders->responseCode() . ' ' . $open_orders->responseContent();
    return \%fetched_order;
  }

  # 1.1 parse json or exit
  my $content;
  try {
    $content = from_json($open_orders->responseContent());
  } catch {
    $fetched_order{error}   = 1;
    $fetched_order{message} = "Malformed JSON Data: $_ " . $open_orders->responseContent();
    return \%fetched_order;
  };

  # 2. check if we found one or more order at all
  my $total = $content->{total};
  if ($total == 0) {
    $fetched_order{number_of_orders} = 0;
    return \%fetched_order;
  } elsif (!$total || !($total > 0)) {
    $fetched_order{error}   = 1;
    $fetched_order{message} = "Undefined value for total orders returned. Invalid State: $total";
    return \%fetched_order;
  }

  # 3. there are open orders. try to import one by one
  $fetched_order{number_of_orders} = 0;
  foreach my $open_order (@{ $content->{data} }) {
    if ($self->import_data_to_shop_order($open_order)) {
      $fetched_order{number_of_orders}++;
    } else {
      $fetched_order{message} .= "Error at importing order with running number:"
                                  . $fetched_order{number_of_orders}+1 . ": $@ \n";
      $fetched_order{error}    = 1;
    }
  }
  return \%fetched_order;
}

sub get_article {
  my ($self, $partnumber) = @_;

  $partnumber   = $::form->escape($partnumber);
  my $product_filter = {
              'filter' => [
                            {
                              'value' => $partnumber,
                              'type' => 'equals',
                              'field' => 'productNumber'
                            }
                          ]
                       };
  my $ret = $self->connector->POST('api/search/product', to_json($product_filter));

  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

  my $data_json;
  try {
    $data_json = decode_json $ret->responseContent();
  } catch {
    die "Malformed JSON Data: $_ " . $ret->responseContent();
  };

  # maybe no product was found ...
  return undef unless scalar @{ $data_json->{data} } > 0;
  # caller wants this structure:
  # $stock_onlineshop = $shop_article->{data}->{mainDetail}->{inStock};
  # $active_online = $shop_article->{data}->{active};
  my $data;
  $data->{data}->{mainDetail}->{inStock} = $data_json->{data}->[0]->{stock};
  $data->{data}->{active}                = $data_json->{data}->[0]->{active};
  return $data;
}

sub get_version {
  my ($self) = @_;

  my $return  = {}; # return for caller
  my $ret     = {}; # internal return

  #  1. check if we can connect at all
  #  2. request version number

  $ret = $self->connector;
  if (!defined $ret || 200 != $ret->responseCode()) {
    $return->{success}         = 0;
    $return->{data}->{version} = $self->{errors}; # whatever init puts in errors
    return $return;
  }

  $ret = $self->connector->GET('api/_info/version');
  if (200 == $ret->responseCode()) {
    my $version = from_json($self->connector->responseContent())->{version};
    $return->{success}         = 1;
    $return->{data}->{version} = $version;
  } else {
    $return->{success}         = 0;
    $return->{data}->{version} = $ret->responseContent(); # Whatever REST Interface says
  }

  return $return;
}

sub set_orderstatus {
  my ($self, $order_id, $transition) = @_;

  # one state differs
  $transition = 'complete' if $transition eq 'completed';

  croak "No shop order ID, should be in format [0-9a-f]{32}" unless $order_id   =~ m/^[0-9a-f]{32}$/;
  croak "NO valid transition value"                          unless $transition =~ m/(open|process|cancel|complete)/;
  my $ret;
  $ret = $self->connector->POST("/api/_action/order/$order_id/state/$transition");
  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

}
sub set_order_transaction_status {
  my ($self, $ordnumber, $transition) = @_;

  croak t8("No Order Number")         unless $ordnumber;
  croak "NO valid transition value"   unless $transition =~ m/(paid)/;

  # first fetch order_transaction id
  my %fetched_order  = $self->get_fetched_order_structure;
  my $assoc          = $self->all_open_orders();

  # overwrite filter for exactly one ordnumber
  $assoc->{filter}->[0]->{value} = $ordnumber;
  $assoc->{filter}->[0]->{type}  = 'equals';
  $assoc->{filter}->[0]->{field} = 'orderNumber';

  # 1. fetch the order and import it as a kivi order
  # 2. return the number of processed order (1)
  my $one_order = $self->connector->POST('api/search/order', to_json($assoc));
  # 1. check for bad request or connection problems
  if ($one_order->responseCode() != 200) {
    $fetched_order{error}   = 1;
    $fetched_order{message} = $one_order->responseCode() . ' ' . $one_order->responseContent();
    die "Invalid response code:" . $fetched_order{message};
  }

  # 1.1 parse json or exit
  my $content;
  try {
    $content = from_json($one_order->responseContent());
  } catch {
    $fetched_order{error}   = 1;
    $fetched_order{message} = "Malformed JSON Data: $_ " . $one_order->responseContent();
    die "Invalid JSON Data:" . $fetched_order{message};
  };

  # 2. check if we found ONE order at all
  my $total = $content->{total};
  if ($total == 0) {
    $fetched_order{number_of_orders} = 0;
    die \%fetched_order;
  } elsif ($total != 1) {
    $fetched_order{error}   = 1;
    $fetched_order{message} = "More than one Order returned. Invalid State: $total";
    die "Invalid State:" . $fetched_order{message};
  }
  # we assume just one transaction at all
  die "Can only sync one single Transaction " unless scalar @{ $content->{data}->[0]->{transactions} } == 1;

  my $order_transaction_id = $content->{data}->[0]->{transactions}->[0]->{id};
  my $ret;
  $ret = $self->connector->POST("/api/_action/order_transaction/$order_transaction_id/state/$transition");

  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

}

sub init_connector {
  my ($self) = @_;

  my $protocol = $self->config->server =~ /(^https:\/\/|^http:\/\/)/ ? '' : $self->config->protocol . '://';
  my $client   = REST::Client->new(host => $protocol . $self->config->server);

  $client->getUseragent()->proxy([$self->config->protocol], $self->config->proxy) if $self->config->proxy;
  $client->addHeader('Content-Type', 'application/json');
  $client->addHeader('charset',      'UTF-8');
  $client->addHeader('Accept',       'application/json');

  my %auth_req = (
                   client_id     => $self->config->login,
                   client_secret => $self->config->password,
                   grant_type    => "client_credentials",
                 );

  my $ret = $client->POST('/api/oauth/token', encode_json(\%auth_req));

  unless (200 == $ret->responseCode()) {
    $self->{errors} .= $ret->responseContent();
    return;
  }

  my $token = from_json($client->responseContent())->{access_token};
  unless ($token) {
    $self->{errors} .= "No Auth-Token received";
    return;
  }
  # persist refresh token
  $client->addHeader('Authorization' => 'Bearer ' . $token);
  return $client;
}

sub import_data_to_shop_order {
  my ($self, $import) = @_;

  # failsafe checks for not yet implemented
  die t8('Shipping cost article not implemented') if $self->config->shipping_costs_parts_id;

  # no mapping unless we also have at least one shop order item ...
  my $order_pos = delete $import->{lineItems};
  croak t8("No Order items fetched") unless ref $order_pos eq 'ARRAY';

  my $shop_order = $self->map_data_to_shoporder($import);

  my $shop_transaction_ret = $shop_order->db->with_transaction(sub {
    $shop_order->save;
    my $id = $shop_order->id;

    my @positions = sort { Sort::Naturally::ncmp($a->{"label"}, $b->{"label"}) } @{ $order_pos };
    my $position = 0;
    my $active_price_source = $self->config->price_source;
    #Mapping Positions
    my %discount_identifier;
    foreach my $pos (@positions) {
      if ($pos->{type} eq 'promotion') {
        next unless $pos->{payload}->{discountType} eq 'percentage';
        foreach my $discount_pos (@{ $pos->{payload}->{composition} }) {
          $discount_identifier{$discount_pos->{id}} = { discount_percentage => $pos->{payload}->{value},
                                                        discount_code       => $pos->{payload}->{code}   };
        }
        next;
      }
      $position++;
      my $price       = $::form->round_amount($pos->{unitPrice}, 2); # unit
      my %pos_columns = ( description          => $pos->{product}->{name},
                          partnumber           => $pos->{product}->{productNumber},
                          price                => $price,
                          quantity             => $pos->{quantity},
                          position             => $position,
                          tax_rate             => $pos->{priceDefinition}->{taxRules}->[0]->{taxRate},
                          shop_trans_id        => $pos->{id}, # pos id or shop_trans_id ? or dont care?
                          shop_order_id        => $id,
                          active_price_source  => $active_price_source,
                          identifier           => $pos->{identifier},
                        );
      my $pos_insert = SL::DB::ShopOrderItem->new(%pos_columns);
      $pos_insert->save;
    }
    # add discount if percentage
    while ((my $identifier, my $discount_ref) = each (%discount_identifier)) {
      # load and update shop order position
      my $soi = SL::DB::Manager::ShopOrderItem->find_by(identifier => $identifier);
      die "No Shop Order Item for discount found! identfier: " . $identifier unless ref $soi eq 'SL::DB::ShopOrderItem';

      $soi->update_attributes(discount      => $discount_ref->{discount_percentage} / 100,
                              discount_code => $discount_ref->{discount_code}       );
    }
    $shop_order->positions($position);

    if ( $self->config->shipping_costs_parts_id ) {
      die t8("Not yet implemented");
      # TODO NOT YET Implemented nor tested, this is shopware5 code:
      my $shipping_part = SL::DB::Part->find_by( id => $self->config->shipping_costs_parts_id);
      my %shipping_pos = ( description    => $import->{data}->{dispatch}->{name},
                           partnumber     => $shipping_part->partnumber,
                           price          => $import->{data}->{invoiceShipping},
                           quantity       => 1,
                           position       => $position,
                           shop_trans_id  => 0,
                           shop_order_id  => $id,
                         );
      my $shipping_pos_insert = SL::DB::ShopOrderItem->new(%shipping_pos);
      $shipping_pos_insert->save;
    }

    my $customer = $shop_order->get_customer;

    if (ref $customer eq 'SL::DB::Customer') {
      $shop_order->kivi_customer_id($customer->id);
    }
    $shop_order->save;

    # update state in shopware before transaction ends
    $self->set_orderstatus($shop_order->shop_trans_id, "process");

    1;

  }) || die t8('Error while saving shop order #1. DB Error #2. Generic exception #3.',
                $shop_order->{shop_ordernumber}, $shop_order->db->error, $@);
}

sub map_data_to_shoporder {
  my ($self, $import) = @_;

  croak "Expect a hash with one order." unless ref $import eq 'HASH';
  # we need one number and a order date, some total prices and one customer
  croak "Does not look like a shopware6 order" unless    $import->{orderNumber}
                                                      && $import->{orderDateTime}
                                                      && ref $import->{price} eq 'HASH'
                                                      && ref $import->{orderCustomer} eq 'HASH';

  my $shipto_id = $import->{deliveries}->[0]->{shippingOrderAddressId};
  die t8("Cannot get shippingOrderAddressId for #1", $import->{orderNumber}) unless $shipto_id;

  my $billing_ary = [ grep { $_->{id} == $import->{billingAddressId} }       @{ $import->{addresses} } ];
  my $shipto_ary  = [ grep { $_->{id} == $shipto_id }                        @{ $import->{addresses} } ];
  my $payment_ary = [ grep { $_->{id} == $import->{paymentMethodId} }        @{ $import->{paymentMethods} } ];

  die t8("No Billing and ship to address, for Order Number #1 with ID Billing #2 and ID Shipping #3",
          $import->{orderNumber}, $import->{billingAddressId}, $import->{deliveries}->[0]->{shippingOrderAddressId})
    unless scalar @{ $billing_ary } == 1 && scalar @{ $shipto_ary } == 1;

  my $billing = $billing_ary->[0];
  my $shipto  = $shipto_ary->[0];
  # TODO payment info is not used at all
  my $payment = scalar @{ $payment_ary } ? delete $payment_ary->[0] : undef;

  # check mandatory fields from shopware
  die t8("No billing city")   unless $billing->{city};
  die t8("No shipto city")    unless $shipto->{city};
  die t8("No customer email") unless $import->{orderCustomer}->{email};

  # extract order date
  my $parser = DateTime::Format::Strptime->new(pattern   => '%Y-%m-%dT%H:%M:%S',
                                               locale    => 'de_DE',
                                               time_zone => 'local'             );
  my $orderdate;
  try {
    $orderdate = $parser->parse_datetime($import->{orderDateTime});
  } catch { die "Cannot parse Order Date" . $_ };

  my $shop_id      = $self->config->id;
  my $tax_included = $self->config->pricetype;

  # TODO copied from shopware5 connector
  # Mapping Zahlungsmethoden muss an Firmenkonfiguration angepasst werden
  my %payment_ids_methods = (
    # shopware_paymentId => kivitendo_payment_id
  );
  my $default_payment    = SL::DB::Manager::PaymentTerm->get_first();
  my $default_payment_id = $default_payment ? $default_payment->id : undef;
  #


  my %columns = (
    amount                  => $import->{amountTotal},
    billing_city            => $billing->{city},
    billing_company         => $billing->{company},
    billing_country         => $billing->{country}->{name},
    billing_department      => $billing->{department},
    billing_email           => $import->{orderCustomer}->{email},
    billing_fax             => $billing->{fax},
    billing_firstname       => $billing->{firstName},
    #billing_greeting        => ($import->{billing}->{salutation} eq 'mr' ? 'Herr' : 'Frau'),
    billing_lastname        => $billing->{lastName},
    billing_phone           => $billing->{phone},
    billing_street          => $billing->{street},
    billing_vat             => $billing->{vatId},
    billing_zipcode         => $billing->{zipcode},
    customer_city           => $billing->{city},
    customer_company        => $billing->{company},
    customer_country        => $billing->{country}->{name},
    customer_department     => $billing->{department},
    customer_email          => $billing->{email},
    customer_fax            => $billing->{fax},
    customer_firstname      => $billing->{firstName},
    #customer_greeting       => ($billing}->{salutation} eq 'mr' ? 'Herr' : 'Frau'),
    customer_lastname       => $billing->{lastName},
    customer_phone          => $billing->{phoneNumber},
    customer_street         => $billing->{street},
    customer_vat            => $billing->{vatId},
    customer_zipcode        => $billing->{zipcode},
#    customer_newsletter     => $customer}->{newsletter},
    delivery_city           => $shipto->{city},
    delivery_company        => $shipto->{company},
    delivery_country        => $shipto->{country}->{name},
    delivery_department     => $shipto->{department},
    delivery_email          => "",
    delivery_fax            => $shipto->{fax},
    delivery_firstname      => $shipto->{firstName},
    #delivery_greeting       => ($shipto}->{salutation} eq 'mr' ? 'Herr' : 'Frau'),
    delivery_lastname       => $shipto->{lastName},
    delivery_phone          => $shipto->{phone},
    delivery_street         => $shipto->{street},
    delivery_vat            => $shipto->{vatId},
    delivery_zipcode        => $shipto->{zipcode},
#    host                    => $shop}->{hosts},
    netamount               => $import->{amountNet},
    order_date              => $orderdate,
    payment_description     => $payment->{name},
    payment_id              => $payment_ids_methods{$import->{paymentId}} || $default_payment_id,
    tax_included            => $tax_included eq "brutto" ? 1 : 0,
    shop_ordernumber        => $import->{orderNumber},
    shop_id                 => $shop_id,
    shop_trans_id           => $import->{id},
    # TODO map these:
    #remote_ip               => $import->{remoteAddress},
    #sepa_account_holder     => $import->{paymentIntances}->{accountHolder},
    #sepa_bic                => $import->{paymentIntances}->{bic},
    #sepa_iban               => $import->{paymentIntances}->{iban},
    #shipping_costs          => $import->{invoiceShipping},
    #shipping_costs_net      => $import->{invoiceShippingNet},
    #shop_c_billing_id       => $import->{billing}->{customerId},
    #shop_c_billing_number   => $import->{billing}->{number},
    #shop_c_delivery_id      => $import->{shipping}->{id},
    #shop_customer_id        => $import->{customerId},
    #shop_customer_number    => $import->{billing}->{number},
    #shop_customer_comment   => $import->{customerComment},
  );

  my $shop_order = SL::DB::ShopOrder->new(%columns);
  return $shop_order;
}

sub _u8 {
  my ($value) = @_;
  return encode('UTF-8', $value // '');
}

1;

__END__

=encoding utf-8

=head1 NAME

  SL::ShopConnector::Shopware6 - this is the Connector Class for Shopware 6

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 AVAILABLE METHODS

=over 4

=item C<get_one_order>

=item C<get_new_orders>

=item C<update_part>

Updates all metadata for a shop part. See base class for a general description.
Specific Implementation notes:
=over 4

=item Calls sync_all_images with set_cover = 1 and delete_orphaned = 1

=item Checks if longdescription should be taken from part or shop_part

=item Checks if a language with the name 'Englisch' or template_code 'en'
      is available and sets the shopware6 'en-GB' locales for the product

=item C<sync_all_images (set_cover: 0|1, delete_orphaned: 0|1)>

The connecting key for shopware to kivi images is the image name.
To get distinct entries the kivi partnumber is combined with the title (description)
of the image. Therefore part1000_someTitlefromUser should be unique in
Shopware.
All image data is simply send to shopware whether or not image data
has been edited recently.
If set_cover is set, the image with the position 1 will be used as
the shopware cover image.
If delete_orphaned ist set, all images related to the shopware product
which are not also in kivitendo will be deleted.
Shopware (6.4.x) takes care of deleting all the relations if the media
entry for the image is deleted.
More on media and Shopware6 can be found here:
https://shopware.stoplight.io/docs/admin-api/ZG9jOjEyNjI1Mzkw-media-handling

=back

=over 4

=item C<get_article>

=item C<get_categories>

=item C<get_version>

Tries to establish a connection and in a second step
tries to get the server's version number.
Returns a hashref with the data structure the Base class expects.

=item C<set_orderstatus>

=item C<init_connector>

Inits the connection to the REST Server.
Errors are collected in $self->{errors} and undef will be returned.
If successful returns a REST::Client object for further communications.

=back

=head1 SEE ALSO

L<SL::ShopConnector::ALL>

=head1 BUGS

None yet. :)

=head1 TODOS

=over 4

=item * Map all data to shop_order

Missing fields are commented in the sub map_data_to_shoporder.
Some items are SEPA debit info, IP adress, delivery costs etc
Furthermore Shopware6 uses currency, country and locales information.
Detailed list:

    #customer_newsletter     => $customer}->{newsletter},
    #remote_ip               => $import->{remoteAddress},
    #sepa_account_holder     => $import->{paymentIntances}->{accountHolder},
    #sepa_bic                => $import->{paymentIntances}->{bic},
    #sepa_iban               => $import->{paymentIntances}->{iban},
    #shipping_costs          => $import->{invoiceShipping},
    #shipping_costs_net      => $import->{invoiceShippingNet},
    #shop_c_billing_id       => $import->{billing}->{customerId},
    #shop_c_billing_number   => $import->{billing}->{number},
    #shop_c_delivery_id      => $import->{shipping}->{id},
    #shop_customer_id        => $import->{customerId},
    #shop_customer_number    => $import->{billing}->{number},
    #shop_customer_comment   => $import->{customerComment},

=item * Use shipping_costs_parts_id for additional shipping costs

Currently dies if a shipping_costs_parts_id is set in the config

=item * Payment Infos can be read from shopware but is not linked with kivi

Unused data structures in sub map_data_to_shoporder => payment_ary

=item * Delete orphaned images is new in this connector, but should be in a separate method

=item * Fetch from last order number is ignored and should not be needed

Fetch orders also sets the state of the order from open to process. The state setting
is transaction safe and therefore get_new_orders should always fetch only unprocessed orders
at all. Nevertheless get_one_order just gets one order with the exactly matching order number
and ignores any shopware order transition state.

=item * Get one order and get new orders is basically the same except for the filter

Right now the returning structure and the common parts of the filter are in two separate functions

=item * Locales!

Many error messages are thrown, but at least the more common cases should be localized.

=item * Multi language support

By guessing the correct german name for the english language some translation for parts can
also be synced. This should be more clear (language configuration for shops) and the order
synchronisation should also handle this (longdescription is simply copied from part.notes)

=item * Shopware6 Promotion Codes

Shopware6 Promotion Codes with discounts for specific positions (called line items in Shopware)
are in a single line item of the type 'promotion'. kivitendo uses a simple real number in the
range of 0 .. 1 to add a discount for a line item.
This implementation adds a percentual discount for the correct positions and does not process
the discount line item afterwards. The original Shopware Promotion Code is also saved.

=back

=head1 AUTHOR

Jan Büren jan@kivitendo.de

=cut
