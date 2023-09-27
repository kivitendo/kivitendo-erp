
# Close intake

In `./SL/Controller/Order.pm` `sub save`: link records

```perl
        $src->update_attributes(closed => 1) if $src->type eq purchase_quotation_intake_type() && $self->type eq purchase_order_type();
```

To `.SL/DB/Order.pm` `sub _after_save_link_records` and `./SL/DB/Helper/RecordLink.pm`

# Close reachable intake


In `./SL/Controller/Order.pm` `sub save`: after save

```perl
    # Close reachable sales order intakes in the from-workflow if this is a sales order
    if (sales_order_type() eq $self->type) {
      my $lr = $self->order->linked_records(direction => 'from', recursive => 1);
      $lr    = [grep { 'SL::DB::Order' eq ref $_ && !$_->closed && $_->is_type('sales_order_intake')} @$lr];
      if (@$lr) {
        SL::DB::Manager::Order->update_all(set   => {closed => 1},
                                           where => [id => [map {$_->id} @$lr]]);
      }
    }
```

To `.SL/DB/Order.pm` `sub _after_save_link_records` and `./SL/DB/Helper/RecordLink.pm`

# Set dates after save as new

In `./SL/Controller/Order.pm` `sub action_save_as_new`:

From

```perl
  # Set new reqdate unless changed if it is enabled in client config
  if ($order->reqdate == $saved_order->reqdate) {
    my $extra_days = $self->type eq sales_quotation_type() ? $::instance_conf->get_reqdate_interval       :
                     $self->type eq sales_order_type()     ? $::instance_conf->get_delivery_date_interval : 1;

    if (   ($self->type eq sales_order_type()     &&  !$::instance_conf->get_deliverydate_on)
        || ($self->type eq sales_quotation_type() &&  !$::instance_conf->get_reqdate_on)) {
      $new_attrs{reqdate} = '';
    } else {
      $new_attrs{reqdate} = DateTime->today_local->next_workday(extra_days => $extra_days);
    }
  } else {
    $new_attrs{reqdate} = $order->reqdate;
  }
```

To

```perl
  # Set new reqdate unless changed if it is enabled in client config
  if ($order->reqdate == $saved_order->reqdate) {
    my $extra_days = $self->type eq sales_quotation_type()    ? $::instance_conf->get_reqdate_interval       :
                     $self->type eq sales_order_type()        ? $::instance_conf->get_delivery_date_interval :
                     $self->type eq sales_order_intake_type() ? $::instance_conf->get_delivery_date_interval : 1;

    if (   ($self->type eq sales_order_intake_type() &&  !$::instance_conf->get_deliverydate_on)
        || ($self->type eq sales_order_type()        &&  !$::instance_conf->get_deliverydate_on)
        || ($self->type eq sales_quotation_type()    &&  !$::instance_conf->get_reqdate_on)) {
      $new_attrs{reqdate} = '';
    } else {
      $new_attrs{reqdate} = DateTime->today_local->next_workday(extra_days => $extra_days);
    }
  } else {
    $new_attrs{reqdate} = $order->reqdate;
  }
```

# Set default dates

In ./SL/Controller/Order.pm` sub action_add`:

From:

```perl
  $self->order->transdate(DateTime->now_local());
  my $extra_days = $self->type eq sales_quotation_type() ? $::instance_conf->get_reqdate_interval       :
                   $self->type eq sales_order_type()     ? $::instance_conf->get_delivery_date_interval : 1;

  if (   ($self->type eq sales_order_type()     &&  $::instance_conf->get_deliverydate_on)
      || ($self->type eq sales_quotation_type() &&  $::instance_conf->get_reqdate_on)
      && (!$self->order->reqdate)) {
    $self->order->reqdate(DateTime->today_local->next_workday(extra_days => $extra_days));
  }
```

To:

```perl
  $self->order->transdate(DateTime->now_local());
  my $extra_days = $self->type eq sales_quotation_type()    ? $::instance_conf->get_reqdate_interval       :
                   $self->type eq sales_order_type()        ? $::instance_conf->get_delivery_date_interval :
                   $self->type eq sales_order_intake_type() ? $::instance_conf->get_delivery_date_interval : 1;

  if (($self->type eq sales_order_intake_type() &&  $::instance_conf->get_deliverydate_on)
      || ($self->type eq sales_order_type()     &&  $::instance_conf->get_deliverydate_on)
      || ($self->type eq sales_quotation_type() &&  $::instance_conf->get_reqdate_on)
      && (!$self->order->reqdate)) {
    $self->order->reqdate(DateTime->today_local->next_workday(extra_days => $extra_days));
  }
```

Now in `SL::Model::Record->update_after_new`

# Create Constants for intake and add to valid type


```perl
  my $text = $self->type eq SALES_ORDER_INTAKE_TYPE()        ? $::locale->text('The order intake has been deleted')
           : $self->type eq SALES_ORDER_TYPE()               ? $::locale->text('The order confirmation has been deleted')
           : $self->type eq PURCHASE_ORDER_TYPE()            ? $::locale->text('The order has been deleted')
           : $self->type eq SALES_QUOTATION_TYPE()           ? $::locale->text('The quotation has been deleted')
           : $self->type eq REQUEST_QUOTATION_TYPE()         ? $::locale->text('The rfq has been deleted')
           : $self->type eq PURCHASE_QUOTATION_INTAKE_TYPE() ? $::locale->text('The quotation intake has been deleted')
```

```perl
sub init_valid_types {
  [ sales_order_intake_type(), sales_order_type(), purchase_order_type(), sales_quotation_type(), request_quotation_type(), purchase_quotation_intake_type() ];
  }
```

# End request after save with error

``
d9bb0bb9 Bernd Bleßmann (2023-07-12 16:44):                                   
Reklamations-Controller: Nach Fehlermeldung beim Speichern Request beenden. … 
``

# adapte record_type update script for order

Add intake types

# No intake flag

Like
`a794ea45d8 (DB::Order: Funktionen angepasst (kein Angebotsflag)`

`tig log -p intake`


# Show menu intake

Order setup action bar


# Type data order intake

# Delivery: order_type errors (Tests)

