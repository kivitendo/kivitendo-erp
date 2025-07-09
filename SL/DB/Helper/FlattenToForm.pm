package SL::DB::Helper::FlattenToForm;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(flatten_to_form prepare_stock_info);

use List::MoreUtils qw(uniq any);

sub flatten_to_form {
  my ($self, $form, %params) = @_;

  my $vc = $self->can('customer_id') && $self->customer_id ? 'customer' : 'vendor';

  _copy($self, $form, '', '', 0, qw(id type taxzone_id ordnumber quonumber invnumber donumber cusordnumber taxincluded shippingpoint shipvia notes intnotes cp_id
                                    employee_id salesman_id closed department_id language_id payment_id delivery_customer_id delivery_vendor_id shipto_id proforma
                                    globalproject_id delivered transaction_description container_type accepted_by_customer invoice storno storno_id dunning_config_id
                                    orddate quodate reqdate gldate duedate deliverydate datepaid transdate tax_point delivery_term_id billing_address_id
                                    vendor_confirmation_number));
  $form->{currency} = $form->{curr} = $self->currency_id ? $self->currency->name || '' : '';

  if ( $vc eq 'customer' ) {
    $form->{customer_id} = $self->customer_id;
    $form->{customer}    = $self->customer->name if $self->customer;
  } else {
    $form->{vendor_id}   = $self->vendor_id;
    $form->{vendor}      = $self->vendor->name if $self->vendor;
  };

  if (_has($self, 'transdate')) {
    my $transdate_idx = ref($self) eq 'SL::DB::Order'         ? ($self->quotation ? 'quodate' : 'orddate')
                      : ref($self) eq 'SL::DB::Invoice'       ? 'invdate'
                      : ref($self) eq 'SL::DB::DeliveryOrder' ? 'dodate'
                      :                                         'transdate';
    $form->{$transdate_idx} = $self->transdate->to_lxoffice;
  }

  $form->{vc} = $vc if ref($self) =~ m{^SL::DB::(?:.*Invoice|.*Order)};

  my @vc_fields          = (qw(account_number bank bank_code bic business city contact country creditlimit
                               department_1 department_2 discount email fax gln greeting homepage iban language name
                               natural_person phone street taxnumber ustid zipcode),
                            "${vc}number",
                            ($vc eq 'customer')? qw(c_vendor_id c_vendor_routing_id): 'v_customer_id');
  my @vc_prefixed_fields = qw(email fax notes number phone);

  _copy($self,                          $form, '',              '', 1, qw(amount netamount marge_total marge_percent container_remaining_weight container_remaining_volume paid exchangerate));
  _copy($self->$vc,                     $form, '',              '', 0, @vc_fields);
  _copy($self->$vc,                     $form, $vc,             '', 0, @vc_prefixed_fields);
  _copy($self->contact,                 $form, '',              '', 0, grep { /^cp_/    } map { $_->name } SL::DB::Contact->meta->columns) if _has($self, 'cp_id');
  _copy($self->globalproject,           $form, 'globalproject', '', 0, qw(number description))                                             if _has($self, 'globalproject_id');
  _copy($self->employee,                $form, 'employee_',     '', 0, map { $_->name } SL::DB::Employee->meta->columns)                   if _has($self, 'employee_id');
  _copy($self->salesman,                $form, 'salesman_',     '', 0, map { $_->name } SL::DB::Employee->meta->columns)                   if _has($self, 'salesman_id');
  _copy($self->acceptance_confirmed_by, $form, 'acceptance_confirmed_by_', '', 0, map { $_->name } SL::DB::Employee->meta->columns)        if _has($self, 'acceptance_confirmed_by_id');

  # Copy selected shipto to form, if set. Else, copy custom shipto, if set.
  my $shipto = _has($self, 'shipto_id')     ? $self->shipto
             : _has($self, 'custom_shipto') ? $self->custom_shipto
             : undef;
  if ($shipto) {
    _copy($shipto,                  $form, '',            '', 0, grep { m{^shipto(?!_id$)} } map { $_->name } SL::DB::Shipto->meta->columns);
    _copy_custom_variables($shipto, $form, 'shiptocvar_', '');
  }

  _handle_user_data($self, $form);

  # company is employee and login independent
  $form->{"${_}_company"}  = $::instance_conf->get_company for qw (employee salesman);

  $form->{employee}   = $self->employee->name          if _has($self, 'employee_id');
  $form->{language}   = $self->language->template_code if _has($self, 'language_id');
  $form->{department} = $self->department->description if _has($self, 'department_id');
  $form->{business}   = $self->$vc->business->description if _has($self->$vc, 'business_id');
  $form->{rowcount}   = scalar(@{ $self->items });

  my $items_name = ref($self) eq 'SL::DB::Order'         ? 'orderitems'
                 : ref($self) eq 'SL::DB::DeliveryOrder' ? 'delivery_order_items'
                 : ref($self) eq 'SL::DB::Invoice'       ? 'invoice'
                 : ref($self) eq 'SL::DB::Reclamation'   ? 'reclamation_items'
                 : '';

  my %cvar_validity = _determine_cvar_validity($self, $vc);

  my $idx = 0;
  my $format_amounts = $params{format_amounts} ? 1 : 0;
  my $format_notnull = $params{format_amounts} ? 2 : 0;
  my $format_percent = $params{format_amounts} ? 3 : 0;
  my $format_noround = $params{format_amounts} ? 4 : 0;
  foreach my $item (@{ $self->items_sorted }) {
    next if _has($item, 'assemblyitem');

    $idx++;

    $form->{"std_warehouse_${idx}"} = $item->part->warehouse->description if _has($item->part, 'warehouse_id');
    $form->{"std_bin_${idx}"}       = $item->part->bin->description       if _has($item->part, 'bin_id');
    $form->{"partsgroup_${idx}"}    = $item->part->partsgroup->partsgroup if _has($item->part, 'partsgroup_id');
    _copy($item,          $form, "${items_name}_", "_${idx}", 0,               qw(id)) if $items_name;
    # TODO: is part_type correct here? Do we need to set part_type as default?
    _copy($item->part,    $form, '',               "_${idx}", 0,               qw(id partnumber weight part_type));
    _copy($item->part,    $form, '',               "_${idx}", 0,               qw(listprice));
    _copy($item,          $form, '',               "_${idx}", 0,               qw(description project_id ship serialnumber pricegroup_id ordnumber donumber cusordnumber unit
                                                                                  subtotal longdescription price_factor_id marge_price_factor reqdate transdate
                                                                                  active_price_source active_discount_source optional));
    _copy($item,          $form, '',              "_${idx}", $format_noround, qw(qty sellprice fxsellprice));
    _copy($item,          $form, '',              "_${idx}", $format_amounts, qw(marge_total marge_percent lastcost));
    _copy($item,          $form, '',              "_${idx}", $format_percent, qw(discount));
    _copy($item->project, $form, 'project',       "_${idx}", 0,               qw(number description)) if _has($item, 'project_id');

    _copy_custom_variables($item, $form, 'ic_cvar_', "_${idx}", $cvar_validity{items}->{ $item->parts_id });

    if (ref($self) eq 'SL::DB::Invoice') {
      my $date                          = $item->deliverydate ? $item->deliverydate->to_lxoffice : undef;
      $form->{"deliverydate_oe_${idx}"} = $date;
      $form->{"reqdate_${idx}"}         = $date;
    }
    if (ref($self) eq 'SL::DB::DeliveryOrder'){
      my $in_out   = $form->{type} =~ /^sales|^supplier/ ? 'out' : 'in';
      $form->{"stock_" . $in_out . "_" . ${idx}} = prepare_stock_info($self,$item);
    }
  }

  _copy_custom_variables($self, $form, 'vc_cvar_', '', $cvar_validity{vc});
  _copy_custom_variables($self->contact, $form, 'cp_cvar_', '') if $self->contact;

  return $self;
}

