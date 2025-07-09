package SL::DB::Order;

use utf8;
use strict;

use Carp;
use DateTime;
use List::Util qw(max);
use List::MoreUtils qw(any);

use SL::DBUtils ();
use SL::DB::PurchaseBasketItem;
use SL::DB::MetaSetup::Order;
use SL::DB::Manager::Order;
use SL::DB::Helper::Attr;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::AttrSorted;
use SL::DB::Helper::FlattenToForm;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::PriceTaxCalculator;
use SL::DB::Helper::PriceUpdater;
use SL::DB::Helper::TypeDataProxy;
use SL::DB::Helper::TransNumberGenerator;
use SL::DB::Helper::Payment qw(forex);
use SL::DB::Helper::RecordLink qw(RECORD_ID RECORD_TYPE_REF RECORD_ITEM_ID RECORD_ITEM_TYPE_REF);
use SL::Helper::Flash;
use SL::Locale::String qw(t8);
use SL::RecordLinks;
use Rose::DB::Object::Helpers qw(as_tree strip);

use SL::DB::Order::TypeData qw(:types validate_type);
use SL::DB::Reclamation::TypeData qw(:types);

__PACKAGE__->meta->add_relationship(
  orderitems => {
    type         => 'one to many',
    class        => 'SL::DB::OrderItem',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'part' ]
    }
  },
  periodic_invoices_config => {
    type                   => 'one to one',
    class                  => 'SL::DB::PeriodicInvoicesConfig',
    column_map             => { id => 'oe_id' },
  },
  custom_shipto            => {
    type                   => 'one to one',
    class                  => 'SL::DB::Shipto',
    column_map             => { id => 'trans_id' },
    query_args             => [ module => 'OE' ],
  },
  exchangerate_obj         => {
    type                   => 'one to one',
    class                  => 'SL::DB::Exchangerate',
    column_map             => { currency_id => 'currency_id', transdate => 'transdate' },
  },
  phone_notes => {
    type         => 'one to many',
    class        => 'SL::DB::Note',
    column_map   => { id => 'trans_id' },
    query_args   => [ trans_module => 'oe' ],
    manager_args => {
      with_objects => [ 'employee' ],
      sort_by      => 'notes.itime',
    }
  },
  order_version => {
    type                   => 'one to many',
    class                  => 'SL::DB::OrderVersion',
    column_map             => { id => 'oe_id' },
  },
);

SL::DB::Helper::Attr::make(__PACKAGE__, daily_exchangerate => 'numeric');

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('notes');
__PACKAGE__->attr_sorted('items');

__PACKAGE__->before_save('_before_save_set_ord_quo_number');
__PACKAGE__->before_save('_before_save_create_new_project');
__PACKAGE__->before_save('_before_save_remove_empty_custom_shipto');
__PACKAGE__->before_save('_before_save_set_custom_shipto_module');
__PACKAGE__->after_save('_after_save_link_records');
__PACKAGE__->after_save('_after_save_close_reachable_intakes'); # uses linked records (order matters)
__PACKAGE__->before_save('_before_save_delete_from_purchase_basket');

# hooks

sub _before_save_set_ord_quo_number {
  my ($self) = @_;

  # ordnumber is 'NOT NULL'. Therefore make sure it's always set to at
  # least an empty string, even if we're saving a quotation.
  $self->ordnumber('') if !$self->ordnumber;

  $self->create_trans_number if !$self->record_number;

  return 1;
}
sub _before_save_create_new_project {
  my ($self) = @_;

  # force new project, if not set yet
  if ($::instance_conf->get_order_always_project && !$self->globalproject_id && ($self->type eq SALES_ORDER_TYPE())) {

    die t8("Error while creating project with project number of new order number, project number #1 already exists!", $self->ordnumber)
      if SL::DB::Manager::Project->find_by(projectnumber => $self->ordnumber);

    eval {
      my $new_project = SL::DB::Project->new(
          projectnumber     => $self->ordnumber,
          description       => $self->customer->name,
          customer_id       => $self->customer->id,
          active            => 1,
          project_type_id   => $::instance_conf->get_project_type_id,
          project_status_id => $::instance_conf->get_project_status_id,
          );
       $new_project->save;
       $self->globalproject_id($new_project->id);
    } or die t8('Could not create new project #1', $@);
  }
  return 1;
}


sub _before_save_remove_empty_custom_shipto {
  my ($self) = @_;

  $self->custom_shipto(undef) if $self->custom_shipto && $self->custom_shipto->is_empty;

  return 1;
}

sub _before_save_set_custom_shipto_module {
  my ($self) = @_;

  $self->custom_shipto->module('OE') if $self->custom_shipto;

  return 1;
}

