
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


# Delivery: order_type errors (Tests)