sub prepare_stock_info {
  my ($self, $item) = @_;

  $item->{stock_info} = SL::YAML::Dump([
    map +{
      delivery_order_items_stock_id => $_->id,
      qty                           => $_->qty,
      warehouse_id                  => $_->warehouse_id,
      bin_id                        => $_->bin_id,
      chargenumber                  => $_->chargenumber,
      unit                          => $_->unit,
    }, $item->delivery_order_stock_entries
  ]);
}

sub _has {
  my ($obj, $column) = @_;
  return $obj->can($column) && $obj->$column;
}

sub _copy {
  my ($src, $form, $prefix, $postfix, $format_amounts, @columns) = @_;

  @columns = grep { $src->can($_) } @columns;

  map { $form->{"${prefix}${_}${postfix}"} = ref($src->$_) eq 'DateTime' ? $src->$_->to_lxoffice : $src->$_             } @columns if !$format_amounts;
  map { $form->{"${prefix}${_}${postfix}"} =                $::form->format_amount(\%::myconfig, $src->$_ * 1,   2)     } @columns if  $format_amounts == 1;
  map { $form->{"${prefix}${_}${postfix}"} = $src->$_ * 1 ? $::form->format_amount(\%::myconfig, $src->$_ * 1,   2) : 0 } @columns if  $format_amounts == 2;
  map { $form->{"${prefix}${_}${postfix}"} = $src->$_ * 1 ? $::form->format_amount(\%::myconfig, $src->$_ * 100, 2) : 0 } @columns if  $format_amounts == 3;
  map { $form->{"${prefix}${_}${postfix}"} = $src->$_ * 1 ? $::form->format_amount(\%::myconfig, $src->$_ * 1,  -2) : 0 } @columns if  $format_amounts == 4;

  return $src;
}