sub _after_save_link_records {
  my ($self) = @_;

  my @allowed_record_sources = qw(SL::DB::Reclamation SL::DB::Order SL::DB::EmailJournal);
  my @allowed_item_sources = qw(SL::DB::ReclamationItem SL::DB::OrderItem);

  SL::DB::Helper::RecordLink::link_records(
    $self,
    \@allowed_record_sources,
    \@allowed_item_sources,
  );

  return 1;
}

sub _after_save_close_reachable_intakes {
  my ($self) = @_;

  # Close reachable sales order intakes in the from-workflow if this is a sales order
  if (SALES_ORDER_TYPE() eq $self->type) {
    my $lr = $self->linked_records(direction => 'from', recursive => 1);
    $lr    = [grep { 'SL::DB::Order' eq ref $_ && !$_->closed && $_->is_type(SALES_ORDER_INTAKE_TYPE()) } @$lr];
    if (@$lr) {
      SL::DB::Manager::Order->update_all(set   => {closed => 1},
                                         where => [id => [map {$_->id} @$lr]]);
    }
  }

  return 1;
}

sub _before_save_delete_from_purchase_basket {
  my ($self) = @_;

  my @basket_item_ids =
    grep { defined($_) && $_ ne ''}
    map { $_->{basket_item_id} }
    $self->orderitems;
  return 1 unless scalar @basket_item_ids;

  # check if all items are still in the basket
  my $basket_item_count = SL::DB::Manager::PurchaseBasketItem->get_all_count(
    where => [ id => \@basket_item_ids ]
  );
  if ($basket_item_count != scalar @basket_item_ids) {
    die "Error while saving order: some items are not in the purchase basket anymore.";
  }

  if (scalar @basket_item_ids) {
    SL::DB::Manager::PurchaseBasketItem->delete_all(
      where => [ id => \@basket_item_ids]
    );
  }

  return 1;
}

# methods

sub items { goto &orderitems; }
sub add_items { goto &add_orderitems; }
sub record_number { goto &number; }

sub type {
  my $self = shift;
  SL::DB::Order::TypeData::validate_type($self->record_type);
  return $self->record_type;
}

sub is_type {
  return shift->type eq shift;
}

sub quotation {
  my $type = $_[0]->type();
  any { $type eq $_ } (
    SALES_ORDER_INTAKE_TYPE(),
    SALES_QUOTATION_TYPE(),
    REQUEST_QUOTATION_TYPE(),
    PURCHASE_QUOTATION_INTAKE_TYPE(),
  );
}

sub intake {
  my $type = $_[0]->type();
  any { $type eq $_ } (
    SALES_ORDER_INTAKE_TYPE(),
    PURCHASE_QUOTATION_INTAKE_TYPE(),
  );
}

sub deliverydate {
  # oe doesn't have deliverydate, but it does have reqdate.
  # But this has a different meaning for sales quotations.
  # deliverydate can be used to determine tax if tax_point isn't set.

  return $_[0]->reqdate if $_[0]->type ne SALES_QUOTATION_TYPE();
}

sub effective_tax_point {
  my ($self) = @_;

  return $self->tax_point || $self->deliverydate || $self->transdate;
}

sub displayable_type {
  my ($self) = @_;
  return $self->type_data->text('type');
}

sub displayable_name {
  join ' ', grep $_, map $_[0]->$_, qw(displayable_type record_number);
};

sub is_sales {
  croak 'not an accessor' if @_ > 1;
  $_[0]->type_data->properties('is_customer');
}

sub daily_exchangerate {
  my ($self, $val) = @_;

  return 1 if $self->currency_id == $::instance_conf->get_currency_id;

  my $rate = (any { $self->is_type($_) } (SALES_QUOTATION_TYPE(), SALES_ORDER_TYPE()))      ? 'buy'
           : (any { $self->is_type($_) } (REQUEST_QUOTATION_TYPE(), PURCHASE_ORDER_TYPE())) ? 'sell'
           : undef;
  return if !$rate;

  if (defined $val) {
    croak t8('exchange rate has to be positive') if $val <= 0;
    if (!$self->exchangerate_obj) {
      $self->exchangerate_obj(SL::DB::Exchangerate->new(
        currency_id => $self->currency_id,
        transdate   => $self->transdate,
        $rate       => $val,
      ));
    } elsif (!defined $self->exchangerate_obj->$rate) {
      $self->exchangerate_obj->$rate($val);
    } else {
      croak t8('exchange rate already exists, no update allowed');
    }
  }
  return $self->exchangerate_obj->$rate if $self->exchangerate_obj;
}

