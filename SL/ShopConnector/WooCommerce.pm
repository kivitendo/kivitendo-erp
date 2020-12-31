package SL::ShopConnector::WooCommerce;

use strict;

use parent qw(SL::ShopConnector::Base);

use SL::JSON;
use LWP::UserAgent;
use LWP::Authen::Digest;
use SL::DB::ShopOrder;
use SL::DB::ShopOrderItem;
use SL::DB::History;
use SL::DB::File;
use Data::Dumper;
use SL::Helper::Flash;
use Encode qw(encode_utf8);

sub get_one_order {
  my ($self, $order_id) = @_;

  my $dbh       = SL::DB::client;
  my $number_of_orders = 0;
  my @errors;

  my $answer = $self->send_request(
    "orders/" . $order_id,
    undef,
    "get"
  );
  my %fetched_orders;
  if($answer->{success}) {
    my $shoporder = $answer->{data};

    $dbh->with_transaction( sub{
        #update status on server
        $shoporder->{status} = "processing";
        my $answer = $self->set_orderstatus($shoporder->{id}, "fetched");
        unless($answer){
          push @errors,($::locale->text('Saving failed. Error message from the server: #1', $answer->message));
          return 0;
        }

        unless ($self->import_data_to_shop_order($shoporder)) { return 0;}

        1;
      })or do {
      push @errors,($::locale->text('Saving failed. Error message from the database: #1', $dbh->error));
    };

    if(@errors){
      flash_later('error', $::locale->text('Errors: #1', @errors));
    } else {
      $number_of_orders++;
    }
    %fetched_orders = (shop_description => $self->config->description, number_of_orders => $number_of_orders);
  } else {
    my %error_msg  = (
      shop_id          => $self->config->id,
      shop_description => $self->config->description,
      message          => $answer->{message},
      error            => 1,
    );
    %fetched_orders = %error_msg;
  }
  return \%fetched_orders;
}

sub get_new_orders {
  my ($self) = @_;

  my $dbh       = SL::DB::client;
  my $otf              = $self->config->orders_to_fetch || 10;
  my $number_of_orders = 0;
  my @errors;

  my $answer = $self->send_request(
    "orders",
    undef,
    "get",
    "&per_page=$otf&status=pending"
  );
  my %fetched_orders;
  if($answer->{success}) {
    my $orders = $answer->{data};
    foreach my $shoporder(@{$orders}){

      $dbh->with_transaction( sub{
          #update status on server
          $shoporder->{status} = "processing";
          my $anser = $self->set_orderstatus($$shoporder->{id}, "fetched");
          unless($answer){
            push @errors,($::locale->text('Saving failed. Error message from the server: #1', $answer->message));
            return 0;
          }

          unless ($self->import_data_to_shop_order($shoporder)) { return 0;}

          1;
      })or do {
        push @errors,($::locale->text('Saving failed. Error message from the database: #1', $dbh->error));
      };

      if(@errors){
        flash_later('error', $::locale->text('Errors: #1', @errors));
      } else {
        $number_of_orders++;
      }
    }
    %fetched_orders = (shop_description => $self->config->description, number_of_orders => $number_of_orders);

  } else {
    my %error_msg  = (
      shop_id          => $self->config->id,
      shop_description => $self->config->description,
      message          => $answer->{message},
      error            => 1,
    );
    %fetched_orders = %error_msg;
  }

  return \%fetched_orders;
}

