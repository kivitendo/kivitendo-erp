package SL::ShopConnector::Shopware;

use strict;

use parent qw(SL::ShopConnector::Base);


use SL::JSON;
use LWP::UserAgent;
use LWP::Authen::Digest;
use SL::DB::ShopOrder;
use SL::DB::ShopOrderItem;
use SL::DB::History;
use DateTime::Format::Strptime;
use SL::DB::File;
use Data::Dumper;
use Sort::Naturally ();
use SL::Helper::Flash;
use Encode qw(encode_utf8);
use SL::File;
use File::Slurp;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(connector url) ],
);

sub get_one_order {
  my ($self, $ordnumber) = @_;

  my $dbh       = SL::DB::client;
  my $of        = 0;
  my $url       = $self->url;
  my $data      = $self->connector->get($url . "api/orders/$ordnumber?useNumberAsId=true");
  my @errors;

  my %fetched_orders;
  if ($data->is_success && $data->content_type eq 'application/json'){
    my $data_json = $data->content;
    my $import    = SL::JSON::decode_json($data_json);
    my $shoporder = $import->{data};
    $dbh->with_transaction( sub{
      $self->import_data_to_shop_order($import);
      1;
    })or do {
      push @errors,($::locale->text('Saving failed. Error message from the database: #1', $dbh->error));
    };

    if(!@errors){
      $of++;
    }else{
      flash_later('error', $::locale->text('Database errors: #1', @errors));
    }
    %fetched_orders = (shop_description => $self->config->description, number_of_orders => $of);
  } else {
    my %error_msg  = (
      shop_id          => $self->config->id,
      shop_description => $self->config->description,
      message          => "Error: $data->status_line",
      error            => 1,
    );
    %fetched_orders = %error_msg;
  }

  return \%fetched_orders;
}