sub invoices {
  my $self   = shift;
  my %params = @_;

  if ($self->quotation) {
    return [];
  } else {
    require SL::DB::Invoice;
    return SL::DB::Manager::Invoice->get_all(
      query => [
        ordnumber => $self->ordnumber,
        @{ $params{query} || [] },
      ]
    );
  }
}

sub displayable_state {
  my ($self) = @_;

  return $self->closed ? $::locale->text('closed') : $::locale->text('open');
}

sub abschlag_invoices {
  return shift()->invoices(query => [ abschlag => 1 ]);
}

sub end_invoice {
  return shift()->invoices(query => [ abschlag => 0 ]);
}

sub convert_to_invoice {
  my ($self, %params) = @_;

  croak("Conversion to invoices is only supported for sales records") unless $self->customer_id;

  my $invoice;
  if (!$self->db->with_transaction(sub {
    require SL::DB::Invoice;
    $invoice = SL::DB::Invoice->new_from($self, %params)->post || die;
    $self->update_attributes(closed => 1);
    1;
  })) {
    return undef;
  }

  return $invoice;
}

sub convert_to_delivery_order {
  my ($self, @args) = @_;

  my $delivery_order;
  if (!$self->db->with_transaction(sub {
    require SL::DB::DeliveryOrder;
    $delivery_order = SL::DB::DeliveryOrder->new_from($self, @args);
    $delivery_order->save;

    $self->update_attributes(delivered => 1) unless $::instance_conf->get_shipped_qty_require_stock_out;
    1;
  })) {
    return undef;
  }

  return $delivery_order;
}

sub convert_to_reclamation {
  my ($self, %params) = @_;
  $params{destination_type} = $self->is_sales ? SALES_RECLAMATION_TYPE()
                                              : PURCHASE_RECLAMATION_TYPE();

  require SL::DB::Reclamation;
  my $reclamation = SL::DB::Reclamation->new_from($self, %params);

  return $reclamation;
}

sub _clone_orderitem_cvar {
  my ($cvar) = @_;

  my $cloned = $_->clone_and_reset;
  $cloned->sub_module('orderitems');

  return $cloned;
}

sub create_from_purchase_basket {
  my ($class, $basket_item_ids, $vendor_item_ids, $vendor_id) = @_;

  my ($vendor, $employee);
  $vendor   = SL::DB::Manager::Vendor->find_by(id => $vendor_id);
  $employee = SL::DB::Manager::Employee->current;

  my @orderitem_maps = (); # part, qty, orderer_id
  if ($basket_item_ids && scalar @{ $basket_item_ids}) {
    my $basket_items = SL::DB::Manager::PurchaseBasketItem->get_all(
      query => [ id => $basket_item_ids ],
      with_objects => ['part'],
    );
    push @orderitem_maps, map {{
        basket_item_id => $_->id,
        part       => $_->part,
        qty        => $_->qty,
        orderer_id => $_->orderer_id,
      }} @{$basket_items};
  }
  if ($vendor_item_ids && scalar @{ $vendor_item_ids}) {
    my $vendor_items = SL::DB::Manager::Part->get_all(
      query => [ id => $vendor_item_ids ] );
    push @orderitem_maps, map {{
        basket_item_id => undef,
        part       => $_,
        qty        => $_->order_qty || 1,
        orderer_id => $employee->id,
      }} @{$vendor_items};
  }

  my $order = $class->new(
    vendor_id               => $vendor->id,
    employee_id             => $employee->id,
    intnotes                => $vendor->notes,
    salesman_id             => $employee->id,
    payment_id              => $vendor->payment_id,
    delivery_term_id        => $vendor->delivery_term_id,
    taxzone_id              => $vendor->taxzone_id,
    currency_id             => $vendor->currency_id,
    transdate               => DateTime->today_local,
    record_type             => PURCHASE_ORDER_TYPE(),
  );

  my @order_items;
  my $i = 0;
  foreach my $orderitem_map (@orderitem_maps) {
    $i++;
    my $part = $orderitem_map->{part};
    my $qty = $orderitem_map->{qty};
    my $orderer_id = $orderitem_map->{orderer_id};

    my $order_item = SL::DB::OrderItem->new(
      part                => $part,
      qty                 => $qty,
      unit                => $part->unit,
      description         => $part->description,
      price_factor_id     => $part->price_factor_id,
      price_factor        =>
        $part->price_factor_id ? $part->price_factor->factor
                               : '',
      orderer_id          => $orderer_id,
      position            => $i,
    );
    $order_item->{basket_item_id} = $orderitem_map->{basket_item_id};

    my $price_source  = SL::PriceSource->new(
      record_item => $order_item, record => $order);
    $order_item->sellprice(
      $price_source->best_price ? $price_source->best_price->price
                                : 0);
    $order_item->active_price_source(
      $price_source->best_price ? $price_source->best_price->source
                                : '');
    push @order_items, $order_item;
  }

  $order->assign_attributes(orderitems => \@order_items);

  $order->calculate_prices_and_taxes;

  foreach my $item(@{ $order->orderitems }){
    $item->parse_custom_variable_values;
    $item->{custom_variables} = \@{ $item->cvars_by_config };
  }

  return $order;
}