sub import_data_to_shop_order {
  my ( $self, $import ) = @_;
  my $shop_order = $self->map_data_to_shoporder($import);

  $shop_order->save;
  my $id = $shop_order->id;

  my @positions = sort { Sort::Naturally::ncmp($a->{"sku"}, $b->{"sku"}) } @{ $import->{line_items} };
  my $position = 1;

  my $answer= $self->send_request("taxes");
  unless ($answer->{success}){ return 0;}
  my %taxes = map { ($_->{id} => $_) } @{ $answer->{data} };

  my $active_price_source = $self->config->price_source;
  #Mapping Positions
  foreach my $pos(@positions) {
    my $price = $::form->round_amount($pos->{total},2);
    my $tax_id = $pos->{taxes}[0]->{id};
    my $tax_rate = $taxes{ $tax_id }{rate};
    my %pos_columns = ( description          => $pos->{name},
                        partnumber           => $pos->{sku}, # sku has to be a valid value in WooCommerce
                        price                => $price,
                        quantity             => $pos->{quantity},
                        position             => $position,
                        tax_rate             => $tax_rate,
                        shop_trans_id        => $pos->{product_id},
                        shop_order_id        => $id,
                        active_price_source  => $active_price_source,
                      );
    #$main::lxdebug->dump(0, "TST: WooCommerce save pos", $pos);
    #$main::lxdebug->dump(0, "TST: WooCommerce save pos_columns", \%pos_columns);
    my $pos_insert = SL::DB::ShopOrderItem->new(%pos_columns);
    $pos_insert->save;
    $position++;
  }
  $shop_order->positions($position-1);

  my $customer = $shop_order->get_customer;

  if(ref($customer)){
    $shop_order->kivi_customer_id($customer->id);
  }
  $shop_order->save;
}


sub map_data_to_shoporder {
  my ($self, $import) = @_;

  my $parser = DateTime::Format::Strptime->new( pattern   => '%Y-%m-%dT%H:%M:%S',
                                                  locale    => 'de_DE',
                                                  time_zone => 'local'
                                                );

  my $shop_id      = $self->config->id;

  # Mapping to table shoporders. See https://woocommerce.github.io/woocommerce-rest-api-docs/?shell#order-properties
  my %columns = (
#billing
    billing_firstname       => $import->{billing}->{first_name},
    billing_lastname        => $import->{billing}->{last_name},
    #address_1 address_2
    billing_street         => $import->{billing}->{address_1} . ($import->{billing}->{address_2} ? " " . $import->{billing}->{address_2} : ""),
    # ???
    billing_city            => $import->{billing}->{city},
    #state
    # ???
    billing_zipcode         => $import->{billing}->{postcode},
    billing_country         => $import->{billing}->{country},
    billing_email           => $import->{billing}->{email},
    billing_phone           => $import->{billing}->{phone},

    #billing_greeting        => "",
    #billing_fax             => "",
    #billing_vat             => "",
    #billing_company         => "",
    #billing_department      => "",

#customer
    #customer_id
    shop_customer_id        => $import->{customer_id},
    shop_customer_number    => $import->{customer_id},
    #customer_ip_address
    remote_ip               => $import->{customer_ip_address},
    #customer_user_agent
    #customer_note
    shop_customer_comment   => $import->{customer_note},

    #customer_city           => "",
    #customer_company        => "",
    #customer_country        => "",
    #customer_department     => "",
    #customer_email          => "",
    #customer_fax            => "",
    #customer_firstname      => "",
    #customer_greeting       => "",
    #customer_lastname       => "",
    #customer_phone          => "",
    #customer_street         => "",
    #customer_vat            => "",

#shipping
    delivery_firstname      => $import->{shipping}->{first_name},
    delivery_lastname       => $import->{shipping}->{last_name},
    delivery_company        => $import->{shipping}->{company},
    #address_1 address_2
    delivery_street         => $import->{shipping}->{address_1} . ($import->{shipping}->{address_2} ? " " . $import->{shipping}->{address_2} : ""),
    delivery_city           => $import->{shipping}->{city},
    #state ???
    delivery_zipcode        => $import->{shipping}->{postcode},
    delivery_country        => $import->{shipping}->{country},
    #delivery_department     => "",
    #delivery_email          => "",
    #delivery_fax            => "",
    #delivery_phone          => "",
    #delivery_vat            => "",

#other
    #id
    #parent_id
    #number
    shop_ordernumber        => $import->{number},
    #order_key
    #created_via
    #version
    #status
    #currency
    #date_created
    order_date              => $parser->parse_datetime($import->{date_created}),
    #date_created_gmt
    #date_modified
    #date_modified_gmt
    #discount_total
    #discount_tax
    #shipping_total
    shipping_costs          => $import->{shipping_costs},
    #shipping_tax
    shipping_costs_net      => $import->{shipping_costs} - $import->{shipping_tax},
    #cart_tax
    #total
    amount                  => $import->{total},
    #total_tax
    netamount               => $import->{total} - $import->{total_tax},
    #prices_include_tax
    tax_included            => $import->{prices_include_tax} eq "true" ? 1 : 0,
    #payment_method
    # ??? payment_id              => $import->{payment_method},
    #payment_method_title
    payment_description     => $import->{payment}->{payment_method_title},
    #transaction_id
    shop_trans_id           => $import->{id},
    #date_paid
    #date_paid_gmt
    #date_completed
    #date_completed_gmt

    host                    => $import->{_links}->{self}[0]->{href},

    #sepa_account_holder     => "",
    #sepa_bic                => "",
    #sepa_iban               => "",

    #shop_c_billing_id       => "",
    #shop_c_billing_number   => "",
    shop_c_delivery_id      => $import->{shipping_lines}[0]->{id}, # ???

# not in Shop
    shop_id                 => $shop_id,
  );

  my $shop_order = SL::DB::ShopOrder->new(%columns);
  return $shop_order;
}

