package SL::DB::Helper::FlattenToForm;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(flatten_to_form);

use List::MoreUtils qw(uniq any);

sub flatten_to_form {
  my ($self, $form, %params) = @_;

  my $vc = $self->can('customer_id') && $self->customer_id ? 'customer' : 'vendor';

  _copy($self, $form, '', '', 0, qw(id type taxzone_id ordnumber quonumber invnumber donumber cusordnumber taxincluded shippingpoint shipvia notes intnotes cp_id
                                    employee_id salesman_id closed department_id language_id payment_id delivery_customer_id delivery_vendor_id shipto_id proforma
                                    globalproject_id delivered transaction_description container_type accepted_by_customer invoice storno storno_id dunning_config_id
                                    orddate quodate reqdate gldate duedate deliverydate datepaid transdate delivery_term_id));
  $form->{currency} = $form->{curr} = $self->currency_id ? $self->currency->name || '' : '';

  if ( $vc eq 'customer' ) {
    $form->{customer_id} = $self->customer_id;
    $form->{customer}    = $self->customer->name if $self->customer;
  } else {
    $form->{vendor_id}   = $self->vendor_id;
    $form->{vendor}      = $self->vendor->name if $self->vendor;
  };

  if (_has($self, 'transdate')) {
    my $transdate_idx = ref($self) eq 'SL::DB::Order'   ? ($self->quotation ? 'quodate' : 'orddate')
                      : ref($self) eq 'SL::DB::Invoice' ? 'invdate'
                      :                                   'transdate';
    $form->{$transdate_idx} = $self->transdate->to_lxoffice;
  }

  $form->{vc} = $vc if ref($self) =~ m{^SL::DB::(?:.*Invoice|.*Order)};

  my @vc_fields          = (qw(account_number bank bank_code bic business city contact country creditlimit
                               department_1 department_2 discount email fax gln homepage iban language name
                               phone street taxnumber ustid zipcode),
                            "${vc}number",
                            ($vc eq 'customer')? 'c_vendor_id': 'v_customer_id');
  my @vc_prefixed_fields = qw(email fax notes number phone);

  _copy($self,                          $form, '',              '', 1, qw(amount netamount marge_total marge_percent container_remaining_weight container_remaining_volume paid));
  _copy($self->$vc,                     $form, '',              '', 0, @vc_fields);
  _copy($self->$vc,                     $form, $vc,             '', 0, @vc_prefixed_fields);
  _copy($self->contact,                 $form, '',              '', 0, grep { /^cp_/    } map { $_->name } SL::DB::Contact->meta->columns) if _has($self, 'cp_id');
  _copy($self->shipto,                  $form, '',              '', 0, grep { /^shipto/ } map { $_->name } SL::DB::Shipto->meta->columns)  if _has($self, 'shipto_id');
  _copy($self->globalproject,           $form, 'globalproject', '', 0, qw(number description))                                             if _has($self, 'globalproject_id');
  _copy($self->employee,                $form, 'employee_',     '', 0, map { $_->name } SL::DB::Employee->meta->columns)                   if _has($self, 'employee_id');
  _copy($self->salesman,                $form, 'salesman_',     '', 0, map { $_->name } SL::DB::Employee->meta->columns)                   if _has($self, 'salesman_id');
  _copy($self->acceptance_confirmed_by, $form, 'acceptance_confirmed_by_', '', 0, map { $_->name } SL::DB::Employee->meta->columns)        if _has($self, 'acceptance_confirmed_by_id');

  if (_has($self, 'employee_id')) {
    my $user = User->new(login => $self->employee->login);
    $form->{"employee_$_"} = $user->{$_} for qw(tel email fax);
  }
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
                                                                                  active_price_source active_discount_source));
    _copy($item,          $form, '',              "_${idx}", $format_noround, qw(qty sellprice));
    _copy($item,          $form, '',              "_${idx}", $format_amounts, qw(marge_total marge_percent lastcost));
    _copy($item,          $form, '',              "_${idx}", $format_percent, qw(discount));
    _copy($item->project, $form, 'project',       "_${idx}", 0,               qw(number description)) if _has($item, 'project_id');

    _copy_custom_variables($item, $form, 'ic_cvar_', "_${idx}", $cvar_validity{items}->{ $item->parts_id });

    if (ref($self) eq 'SL::DB::Invoice') {
      my $date                          = $item->deliverydate ? $item->deliverydate->to_lxoffice : undef;
      $form->{"deliverydate_oe_${idx}"} = $date;
      $form->{"reqdate_${idx}"}         = $date;
    }
  }

  _copy_custom_variables($self, $form, 'vc_cvar_', '', $cvar_validity{vc});
  _copy_custom_variables($self->contact, $form, 'cp_cvar_', '') if $self->contact;

  return $self;
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

  my $obj = (any { ref($src) eq $_ } qw(SL::DB::OrderItem SL::DB::DeliveryOrderItem SL::DB::InvoiceItem SL::DB::Contact))
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

1;