sub new_from {
  my ($class, $source, %params) = @_;

  unless (any {ref($source) eq $_} qw(
    SL::DB::Order
    SL::DB::Reclamation
  )) {
    croak("Unsupported source object type '" . ref($source) . "'");
  }
  croak("A destination type must be given as parameter")         unless $params{destination_type};

  my $destination_type  = delete $params{destination_type};

  my @from_tos = (
    { from => SALES_QUOTATION_TYPE(),             to => SALES_ORDER_TYPE(),                 abbr => 'sqso'   },
    { from => REQUEST_QUOTATION_TYPE(),           to => PURCHASE_ORDER_TYPE(),              abbr => 'rqpo'   },
    { from => SALES_QUOTATION_TYPE(),             to => SALES_QUOTATION_TYPE(),             abbr => 'sqsq'   },
    { from => SALES_ORDER_TYPE(),                 to => SALES_ORDER_TYPE(),                 abbr => 'soso'   },
    { from => REQUEST_QUOTATION_TYPE(),           to => REQUEST_QUOTATION_TYPE(),           abbr => 'rqrq'   },
    { from => PURCHASE_ORDER_TYPE(),              to => PURCHASE_ORDER_TYPE(),              abbr => 'popo'   },
    { from => SALES_ORDER_TYPE(),                 to => PURCHASE_ORDER_TYPE(),              abbr => 'sopo'   },
    { from => PURCHASE_ORDER_TYPE(),              to => SALES_ORDER_TYPE(),                 abbr => 'poso'   },
    { from => SALES_ORDER_TYPE(),                 to => SALES_QUOTATION_TYPE(),             abbr => 'sosq'   },
    { from => PURCHASE_ORDER_TYPE(),              to => REQUEST_QUOTATION_TYPE(),           abbr => 'porq'   },
    { from => REQUEST_QUOTATION_TYPE(),           to => SALES_QUOTATION_TYPE(),             abbr => 'rqsq'   },
    { from => REQUEST_QUOTATION_TYPE(),           to => SALES_ORDER_TYPE(),                 abbr => 'rqso'   },
    { from => SALES_QUOTATION_TYPE(),             to => REQUEST_QUOTATION_TYPE(),           abbr => 'sqrq'   },
    { from => SALES_ORDER_TYPE(),                 to => REQUEST_QUOTATION_TYPE(),           abbr => 'sorq'   },
    { from => SALES_RECLAMATION_TYPE(),           to => SALES_ORDER_TYPE(),                 abbr => 'srso'   },
    { from => PURCHASE_RECLAMATION_TYPE(),        to => PURCHASE_ORDER_TYPE(),              abbr => 'prpo'   },
    { from => SALES_ORDER_INTAKE_TYPE(),          to => SALES_ORDER_INTAKE_TYPE(),          abbr => 'soisoi' },
    { from => SALES_ORDER_INTAKE_TYPE(),          to => SALES_QUOTATION_TYPE(),             abbr => 'soisq'  },
    { from => SALES_ORDER_INTAKE_TYPE(),          to => REQUEST_QUOTATION_TYPE(),           abbr => 'soirq'  },
    { from => SALES_ORDER_INTAKE_TYPE(),          to => SALES_ORDER_TYPE(),                 abbr => 'soiso'  },
    { from => SALES_ORDER_INTAKE_TYPE(),          to => PURCHASE_ORDER_TYPE(),              abbr => 'soipo'  },
    { from => SALES_QUOTATION_TYPE(),             to => SALES_ORDER_INTAKE_TYPE(),          abbr => 'sqsoi'  },
    { from => PURCHASE_QUOTATION_INTAKE_TYPE(),   to => PURCHASE_QUOTATION_INTAKE_TYPE(),   abbr => 'pqipqi' },
    { from => PURCHASE_QUOTATION_INTAKE_TYPE(),   to => SALES_QUOTATION_TYPE(),             abbr => 'pqisq'  },
    { from => PURCHASE_QUOTATION_INTAKE_TYPE(),   to => SALES_ORDER_TYPE(),                 abbr => 'pqiso'  },
    { from => PURCHASE_QUOTATION_INTAKE_TYPE(),   to => PURCHASE_ORDER_TYPE(),              abbr => 'pqipo'  },
    { from => REQUEST_QUOTATION_TYPE(),           to => PURCHASE_QUOTATION_INTAKE_TYPE(),   abbr => 'rqpqi'  },
    { from => PURCHASE_ORDER_CONFIRMATION_TYPE(), to => PURCHASE_ORDER_CONFIRMATION_TYPE(), abbr => 'pocpoc' },
    { from => PURCHASE_ORDER_CONFIRMATION_TYPE(), to => SALES_QUOTATION_TYPE(),             abbr => 'pocsq' },
    { from => PURCHASE_ORDER_CONFIRMATION_TYPE(), to => SALES_ORDER_TYPE(),                 abbr => 'pocso' },
    { from => PURCHASE_ORDER_CONFIRMATION_TYPE(), to => PURCHASE_ORDER_TYPE(),              abbr => 'pocpo' },
    { from => PURCHASE_ORDER_TYPE(),              to => PURCHASE_ORDER_CONFIRMATION_TYPE(), abbr => 'popoc' },
  );
  my $from_to = (grep { $_->{from} eq $source->record_type && $_->{to} eq $destination_type} @from_tos)[0];
  croak("Cannot convert from '" . $source->record_type . "' to '" . $destination_type . "'") if !$from_to;

  my $is_abbr_any = sub {
    my (@abbrs) = @_;

    my $missing_abbr;
    if (any { $missing_abbr = $_; !grep { $_->{abbr} eq $missing_abbr } @from_tos } @abbrs) {
      die "no such workflow abbreviation '$missing_abbr'";
    }

    any { $from_to->{abbr} eq $_ } @abbrs;
  };

  my %args;
  if (ref($source) eq 'SL::DB::Order') {
    %args = ( map({ ( $_ => $source->$_ ) } qw(amount cp_id currency_id cusordnumber customer_id delivery_customer_id delivery_term_id delivery_vendor_id
                                               department_id exchangerate globalproject_id intnotes marge_percent marge_total language_id netamount notes
                                               ordnumber payment_id quonumber reqdate salesman_id shippingpoint shipvia taxincluded tax_point taxzone_id
                                               transaction_description vendor_id billing_address_id
                                            )),
                 closed    => 0,
                 delivered => 0,
                 transdate => DateTime->today_local,
                 employee  => SL::DB::Manager::Employee->current,
              );
    # reqdate in quotation is 'offer is valid    until reqdate'
    # reqdate in order     is 'will be delivered until reqdate'
    # both dates are setable (on|off)
    # and may have a additional interval in days (+ n days)
    # dies if this convention will change
    $args{reqdate} = $from_to->{to} =~ m/_quotation$/
                   ? $::instance_conf->get_reqdate_on
                   ? DateTime->today_local->next_workday(extra_days => $::instance_conf->get_reqdate_interval)->to_kivitendo
                   : undef
                   : $from_to->{to} =~ m/_order$/
                   ? $::instance_conf->get_deliverydate_on
                   ? DateTime->today_local->next_workday(extra_days => $::instance_conf->get_delivery_date_interval)->to_kivitendo
                   : undef
                   : $from_to->{to} =~ m/^sales_order_intake$/
                   # ? $source->reqdate
                   ? undef
                   : $from_to->{to} =~ m/^purchase_quotation_intake$/
                   ? $source->reqdate
                   : $from_to->{to} =~ m/^purchase_order_confirmation$/
                   ? $source->reqdate
                   : die "Wrong state for reqdate";
  } elsif ( ref($source) eq 'SL::DB::Reclamation') {
    %args = ( map({ ( $_ => $source->$_ ) } qw(
        amount billing_address_id currency_id customer_id delivery_term_id department_id
        exchangerate globalproject_id intnotes language_id netamount
        notes payment_id  reqdate salesman_id shippingpoint shipvia taxincluded
        tax_point taxzone_id transaction_description vendor_id
      )),
      cp_id     => $source->{contact_id},
      closed    => 0,
      delivered => 0,
      transdate => DateTime->today_local,
      employee  => SL::DB::Manager::Employee->current,
   );
  }

  if ( $is_abbr_any->(qw(soipo sopo poso rqso soisq sosq porq rqsq sqrq soirq sorq pqisq pqiso pocsq pocso)) ) {
    $args{ordnumber} = undef;
    $args{quonumber} = undef;
  }
  if ( $is_abbr_any->(qw(soipo sopo sqrq soirq sorq)) ) {
    $args{customer_id}      = undef;
    $args{salesman_id}      = undef;
    $args{payment_id}       = undef;
    $args{delivery_term_id} = undef;
  }
  if ( $is_abbr_any->(qw(poso rqsq pqisq pqiso pocsq pocso)) ) {
    $args{vendor_id} = undef;
  }
  if ( $is_abbr_any->(qw(soso)) ) {
    if ($source->periodic_invoices_config) {
      $args{periodic_invoices_config} = $source->periodic_invoices_config->clone_and_reset;

      if ($args{periodic_invoices_config}->active == 1) {
        $args{periodic_invoices_config}->active(0);
        flash_later('info', $::locale->text('Periodic invoices config set to inactive.'));
      }
    }
  }
  if ( $is_abbr_any->(qw(sqrq soirq sorq)) ) {
    $args{cusordnumber} = undef;
  }
  if ( $is_abbr_any->(qw(soiso pocpoc pocpo popoc)) ) {
    $args{ordnumber} = undef;
  }
  if ( $is_abbr_any->(qw(rqpqi pqisq)) ) {
    $args{quonumber} = undef;
  }

  # Custom shipto addresses (the ones specific to the sales/purchase
  # record and not to the customer/vendor) are only linked from
  # shipto → order. Meaning order.shipto_id
  # will not be filled in that case.
  if (!$source->shipto_id && $source->id) {
    $args{custom_shipto} = $source->custom_shipto->clone($class) if $source->can('custom_shipto') && $source->custom_shipto;

  } else {
    $args{shipto_id} = $source->shipto_id;
  }

  $args{record_type} = $destination_type;

  my $order = $class->new(%args);
  $order->assign_attributes(%{ $params{attributes} }) if $params{attributes};
  my $items = delete($params{items}) || $source->items_sorted;

  my @items = map {
    my $source_item      = $_;
    my @custom_variables = map { _clone_orderitem_cvar($_) } @{ $source_item->custom_variables };

    my $current_oe_item;
    if (ref($source) eq 'SL::DB::Order') {
      $current_oe_item = SL::DB::OrderItem->new(map({ ( $_ => $source_item->$_ ) }
                                                       qw(active_discount_source active_price_source base_qty cusordnumber
                                                          description discount lastcost longdescription
                                                          marge_percent marge_price_factor marge_total
                                                          ordnumber parts_id price_factor price_factor_id pricegroup_id
                                                          project_id qty reqdate sellprice serialnumber ship subtotal transdate unit
                                                          optional recurring_billing_mode position
                                                       )),
                                                   custom_variables => \@custom_variables,
      );
    } elsif (ref($source) eq 'SL::DB::Reclamation') {
      $current_oe_item = SL::DB::OrderItem->new(
        map({ ( $_ => $source_item->$_ ) } qw(
          active_discount_source active_price_source base_qty description
          discount lastcost longdescription parts_id price_factor
          price_factor_id pricegroup_id project_id qty reqdate sellprice
          serialnumber unit position
        )),
        custom_variables => \@custom_variables,
      );
    }
    if ( $is_abbr_any->(qw(soipo sopo)) ) {
      $current_oe_item->sellprice($source_item->lastcost);
      $current_oe_item->discount(0);
    }
    if ( $is_abbr_any->(qw(poso rqsq rqso pqisq pqiso pocsq pocso)) ) {
      $current_oe_item->lastcost($source_item->sellprice);
    }
    unless ($params{no_linked_records}) {
      $current_oe_item->{ RECORD_ITEM_ID() } = $source_item->{id};
      $current_oe_item->{ RECORD_ITEM_TYPE_REF() } = ref($source_item);
    }
    $current_oe_item;
  } @{ $items };

  @items = grep { $params{item_filter}->($_) } @items if $params{item_filter};
  @items = grep { $_->qty * 1 } @items if $params{skip_items_zero_qty};
  @items = grep { $_->qty >=0 } @items if $params{skip_items_negative_qty};

  $order->items(\@items);

  unless ($params{no_linked_records}) {
    $order->{ RECORD_ID()       } = $source->{id};
    $order->{ RECORD_TYPE_REF() } = ref($source);
  }

  return $order;
}