#TODO CVARS, tax and images
sub update_part {
  my ($self, $shop_part, $todo) = @_;

  #shop_part is passed as a param
  die unless ref($shop_part) eq 'SL::DB::ShopPart';
  my $part = SL::DB::Part->new(id => $shop_part->part_id)->load;

  # CVARS to map
  #my $cvars = {
  #  map {
  #    ($_->config->name => {
  #      value => $_->value_as_text,
  #      is_valid => $_->is_valid
  #    })
  #  }
  #  @{ $part->cvars_by_config }
  #};

  my @categories = ();
  if ($shop_part->shop_category) {
    foreach my $row_cat ( @{ $shop_part->shop_category } ) {
      my $temp = { ( id => @{$row_cat}[0], ) };
      push ( @categories, $temp );
    }
  }

  #my @upload_img = $shop_part->get_images;
  my $partnumber = $::form->escape($part->partnumber);#don't accept / in partnumber
  my $stock_status = ($part->onhand ? "instock" : "outofstock");
  my $status = ($shop_part->active ? "publish" : "private");
  my $tax_n_price = $shop_part->get_tax_and_price;
  my $price = $tax_n_price->{price};
  #my $taxrate = $tax_n_price->{tax};
  #my $tax_class = ($taxrate >= 16 ? "standard" : "reduzierter-preis");

  my %shop_data;

  if($todo eq "price"){
    %shop_data = (
      regular_price => $price,
    );
  }elsif($todo eq "stock"){
    %shop_data = (
      stock_status => $stock_status,
    );
  }elsif($todo eq "price_stock"){
    %shop_data =  (
      stock_status => $stock_status,
      regular_price => $price,
    );
  }elsif($todo eq "active"){
    %shop_data =  (
      status => $status,
    );
  }elsif($todo eq "all"){
  # mapping  still missing attributes,metatags
    %shop_data =  (
      sku => $partnumber,
      name => $part->description,
      stock_status => $stock_status,
      regular_price => $price,
      status => $status,
      description=> $shop_part->shop_description,
      short_description=> $shop_part->shop_description,
      categories => [ @categories ],
      #tax_class => $tax_class,
    );
  }

  my $dataString = SL::JSON::to_json(\%shop_data);
  $dataString    = encode_utf8($dataString);

  # LWP->post = create || LWP->put = update
  my $answer = $self->send_request("products/", undef , "get" , "&sku=$partnumber");

  if($answer->{success} && scalar @{$answer->{data}}){
    #update
    my $woo_shop_part_id = $answer->{data}[0]->{id};
    $answer = $self->send_request("products/$woo_shop_part_id", $dataString, "put");
  }else{
    #upload
    $answer = $self->send_request("products", $dataString, "post");
  }

  # don't know if this is needed
  #if(@upload_img) {
  #  my $partnumber = $::form->escape($part->partnumber);#shopware don't accept / in partnumber
  #  my $imgup      = $self->connector->put($url . "api/generatepartimages/$partnumber?useNumberAsId=true");
  #}

  return $answer->{success};
}

