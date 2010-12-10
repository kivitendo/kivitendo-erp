package SL::DB::Helper::FlattenToForm;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(flatten_to_form);

use List::MoreUtils qw(any);

use SL::CVar;

sub flatten_to_form {
  my ($self, $form, %params) = @_;

  my $vc = $self->can('customer_id') && $self->customer_id ? 'customer' : 'vendor';

  _copy($self, $form, '', '', 0, qw(id type taxzone_id ordnumber quonumber invnumber donumber cusordnumber taxincluded shippingpoint shipvia notes intnotes curr cp_id
                                    employee_id salesman_id closed department_id language_id payment_id delivery_customer_id delivery_vendor_id shipto_id proforma
                                    globalproject_id delivered transaction_description container_type accepted_by_customer invoice terms storno storno_id dunning_config_id
                                    orddate quodate reqdate gldate duedate deliverydate datepaid transdate));

  if (_has($self, 'transdate')) {
    my $transdate_idx = ref($self) eq 'SL::DB::Order'   ? ($self->quotation ? 'quodate' : 'orddate')
                      : ref($self) eq 'SL::DB::Invoice' ? 'invdate'
                      :                                   'transdate';
    $form->{$transdate_idx} = $self->transdate->to_lxoffice;
  }

  $form->{vc} = $vc if ref($self) =~ /^SL::DB::.*Invoice/;

  my @vc_fields          = (qw(account_number bank bank_code bic business city contact country creditlimit discount
                               email fax homepage iban language name payment_terms phone street taxnumber zipcode),
                            "${vc}number");
  my @vc_prefixed_fields = qw(email fax notes number phone);

  _copy($self,                          $form, '',              '', 1, qw(amount netamount marge_total marge_percent container_remaining_weight container_remaining_volume paid));
  _copy($self->$vc,                     $form, '',              '', 0, @vc_fields);
  _copy($self->$vc,                     $form, $vc,             '', 0, @vc_prefixed_fields);
  _copy($self->contact,                 $form, '',              '', 0, grep { /^cp_/    } map { $_->name } SL::DB::Contact->meta->columns) if _has($self, 'cp_id');
  _copy($self->shipto,                  $form, '',              '', 0, grep { /^shipto/ } map { $_->name } SL::DB::Shipto->meta->columns)  if _has($self, 'shipto_id');
  _copy($self->globalproject,           $form, 'globalproject', '', 0, qw(number description))                                             if _has($self, 'globalproject_id');
  _copy($self->employee,                $form, 'employee',      '', 0, map { $_->name } SL::DB::Employee->meta->columns)                   if _has($self, 'employee_id');
  _copy($self->salesman,                $form, 'salesman',      '', 0, map { $_->name } SL::DB::Employee->meta->columns)                   if _has($self, 'salesman_id');
  _copy($self->acceptance_confirmed_by, $form, 'acceptance_confirmed_by_', '', 0, map { $_->name } SL::DB::Employee->meta->columns)        if _has($self, 'acceptance_confirmed_by_id');

  $form->{employee}   = $self->employee->name          if _has($self, 'employee_id');
  $form->{language}   = $self->language->template_code if _has($self, 'language_id');
  $form->{department} = $self->department->description if _has($self, 'department_id');
  $form->{rowcount}   = scalar(@{ $self->items });

  my $idx = 0;
  my $format_amounts = $params{format_amounts};
  foreach my $item (@{ $self->items }) {
    next if _has($item, 'assemblyitem');

    $idx++;

    $form->{"id_${idx}"}     = $item->parts_id;
    $form->{"number_${idx}"} = $item->part->partnumber;
    _copy($item,          $form, '',         "_${idx}", 0,              qw(description project_id ship serialnumber pricegroup_id ordnumber cusordnumber unit
                                                                           subtotal longdescription price_factor_id marge_price_factor approved_sellprice reqdate transdate));
    _copy($item,          $form, '',        "_${idx}", $format_amounts, qw(qty sellprice discount marge_total marge_percent lastcost));
    _copy($item->project, $form, 'project', "_${idx}", 0,               qw(number description)) if _has($item, 'project_id');

    _copy_custom_variables($item, $form, 'ic_cvar_', "_${idx}");
  }

  _copy_custom_variables($self, $form, 'vc_cvar_', '');

  return $self;
}

sub _has {
  my ($obj, $column) = @_;
  return $obj->can($column) && $obj->$column;
}

sub _copy {
  my ($src, $form, $prefix, $postfix, $format_amounts, @columns) = @_;

  map { $form->{"${prefix}${_}${postfix}"} = ref($src->$_) eq 'DateTime' ? $src->$_->to_lxoffice : $src->$_ if $src->can($_) } @columns if !$format_amounts;
  map { $form->{"${prefix}${_}${postfix}"} = $::form->format_amount(\%::myconfig, $src->$_ * 1, 2) if $src->can($_)          } @columns if  $format_amounts;

  return $src;
}

sub _copy_custom_variables {
  my ($src, $form, $prefix, $postfix) = @_;

  my ($module, $sub_module, $trans_id) = ref($src) eq 'SL::DB::OrderItem'         ? ('IC', 'orderitems',           $src->id)
                                       : ref($src) eq 'SL::DB::DeliveryOrderItem' ? ('IC', 'delivery_order_items', $src->id)
                                       : ref($src) eq 'SL::DB::InvoiceItem'       ? ('IC', 'invoice',              $src->id)
                                       :                                            ('CT', undef,                  _has($src, 'customer_id') ? $src->customer_id : $src->vendor_id);

  return unless $trans_id;

  my $cvars = CVar->get_custom_variables(dbh        => $src->db->dbh,
                                         module     => $module,
                                         sub_module => $sub_module,
                                         trans_id   => $trans_id,
                                        );
  map { $form->{ $prefix . $_->{name} . $postfix } = $_->{value} } @{ $cvars };

  return $src;
}

1;
