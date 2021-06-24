package SL::ShopConnector::WooCommerce;

use strict;

use parent qw(SL::ShopConnector::Base);

use SL::JSON;
use LWP::UserAgent;
use LWP::Authen::Digest;
use SL::DB::ShopOrder;
use SL::DB::ShopOrderItem;
use SL::DB::PaymentTerm;
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
        my $answer = $self->set_orderstatus($shoporder->{id}, "completed");
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
    "&per_page=$otf&status=processing&after=2020-12-31T23:59:59&order=asc"
  );
  my %fetched_orders;
  if($answer->{success}) {
    my $orders = $answer->{data};
    foreach my $shoporder(@{$orders}){
      $dbh->with_transaction( sub{
          #update status on server
          $shoporder->{status} = "completed";
          my $anwser = $self->set_orderstatus($shoporder->{id}, "completed");
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

  my $active_price_source = $self->config->price_source;
  my $tax_included = $self->config->pricetype eq 'brutto' ? 1 : 0;
  #Mapping Positions
  foreach my $pos(@positions) {
    my $tax_rate = $pos->{tax_class} eq "reduced-rate" ? 7 : 19;
    my $tax_factor = $tax_rate/100+1;
    my $price = $pos->{price};
    if ( $tax_included ) {
      $price = $price * $tax_factor;
      $price = $::form->round_amount($price,2);
    } else {
      $price = $::form->round_amount($price,2);
    }
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
    my $pos_insert = SL::DB::ShopOrderItem->new(%pos_columns);
    $pos_insert->save;
    $position++;
  }
  $shop_order->positions($position-1);

  if ( $self->config->shipping_costs_parts_id ) {
    my $shipping_part = SL::DB::Part->find_by( id => $self->config->shipping_costs_parts_id);
    my %shipping_pos = (
      description    => $import->{data}->{dispatch}->{name},
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
  my $tax_included = $self->config->pricetype;

  # Mapping to table shoporders. See https://woocommerce.github.io/woocommerce-rest-api-docs/?shell#order-properties
    my $d_street;
    if ( $import->{shipping}->{address_1} ne "" ) {
      $d_street = $import->{shipping}->{address_1} . ($import->{shipping}->{address_2} ? " " . $import->{shipping}->{address_2} : "");
    } else {
      $d_street = $import->{billing}->{address_1} . ($import->{billing}->{address_2} ? " " . $import->{billing}->{address_2} : "");
    }
  # Mapping Zahlungsmethoden muss an Firmenkonfiguration angepasst werden
  my %payment_ids_methods = (
    # woocommerce_payment_method_title => kivitendo_payment_id
  );
  my $default_payment    = SL::DB::Manager::PaymentTerm->get_first();
  my $default_payment_id = $default_payment ? $default_payment->id : undef;
  my %columns = (
#billing Shop can have different billing addresses, and may have 1 customer_address
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
    billing_company         => $import->{billing}->{company},
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
    delivery_firstname      => $import->{shipping}->{first_name} || $import->{billing}->{first_name},
    delivery_lastname       => $import->{shipping}->{last_name} || $import->{billing}->{last_name},
    delivery_company        => $import->{shipping}->{company} || $import->{billing}->{company},
    #address_1 address_2
    delivery_street         => $d_street,
    delivery_city           => $import->{shipping}->{city} || $import->{billing}->{city},
    #state ???
    delivery_zipcode        => $import->{shipping}->{postcode} || $import->{billing}->{postcode},
    delivery_country        => $import->{shipping}->{country} || $import->{billing}->{country},
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
    shipping_costs          => $import->{shipping_total},
    #shipping_tax
    shipping_costs_net      => $import->{shipping_total},
    #cart_tax
    #total
    amount                  => $import->{total},
    #total_tax
    netamount               => $import->{total} - $import->{total_tax},
    #prices_include_tax
    tax_included            => $tax_included,
    #payment_method
    payment_id              => $payment_ids_methods{$import->{payment_method}} || $default_payment_id,
    #payment_method_title
    payment_description     => $import->{payment_method_title},
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
  foreach my $row_cat ( @{ $shop_part->shop_category } ) {
    my $temp = { ( id => @{$row_cat}[0], ) };
    push ( @categories, $temp );
  }

  #my @upload_img = $shop_part->get_images;
  my $partnumber = $::form->escape($part->partnumber);#don't accept / in articlenumber
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
  #  my $partnumber = $::form->escape($part->partnumber);#shopware don't accept / in articlenumber
  #  my $imgup      = $self->connector->put($url . "api/generatearticleimages/$partnumber?useNumberAsId=true");
  #}

  return $answer->{success};
}

sub get_article {
  my ($self) = @_;
  my $partnumber = $_[1];

  $partnumber   = $::form->escape($partnumber);#don't accept / in partnumber
  my $answer = $self->send_request("products/", undef , "get" , "&sku=$partnumber");

  if($answer->{success} && scalar @{$answer->{data}}){
    my $article = $answer->{data}[0];
    return $article;
  } else {
    #What shut be here?
    return $answer
  }
}

sub get_categories {
  my ($self) = @_;

  my $answer = $self->send_request("products/categories",undef,"get","&per_page=100");
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
  #  if ($status eq "fetched") { $status =  "processing"; }
  #  if ($status eq "processing") { $status = "completed"; }
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
    my $json = SL::JSON::decode_json($data_json);
    %return = (
      success => 1,
      data    => $json,
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