sub get_article_info {
  my ($self) = @_;
  my $partnumber = $_[1];

  $partnumber   = $::form->escape($partnumber);#don't accept / in partnumber
  my $answer = $self->send_request("products/", undef , "get" , "&sku=$partnumber");

  $answer->{data} = $answer->{data}[0];
  #$main::lxdebug->dump(0, "TST: WooCommerce get_part_info ", $answer);
  return $answer;

  if($answer->{success} && scalar @{$answer->{data}}){
    my $part = $self->map_data_to_part($answer->{data}[0]);
    #$main::lxdebug->dump(0, "TST: WooCommerce get_part_info part", $part);
    return $part;
  } else {
    #What shut be here?
    return $answer
  }
}

sub map_data_to_part {
  my ($self, $part_data) = @_;

  my %map_part_data =  (
    #id                 => $part_data->{},
    partnumber         => $part_data->{sku},
    description        => $part_data->{name},
    #listprice          => $part_data->{},
    #sellprice          => $part_data->{},
    #lastcost           => $part_data->{},
    #priceupdate        => $part_data->{},
    #weight             => $part_data->{},
    notes              => $part_data->{description},
    #makemodel          => $part_data->{},
    #rop                => $part_data->{},
    shop               => 1,
    obsolete           => 0,
    #bom                => $part_data->{},
    #image              => $part_data->{},
    #drawing            => $part_data->{},
    #microfiche         => $part_data->{},
    #partsgroup_id      => $part_data->{},
    #ve                 => $part_data->{},
    #gv                 => $part_data->{},
    #itime              => $part_data->{},
    #mtime              => $part_data->{},
    #unit               => $part_data->{},
    unit               => 'Stck',
    #formel             => $part_data->{},
    #not_discountable   => $part_data->{},
    #buchungsgruppen_id => $part_data->{},
    #payment_id         => $part_data->{},
    #ean                => $part_data->{},
    #price_factor_id    => $part_data->{},
    #onhand             => $part_data->{},
    #stockable          => $part_data->{},
    #has_sernumber      => $part_data->{},
    #warehouse_id       => $part_data->{},
    #bin_id             => $part_data->{},
    #df_status_aktuell  => $part_data->{},
    #df_status_verlauf  => $part_data->{},
    #active             => $part_data->{},
    #classification_id  => $part_data->{},
    part_type          => 'part',
  );
  return SL::DB::Part->new(%map_part_data);
}

sub map_data_to_shop_part {
  my ($self, $part_data, $part) = @_;

  my @categories = ();
  foreach my $row_cat ( @{ $part_data->{categories} } ) {
    my @tmp;
    push( @tmp,$row_cat->{id} );
    push( @tmp,$row_cat->{name} );
    push( @categories,\@tmp );
  }
  my %map_shop_part_data =  (
    #id                  => ,
    shop_id             => $self->config->id,
    part_id             => $part->id,
    shop_description    => $part_data->{description},
    #itime               => ,
    #mtime               => ,
    #last_update         => ,
    #show_date           => ,
    sortorder           => $part_data->{menu_order},
    #front_page          => ,
    active              => 1,
    shop_category       => \@categories,
    #active_price_source => ,
    #metatag_keywords    => ,
    #metatag_description => ,
    #metatag_title       => ,
    #shop_versandhinweis => ,
  );
  return SL::DB::ShopPart->new(%map_shop_part_data);
}
sub get_shop_parts {
  my ($self, $partnumber) = @_;

  my $dbh       = SL::DB::client;
  my @errors;
  my $number_of_parts = 0;
  my %fetched_parts;
  my $answer;

  if ($partnumber) {
    $partnumber   = $::form->escape($partnumber);#don't accept / in partnumber
    $answer = $self->send_request("products/", undef , "get" , "&sku=$partnumber");
  } else {
    #TODO
    $answer = $self->send_request("products/", undef , "get");
    if ($answer->{total_pages} > 1) {
      my $current_page = 2;
      while ($current_page <= $answer->{total_pages}) {
        my $tmp_answer = $self->send_request("products/", undef , "get", "&page=$current_page");
        foreach my $part (@{$tmp_answer->{data}}) {
          push @{$answer->{data}} , $part;
        }
        $current_page++;
      }
    }
  }

  if($answer->{success} && scalar @{$answer->{data}}){
    $dbh->with_transaction( sub{
      foreach my $part_data (@{$answer->{data}}) {
      unless (!$part_data->{sku} || SL::DB::Manager::Part->get_all_count( query => [ partnumber => $part_data->{sku} ] )) {
          my $part = $self->map_data_to_part($part_data);
          #$main::lxdebug->dump(0, "TST: WooCommerce get_shop_parts part ", $part);
          $part->save;
          my $shop_part = $self->map_data_to_shop_part($part_data, $part);
          #$main::lxdebug->dump(0, "TST: WooCommerce get_shop_parts shop_part ", $shop_part);
          $shop_part->save;
          $number_of_parts++;
        }
      }
      return 1;
    })or do {
      push @errors,($::locale->text('Saving failed. Error message from the database: #1', $dbh->error));
    };

    if(@errors){
      flash_later('error', $::locale->text('Errors: #1', @errors));
    }
    %fetched_parts = (
      shop_id          => $self->config->id,
      shop_description => $self->config->description,
      number_of_parts => $number_of_parts,
    );
  } else {
    my %error_msg  = (
      shop_id          => $self->config->id,
      shop_description => $self->config->description,
      message          => $answer->{message},
      error            => 1,
    );
    %fetched_parts = %error_msg;
  }
  return \%fetched_parts;
}