sub _copy_custom_variables {
  my ($src, $form, $prefix, $postfix, $cvar_validity) = @_;

  my $obj = (any { ref($src) eq $_ } qw(SL::DB::OrderItem SL::DB::DeliveryOrderItem SL::DB::InvoiceItem SL::DB::Contact SL::DB::Shipto))
          ? $src
          : $src->customervendor;

  foreach my $cvar (@{ $obj->cvars_by_config }) {
    next if $cvar_validity && !$cvar_validity->{ $cvar->config_id };

    my $value = ($cvar->config->type =~ m{^(?:bool|customer|vendor|part)$})
              ? $cvar->value
              : $cvar->value_as_text;

    $form->{ $prefix . $cvar->config->name . $postfix } = $value;
  }

  return $src;
}

sub _determine_cvar_validity {
  my ($self, $vc) = @_;

  my @part_ids    = uniq map { $_->parts_id } @{ $self->items };
  my @parts       = map { SL::DB::Part->new(id => $_)->load } @part_ids;

  my %item_cvar_validity;
  foreach my $part (@parts) {
    $item_cvar_validity{ $part->id } = { map { ($_->config_id => $_->is_valid) } @{ $part->cvars_by_config } };
  }

  my %vc_cvar_validity = map { ($_->config_id => $_->is_valid) } @{ $self->$vc->cvars_by_config };

  return (
    items => \%item_cvar_validity,
    vc    => \%vc_cvar_validity,
  );
}

sub  _handle_user_data {
  my ($self, $form) = @_;

  foreach my $type (qw(employee salesman)) {
    next if !_has($self, "${type}_id");

    my $user = User->new(login => $self->$type->login);
    $form->{"${type}_$_"} = $user->{$_} for qw(tel email fax signature);

    if ($self->$type->deleted) {
      for my $key (grep { $_ =~ m{^deleted_} } SL::DB::Employee->meta->columns) {
        $key =~ s{^deleted_}{};
        $form->{"${type}_${key}"} = $form->{"${type}_deleted_${key}"}
      }
    }

  }
}

1;