sub get_new_orders {
  my ($self, $id) = @_;

  my $url              = $self->url;
  my $last_order_number = $self->config->last_order_number;
  my $otf              = $self->config->orders_to_fetch;
  my $of               = 0;
  my $last_data      = $self->connector->get($url . "api orders/$last_order_number?useNumberAsId=true");
  my $last_data_json = $last_data->content;
  my $last_import    = SL::JSON::decode_json($last_data_json);

  my $orders_data      = $self->connector->get($url . "api/orders?limit=$otf&filter[1][property]=status&filter[1][value]=0&filter[0][property]=id&filter[0][expression]=>&filter[0][value]=" . $last_import->{data}->{id});

  my $dbh = SL::DB->client;
  my @errors;
  my %fetched_orders;
  if ($orders_data->is_success && $orders_data->content_type eq 'application/json'){
    my $orders_data_json = $orders_data->content;
    my $orders_import    = SL::JSON::decode_json($orders_data_json);
    foreach my $shoporder(@{ $orders_import->{data} }){

      my $data      = $self->connector->get($url . "api/orders/" . $shoporder->{id});
      my $data_json = $data->content;
      my $import    = SL::JSON::decode_json($data_json);

      $dbh->with_transaction( sub{
          $self->import_data_to_shop_order($import);

          $self->config->assign_attributes( last_order_number => $shoporder->{number});
          $self->config->save;
          1;
      })or do {
        push @errors,($::locale->text('Saving failed. Error message from the database: #1', $dbh->error));
      };

      if(!@errors){
        $of++;
      }else{
        flash_later('error', $::locale->text('Database errors: #1', @errors));
      }
    }
    %fetched_orders = (shop_description => $self->config->description, number_of_orders => $of);
  } else {
    my %error_msg  = (
      shop_id          => $self->config->id,
      shop_description => $self->config->description,
      message          => "Error: $orders_data->status_line",
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

  my @positions = sort { Sort::Naturally::ncmp($a->{"articleNumber"}, $b->{"articleNumber"}) } @{ $import->{data}->{details} };
  #my @positions = sort { Sort::Naturally::ncmp($a->{"partnumber"}, $b->{"partnumber"}) } @{ $import->{data}->{details} };
  my $position = 1;
  my $active_price_source = $self->config->price_source;
  #Mapping Positions
  foreach my $pos(@positions) {
    my $price = $::form->round_amount($pos->{price},2);
    my %pos_columns = ( description          => $pos->{articleName},
                        partnumber           => $pos->{articleNumber},
                        price                => $price,
                        quantity             => $pos->{quantity},
                        position             => $position,
                        tax_rate             => $pos->{taxRate},
                        shop_trans_id        => $pos->{articleId},
                        shop_order_id        => $id,
                        active_price_source  => $active_price_source,
                      );
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
  my $orderdate = $parser->parse_datetime($import->{data}->{orderTime});

  my $shop_id      = $self->config->id;
  my $tax_included = $self->config->pricetype;

  # Mapping to table shoporders. See http://community.shopware.com/_detail_1690.html#GET_.28Liste.29
  my %columns = (
    amount                  => $import->{data}->{invoiceAmount},
    billing_city            => $import->{data}->{billing}->{city},
    billing_company         => $import->{data}->{billing}->{company},
    billing_country         => $import->{data}->{billing}->{country}->{name},
    billing_department      => $import->{data}->{billing}->{department},
    billing_email           => $import->{data}->{customer}->{email},
    billing_fax             => $import->{data}->{billing}->{fax},
    billing_firstname       => $import->{data}->{billing}->{firstName},
    #billing_greeting        => ($import->{data}->{billing}->{salutation} eq 'mr' ? 'Herr' : 'Frau'),
    billing_lastname        => $import->{data}->{billing}->{lastName},
    billing_phone           => $import->{data}->{billing}->{phone},
    billing_street          => $import->{data}->{billing}->{street},
    billing_vat             => $import->{data}->{billing}->{vatId},
    billing_zipcode         => $import->{data}->{billing}->{zipCode},
    customer_city           => $import->{data}->{billing}->{city},
    customer_company        => $import->{data}->{billing}->{company},
    customer_country        => $import->{data}->{billing}->{country}->{name},
    customer_department     => $import->{data}->{billing}->{department},
    customer_email          => $import->{data}->{customer}->{email},
    customer_fax            => $import->{data}->{billing}->{fax},
    customer_firstname      => $import->{data}->{billing}->{firstName},
    #customer_greeting       => ($import->{data}->{billing}->{salutation} eq 'mr' ? 'Herr' : 'Frau'),
    customer_lastname       => $import->{data}->{billing}->{lastName},
    customer_phone          => $import->{data}->{billing}->{phone},
    customer_street         => $import->{data}->{billing}->{street},
    customer_vat            => $import->{data}->{billing}->{vatId},
    customer_zipcode        => $import->{data}->{billing}->{zipCode},
    customer_newsletter     => $import->{data}->{customer}->{newsletter},
    delivery_city           => $import->{data}->{shipping}->{city},
    delivery_company        => $import->{data}->{shipping}->{company},
    delivery_country        => $import->{data}->{shipping}->{country}->{name},
    delivery_department     => $import->{data}->{shipping}->{department},
    delivery_email          => "",
    delivery_fax            => $import->{data}->{shipping}->{fax},
    delivery_firstname      => $import->{data}->{shipping}->{firstName},
    #delivery_greeting       => ($import->{data}->{shipping}->{salutation} eq 'mr' ? 'Herr' : 'Frau'),
    delivery_lastname       => $import->{data}->{shipping}->{lastName},
    delivery_phone          => $import->{data}->{shipping}->{phone},
    delivery_street         => $import->{data}->{shipping}->{street},
    delivery_vat            => $import->{data}->{shipping}->{vatId},
    delivery_zipcode        => $import->{data}->{shipping}->{zipCode},
    host                    => $import->{data}->{shop}->{hosts},
    netamount               => $import->{data}->{invoiceAmountNet},
    order_date              => $orderdate,
    payment_description     => $import->{data}->{payment}->{description},
    payment_id              => $import->{data}->{paymentId},
    remote_ip               => $import->{data}->{remoteAddress},
    sepa_account_holder     => $import->{data}->{paymentIntances}->{accountHolder},
    sepa_bic                => $import->{data}->{paymentIntances}->{bic},
    sepa_iban               => $import->{data}->{paymentIntances}->{iban},
    shipping_costs          => $import->{data}->{invoiceShipping},
    shipping_costs_net      => $import->{data}->{invoiceShippingNet},
    shop_c_billing_id       => $import->{data}->{billing}->{customerId},
    shop_c_billing_number   => $import->{data}->{billing}->{number},
    shop_c_delivery_id      => $import->{data}->{shipping}->{id},
    shop_customer_id        => $import->{data}->{customerId},
    shop_customer_number    => $import->{data}->{billing}->{number},
    shop_customer_comment   => $import->{data}->{customerComment},
    shop_id                 => $shop_id,
    shop_ordernumber        => $import->{data}->{number},
    shop_trans_id           => $import->{data}->{id},
    tax_included            => $tax_included eq "brutto" ? 1 : 0,
  );

  my $shop_order = SL::DB::ShopOrder->new(%columns);
  return $shop_order;
}

sub get_categories {
  my ($self) = @_;

  my $url        = $self->url;
  my $data       = $self->connector->get($url . "api/categories");
  my $data_json  = $data->content;
  my $import     = SL::JSON::decode_json($data_json);
  my @daten      = @{$import->{data}};
  my %categories = map { ($_->{id} => $_) } @daten;

  for(@daten) {
    my $parent = $categories{$_->{parentId}};
    $parent->{children} ||= [];
    push @{$parent->{children}},$_;
  }

  return \@daten;
}

sub get_version {
  my ($self) = @_;

  my $url       = $self->url;
  my $data      = $self->connector->get($url . "api/version");
  my $type = $data->content_type;
  my $status_line = $data->status_line;

  if($data->is_success && $type eq 'application/json'){
    my $data_json = $data->content;
    return SL::JSON::decode_json($data_json);
  }else{
    my %return = ( success => 0,
                   data    => { version => $url . ": " . $status_line, revision => $type },
                   message => "Server not found or wrong data type",
                );
    return \%return;
  }
}

sub update_part {
  my ($self, $shop_part, $todo) = @_;

  #shop_part is passed as a param
  die unless ref($shop_part) eq 'SL::DB::ShopPart';

  my $url = $self->url;
  my $part = SL::DB::Part->new(id => $shop_part->part_id)->load;

  # CVARS to map
  my $cvars = { map { ($_->config->name => { value => $_->value_as_text, is_valid => $_->is_valid }) } @{ $part->cvars_by_config } };

  my @cat = ();
  foreach my $row_cat ( @{ $shop_part->shop_category } ) {
    my $temp = { ( id => @{$row_cat}[0], ) };
    push ( @cat, $temp );
  }

  my @upload_img = $shop_part->get_images;
  my $tax_n_price = $shop_part->get_tax_and_price;
  my $price = $tax_n_price->{price};
  my $taxrate = $tax_n_price->{tax};
  # mapping to shopware still missing attributes,metatags
  my %shop_data;

  if($todo eq "price"){
    %shop_data = ( mainDetail => { number   => $part->partnumber,
                                   prices   =>  [ { from             => 1,
                                                    price            => $price,
                                                    customerGroupKey => 'EK',
                                                  },
                                                ],
                                  },
                 );
  }elsif($todo eq "stock"){
    %shop_data = ( mainDetail => { number   => $part->partnumber,
                                   inStock  => $part->onhand,
                                 },
                 );
  }elsif($todo eq "price_stock"){
    %shop_data =  ( mainDetail => { number   => $part->partnumber,
                                    inStock  => $part->onhand,
                                    prices   =>  [ { from             => 1,
                                                     price            => $price,
                                                     customerGroupKey => 'EK',
                                                   },
                                                 ],
                                   },
                   );
  }elsif($todo eq "active"){
    %shop_data =  ( mainDetail => { number   => $part->partnumber,
                                   },
                    active => ($part->partnumber == 1 ? 0 : 1),
                   );
  }elsif($todo eq "all"){
  # mapping to shopware still missing attributes,metatags
    %shop_data =  (   name              => $part->description,
                      mainDetail        => { number   => $part->partnumber,
                                             inStock  => $part->onhand,
                                             prices   =>  [ {          from   => 1,
                                                                       price  => $price,
                                                            customerGroupKey  => 'EK',
                                                            },
                                                          ],
                                             active   => $shop_part->active,
                                             #attribute => { attr1  => $cvars->{CVARNAME}->{value}, } , #HowTo handle attributes
                                       },
                      supplier          => 'AR', # Is needed by shopware,
                      descriptionLong   => $shop_part->shop_description,
                      active            => $shop_part->active,
                      images            => [ @upload_img ],
                      __options_images  => { replace => 1, },
                      categories        => [ @cat ],
                      description       => $shop_part->shop_description,
                      categories        => [ @cat ],
                      tax               => $taxrate,
                    )
                  ;
  }

  my $dataString = SL::JSON::to_json(\%shop_data);
  $dataString    = encode_utf8($dataString);

  my $upload_content;
  my $upload;
  my ($import,$data,$data_json);
  my $partnumber = $::form->escape($part->partnumber);#shopware don't accept / in articlenumber
  # Shopware RestApi sends an erroremail if configured and part not found. But it needs this info to decide if update or create a new article
  # LWP->post = create LWP->put = update
    $data       = $self->connector->get($url . "api/articles/$partnumber?useNumberAsId=true");
    $data_json  = $data->content;
    $import     = SL::JSON::decode_json($data_json);
  if($import->{success}){
    #update
    my $partnumber  = $::form->escape($part->partnumber);#shopware don't accept / in articlenumber
    $upload         = $self->connector->put($url . "api/articles/$partnumber?useNumberAsId=true", Content => $dataString);
    my $data_json   = $upload->content;
    $upload_content = SL::JSON::decode_json($data_json);
  }else{
    #upload
    $upload         = $self->connector->post($url . "api/articles/", Content => $dataString);
    my $data_json   = $upload->content;
    $upload_content = SL::JSON::decode_json($data_json);
  }
  # don't know if this is needed
  if(@upload_img) {
    my $partnumber = $::form->escape($part->partnumber);#shopware don't accept / in articlenumber
    my $imgup      = $self->connector->put($url . "api/generatearticleimages/$partnumber?useNumberAsId=true");
  }

  return $upload_content->{success};
}

sub get_article {
  my ($self,$partnumber) = @_;

  my $url       = $self->url;
  $partnumber   = $::form->escape($partnumber);#shopware don't accept / in articlenumber
  my $data      = $self->connector->get($url . "api/articles/$partnumber?useNumberAsId=true");
  my $data_json = $data->content;
  return SL::JSON::decode_json($data_json);
}

sub init_url {
  my ($self) = @_;
  $self->url($self->config->protocol . "://" . $self->config->server . ":" . $self->config->port . $self->config->path);
}

sub init_connector {
  my ($self) = @_;
  my $ua = LWP::UserAgent->new;
  $ua->credentials(
      $self->config->server . ":" . $self->config->port,
      $self->config->realm,
      $self->config->login => $self->config->password
  );

  return $ua;

}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Shopconnecter::Shopware - connector for shopware 5

=head1 SYNOPSIS


=head1 DESCRIPTION

This is the connector to shopware.
In this file you can do the mapping to your needs.
see https://developers.shopware.com/developers-guide/rest-api/
for more information.

=head1 METHODS

=over 4

=item C<get_one_order>

Fetches one order specified by ordnumber

=item C<get_new_orders>

Fetches new order by parameters from shop configuration

=item C<import_data_to_shop_order>

Creates on shoporder object from json
Here is the mapping for the positions.
see https://developers.shopware.com/developers-guide/rest-api/
for detailed information

=item C<map_data_to_shoporder>

Here is the mapping for the order data.
see https://developers.shopware.com/developers-guide/rest-api/
for detailed information

=item C<get_categories>

=item C<get_version>

Use this for test Connection
see SL::Shop

=item C<update_part>

Here is the mapping for the article data.
see https://developers.shopware.com/developers-guide/rest-api/
for detailed information

=item C<get_article>

=back

=head1 INITS

=over 4

=item init_url

build an url for LWP

=item init_connector

=back

=head1 TODO

Pricesrules, pricessources aren't fully implemented yet.
Payments aren't implemented( need to map payments from Shopware like invoice, paypal etc. to payments in kivitendo)

=head1 BUGS

None yet. :)

=head1 AUTHOR

W. Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