sub get_categories {
  my ($self) = @_;

  my $answer = $self->send_request("products/categories");
  unless($answer->{success}) {
    return $answer;
  }
  my @data = @{$answer->{data}};
  my %categories = map { ($_->{id} => $_) } @data;

  my @categories_tree;
  for(@data) {
    my $parent = $categories{$_->{parent}};
    if($parent) {
      $parent->{children} ||= [];
      push @{$parent->{children}},$_;
    } else {
      push @categories_tree, $_;
    }
  }

  return \@categories_tree;
}

sub get_version {
  my ($self) = @_;

  my $answer = $self->send_request("system_status");
  if($answer->{success}) {
    my $version = $answer->{data}->{environment}->{version};
    my %return = (
      success => 1,
      data    => { version => $version },
    );
    return \%return;
  } else {
    return $answer;
  }
}

sub set_orderstatus {
  my ($self,$order_id, $status) = @_;
  if ($status eq "fetched") { $status =  "processing"; }
  if ($status eq "completed") { $status = "completed"; }
  my %new_status = (status => $status);
  my $status_json = SL::JSON::to_json( \%new_status);
  my $answer = $self->send_request("orders/$order_id", $status_json, "put");
  unless($answer->{success}){
    return 0;
  }
  return 1;
}

sub create_url {
  my ($self) = @_;
  my $request = $_[1];
  my $parameters = $_[2];

  my $consumer_key = $self->config->login;
  my $consumer_secret = $self->config->password;
  my $protocol = $self->config->protocol;
  my $server = $self->config->server;
  my $port = $self->config->port;
  my $path = $self->config->path;

  return $protocol . "://". $server . ":" . $port . $path . $request . "?consumer_key=" . $consumer_key . "&consumer_secret=" . $consumer_secret . $parameters;
}

sub send_request {
  my ($self) = @_;
  my $request = $_[1];
  my $json_data = $_[2];
  my $method_type = $_[3];
  my $parameters = $_[4];

  my $ua = LWP::UserAgent->new;
  my $url = $self->create_url( $request, $parameters );

  my $answer;
  if( $method_type eq "put" ) {
    $answer = $ua->put($url, "Content-Type" => "application/json", Content => $json_data);
  } elsif ( $method_type eq "post") {
    $answer = $ua->post($url, "Content-Type" => "application/json", Content => $json_data);
  } else {
    $answer = $ua->get($url);
  }

  my $type = $answer->content_type;
  my $status_line = $answer->status_line;

  my %return;
  if($answer->is_success && $type eq 'application/json'){
    my $data_json = $answer->content;
    #$main::lxdebug->dump(0, "TST: WooCommerce send_request header ", $answer->header( 'Link'));
    my $json = SL::JSON::decode_json($data_json);
    %return = (
      success => 1,
      data    => $json,
      total_pages => $answer->header( 'X-WP-TotalPages'),
      total_elements => $answer->header( 'X-WP-Total'),
    );
  }else{
    %return = (
      success => 0,
      data    => { version => $url . ": " . $status_line, data_type => $type },
      message => "Error: $status_line",
    );
  }
  #$main::lxdebug->dump(0, "TST: WooCommerce send_request return ", \%return);
  return \%return;

}

1;