sub new_from_multi {
  my ($class, $sources, %params) = @_;

  croak("Unsupported object type in sources")                             if any { ref($_) !~ m{SL::DB::Order} }                   @$sources;
  croak("Cannot create order for purchase records")                       if any { !$_->is_sales }                                 @$sources;
  croak("Cannot create order from source records of different customers") if any { $_->customer_id != $sources->[0]->customer_id } @$sources;

  # bb: todo: check shipto: is it enough to check the ids or do we have to compare the entries?
  if (delete $params{check_same_shipto}) {
    die "check same shipto address is not implemented yet";
    die "Source records do not have the same shipto"        if 1;
  }

  # sort sources
  if (defined $params{sort_sources_by}) {
    my $sort_by = delete $params{sort_sources_by};
    if ($sources->[0]->can($sort_by)) {
      $sources = [ sort { $a->$sort_by cmp $b->$sort_by } @$sources ];
    } else {
      die "Cannot sort source records by $sort_by";
    }
  }

  # set this entries to undef that yield different information
  my %attributes;
  foreach my $attr (qw(ordnumber transdate reqdate tax_point taxincluded shippingpoint
                       shipvia notes closed delivered reqdate quonumber
                       cusordnumber proforma transaction_description
                       order_probability expected_billing_date)) {
    $attributes{$attr} = undef if any { ($sources->[0]->$attr//'') ne ($_->$attr//'') } @$sources;
  }
  foreach my $attr (qw(cp_id currency_id salesman_id department_id
                       delivery_customer_id delivery_vendor_id shipto_id
                       globalproject_id exchangerate)) {
    $attributes{$attr} = undef if any { ($sources->[0]->$attr||0) != ($_->$attr||0) }   @$sources;
  }

  # set this entries from customer that yield different information
  foreach my $attr (qw(language_id taxzone_id payment_id delivery_term_id)) {
    $attributes{$attr}  = $sources->[0]->customervendor->$attr if any { ($sources->[0]->$attr||0)     != ($_->$attr||0) }      @$sources;
  }
  $attributes{intnotes} = $sources->[0]->customervendor->notes if any { ($sources->[0]->intnotes//'') ne ($_->intnotes//'')  } @$sources;

  # no periodic invoice config for new order
  $attributes{periodic_invoices_config} = undef;

  # set emplyee to the current one
  $attributes{employee} = SL::DB::Manager::Employee->current;

  # copy global ordnumber, transdate, cusordnumber into item scope
  #   unless already present there
  foreach my $attr (qw(ordnumber transdate cusordnumber)) {
    foreach my $src (@$sources) {
      foreach my $item (@{ $src->items_sorted }) {
        $item->$attr($src->$attr) if !$item->$attr;
      }
    }
  }

  # collect items
  my @items;
  push @items, @{$_->items_sorted} for @$sources;
  # make order from first source and all items
  my $order = $class->new_from($sources->[0],
                               destination_type => SALES_ORDER_TYPE(),
                               attributes       => \%attributes,
                               items            => \@items,
                               %params);
  $order->{RECORD_ID()} = join ' ', map { $_->id } @$sources; # link all sources

  return $order;
}

sub number {
  my $self = shift;

  my $nr_key = $self->type_data->properties('nr_key');
  return $self->$nr_key(@_);
}

sub customervendor {
  $_[0]->type_data->properties('is_customer') ? $_[0]->customer : $_[0]->vendor;
}

sub date {
  goto &transdate;
}

sub digest {
  my ($self) = @_;

  sprintf "%s %s %s (%s)",
    $self->number,
    $self->customervendor->name,
    $self->amount_as_number,
    $self->date->to_kivitendo;
}

sub current_version_number {
  my ($self) = @_;

  my $query = <<EOSQL;
    SELECT max(version)
    FROM oe_version
    WHERE (oe_id = ?)
EOSQL

  my ($current_version_number) = SL::DBUtils::selectfirst_array_query($::form, $self->db->dbh, $query, ($self->id));
  die "Invalid State. No version linked" unless $current_version_number;

  return $current_version_number;
}

sub is_final_version {
  my ($self) = @_;

  my $order_versions_count = SL::DB::Manager::OrderVersion->get_all_count(where => [ oe_id => $self->id, final_version => 0 ]);
  die "Invalid version state" unless $order_versions_count < 2;
  my $final_version = $order_versions_count == 1 ? 0 : 1;

  return $final_version;
}

sub increment_version_number {
  my ($self) = @_;

  die t8('This sub-version is not yet finalized') if !$self->is_final_version;

  my $current_version_number = $self->current_version_number;
  my $new_version_number     = $current_version_number + 1;

  my $new_number = $self->number;
  $new_number    =~ s/-$current_version_number$//;
  $self->number($new_number . '-' . $new_version_number);
  $self->add_order_version(SL::DB::OrderVersion->new(version => $new_version_number));
}

sub netamount_base_currency {
  my ($self) = @_;

  return $self->netamount unless $self->forex;

  if ( defined $self->exchangerate ) {
    return $self->netamount * $self->exchangerate;
  } else {
    return $self->netamount * $self->daily_exchangerate;
  }
}

sub preceding_purchase_orders {
  my ($self) = @_;

  my @lrs = ();
  if ($self->id) {
    @lrs = grep { $_->record_type eq PURCHASE_ORDER_TYPE() } @{$self->linked_records(from => 'SL::DB::Order')};
  } else {
    if ('SL::DB::Order' eq $self->{RECORD_TYPE_REF()}) {
      my $order = SL::DB::Order->load_cached($self->{RECORD_ID()});
      push @lrs, $order if $order->record_type eq PURCHASE_ORDER_TYPE();
    }
  }

  return \@lrs;
}

sub type_data {
  SL::DB::Helper::TypeDataProxy->new(ref $_[0], $_[0]->type);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Order - Order Datenbank Objekt.

=head1 FUNCTIONS

=head2 C<type>

Returns one of the following string types:

=over 4

=item sales_order

=item purchase_order

=item sales_quotation

=item request_quotation

=back

=head2 C<is_type TYPE>

Returns true if the order is of the given type.

=head2 C<daily_exchangerate $val>

Gets or sets the exchangerate object's value. This is the value from the
table C<exchangerate> depending on the order's currency, the transdate and
if it is a sales or purchase order.

The order object (respectively the table C<oe>) has an own column
C<exchangerate> which can be get or set with the accessor C<exchangerate>.

The idea is to drop the legacy table C<exchangerate> in the future and to
give all relevant tables it's own C<exchangerate> column.

So, this method is here if you need to access the "legacy" exchangerate via
an order object.

=over 4

=item C<$val>

(optional) If given, the exchangerate in the "legacy" table is set to this
value, depending on currency, transdate and sales or purchase.

=back

=head2 C<convert_to_delivery_order %params>

Creates a new delivery order with C<$self> as the basis by calling
L<SL::DB::DeliveryOrder::new_from>. That delivery order is saved, and
C<$self> is linked to the new invoice via
L<SL::DB::RecordLink>. C<$self>'s C<delivered> attribute is set to
C<true>, and C<$self> is saved.

The arguments in C<%params> are passed to
L<SL::DB::DeliveryOrder::new_from>.

Returns C<undef> on failure. Otherwise the new delivery order will be
returned.

=head2 C<convert_to_invoice %params>

Creates a new invoice with C<$self> as the basis by calling
L<SL::DB::Invoice::new_from>. That invoice is posted, and C<$self> is
linked to the new invoice via L<SL::DB::RecordLink>. C<$self>'s
C<closed> attribute is set to C<true>, and C<$self> is saved.

The arguments in C<%params> are passed to L<SL::DB::Invoice::new_from>.

Returns the new invoice instance on success and C<undef> on
failure. The whole process is run inside a transaction. On failure
nothing is created or changed in the database.

At the moment only sales quotations and sales orders can be converted.

=head2 C<new_from $source, %params>

Creates a new C<SL::DB::Order> instance and copies as much
information from C<$source> as possible. At the moment only records with the
same destination type as the source type and sales orders from
sales quotations and purchase orders from requests for quotations can be
created.

The C<transdate> field will be set to the current date.

The conversion copies the order items as well.

Returns the new order instance. The object returned is not
saved.

C<%params> can include the following options
(C<destination_type> is mandatory):

=over 4

=item C<destination_type>

(mandatory)
The type of the newly created object. Can be C<sales_quotation>,
C<sales_order>, C<purchase_quotation> or C<purchase_order> for now.

=item C<items>

An optional array reference of RDBO instances for the items to use. If
missing then the method C<items_sorted> will be called on
C<$source>. This option can be used to override the sorting, to
exclude certain positions or to add additional ones.

=item C<skip_items_negative_qty>

If trueish then items with a negative quantity are skipped. Items with
a quantity of 0 are not affected by this option.

=item C<skip_items_zero_qty>

If trueish then items with a quantity of 0 are skipped.

=item C<item_filter>

An optional code reference that is called for each item with the item
as its sole parameter. Items for which the code reference returns a
falsish value will be skipped.

=item C<attributes>

An optional hash reference. If it exists then it is passed to C<new>
allowing the caller to set certain attributes for the new delivery
order.

=back

=head2 C<new_from_multi $sources, %params>

Creates a new C<SL::DB::Order> instance from multiple sources and copies as
much information from C<$sources> as possible.
At the moment only sales orders can be combined and they must be of the same
customer.

The new order is created from the first one using C<new_from> and the positions
of all orders are added to the new order. The orders can be sorted with the
parameter C<sort_sources_by>.

The orders attributes are kept if they contain the same information for all
source orders an will be set to empty if they contain different information.

Returns the new order instance. The object returned is not
saved.

C<params> other then C<sort_sources_by> are passed to C<new_from>.

=head2 C<increment_version_number>

Checks if the current version of the order is finalized, increments
the version number and adds a new order_version to the order.
Dies if the version is not final.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling <s.schoeling@linet-services.de>

=cut
