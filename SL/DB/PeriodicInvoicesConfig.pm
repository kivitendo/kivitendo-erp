package SL::DB::PeriodicInvoicesConfig;

use strict;

use SL::DB::MetaSetup::PeriodicInvoicesConfig;
use SL::DB::Manager::PeriodicInvoicesConfig;

use Params::Validate qw(:all);
use List::Util qw(max min);
use Rose::DB::Object::Helpers qw(clone);

use SL::Helper::DateTime;

__PACKAGE__->meta->initialize;

our %PERIOD_LENGTHS             = ( o => 0, m => 1, q => 3, b => 6, y => 12 );
our %ORDER_VALUE_PERIOD_LENGTHS = ( %PERIOD_LENGTHS, 2 => 24, 3 => 36, 4 => 48, 5 => 60 );
our @PERIODICITIES              = keys %PERIOD_LENGTHS;
our @ORDER_VALUE_PERIODICITIES  = keys %ORDER_VALUE_PERIOD_LENGTHS;

sub get_open_orders_for_period {
  my $self = shift;

  my %params = validate(@_, {
    start_date => {
      callbacks => { is_date => \&_is_date, },
      default   => $self->start_date,
    },
    end_date   => {
      callbacks => { is_date => \&_is_date, },
      default   => DateTime->today_local,
    },
  });

  my @invoice_dates = $self->calculate_invoice_dates(%params);
  return [] unless scalar @invoice_dates;

  my $orig_order = $self->order;

  my @orders;
  foreach my $invoice_date (@invoice_dates) {
    my $new_order = clone($orig_order);
    $new_order->reqdate($invoice_date);
    $new_order->tax_point(
      $self->get_order_value_period_length || $self->get_order_value_period_length ?
          $self->add_months($invoice_date,
            $self->get_billing_period_length || $self->get_order_value_period_length
          )->subtract(days => 1)
        : $invoice_date
    );
    my @items;
    for my $item ($orig_order->items) {
      my $new_item = $self->_create_item_for_period(
        order_item => $item,
        invoice_date => $invoice_date,
      );
      push @items, $new_item if $new_item;
    }
    if (scalar @items) { # don't return empty orders
      $new_order->items(@items);
      $new_order->calculate_prices_and_taxes;
      push @orders, $new_order;
    }
  }
  return \@orders;
}

sub _create_item_for_period {
  my $self = shift;

  my %params = validate(@_, {
    invoice_date => { callbacks => { is_date => \&_is_date, } },
    order_item => { isa => 'SL::DB::OrderItem' },
  });

  my $item         = $params{order_item};
  my $invoice_date = DateTime->from_ymd($params{invoice_date});

  my $new_item = clone($item);

  my $item_count_and_date = $self->item_count_and_dates_in_period(
    invoice_date => $invoice_date,
    item => $new_item,
  );

  my $count = $item_count_and_date->{count};
  return if $count == 0;
  my $item_start_date = $item_count_and_date->{start_date};

  $new_item->qty($new_item->qty * $count);
  $new_item->reqdate($item_start_date) if $new_item->reqdate;

  $new_item = $self->_adjust_sellprices_for_period(
      order_item => $new_item,
      invoice_date => $invoice_date,
  );
  return $new_item
}

sub item_count_and_dates_in_period {
  my $self = shift;

  my %params = validate(@_, {
    invoice_date => { callbacks => { is_date => \&_is_date, } },
    item => { isa => 'SL::DB::OrderItem' },
  });

  my $period_length = $self->get_billing_period_length;

  my $invoice_date  = DateTime->from_ymd($params{invoice_date});
  my $item_config   = $params{item}->periodic_invoice_items_config
      or return {
      count => 1,
      start_date => $invoice_date,
      end_date => $self->add_months(
        $invoice_date, $period_length
      )->subtract(days => 1),
    };

  my %empty_return = (count => 0);

  return \%empty_return if $item_config->periodicity eq 'n';

  my $item_start_date = $item_config->start_date;
  if (!$item_start_date && $self->first_billing_date) {
    my $item_start_date = $self->first_billing_date;
    $item_start_date = $self->add_months(
      $item_start_date, $period_length
    ) while $item_start_date < $self->start_date;
  }
  $item_start_date ||= $self->start_date;

  return \%empty_return if $item_start_date > $invoice_date;

  if ($item_config->periodicity eq 'o') {
    return \%empty_return if $item_config->once_invoice_id;

    my $first_possible_date = max(
      $item_start_date, $self->get_previous_billed_period_start_date
    );
    $first_possible_date ||= $item_start_date;

    my @dates = $self->calculate_invoice_dates(
      start_date => $first_possible_date,
      end_date => $self->add_months($first_possible_date, $period_length),
    );
    my $once_date = scalar @dates ? $dates[0] : undef;
    return \%empty_return if $invoice_date != $once_date;
    return {
      count => 1,
      start_date => $item_start_date,
      end_date   => undef             # end_date don't affect once items
    };
  }

  my $period_start_date =
    $self->sub_months($invoice_date, $period_length)->add(days => 1);
  my $i_period_length = $item_config->get_item_period_length;
  my $item_start_date_in_period;
  if ($period_start_date > $item_start_date) {
    my $months_from_item_start_date =
          ($period_start_date->year  - $item_start_date->year) * 12
        + ($period_start_date->month - $item_start_date->month);
    $months_from_item_start_date++
      if $self->add_months($item_start_date, $months_from_item_start_date) < $period_start_date;
    my $months_offset_to_item_start_date_in_period =
      $months_from_item_start_date % $i_period_length ?
          $i_period_length - ($months_from_item_start_date % $i_period_length)
        : 0;
    $item_start_date_in_period = $self->add_months($item_start_date,
      $months_from_item_start_date + $months_offset_to_item_start_date_in_period
    );
  } else {
    $item_start_date_in_period = $item_start_date;
  }

  return \%empty_return if $item_start_date_in_period > $invoice_date;

  my $item_end_date;
  if ($item_config->terminated || !$item_config->extend_automatically_by) {
    $item_end_date = $item_config->end_date;
  } elsif ($self->terminated || !$self->extend_automatically_by) {
    $item_end_date = $self->end_date;
  }
  return \%empty_return if $item_end_date && $item_end_date < $period_start_date;

  if ($i_period_length < $period_length) { # calc items periods in last billing period
    my $max_periods = $period_length / $i_period_length;
    my $periods = $max_periods;

    my $periods_to_start = 0;
    $periods_to_start++ while $periods > $periods_to_start
      && $self->add_months(
        $period_start_date,
        ($periods_to_start + 1) * $i_period_length
      ) < $item_start_date_in_period;
    $periods -= $periods_to_start;

    my $periods_from_end = 0;
    if ($item_end_date) {
      $periods_from_end++ while $periods > $periods_from_end
        && $self->sub_months($invoice_date, $periods_from_end) > $item_end_date;
      $periods -= $periods_from_end;
    }

    return \%empty_return if $periods == 0;
    return {
      count => $periods,
      start_date => $item_start_date_in_period,
      end_date => $self->add_months(
        $item_start_date_in_period, $i_period_length * $periods
      )->subtract(days => 1),
    };
  } else {
    return {
      count => 1,
      start_date => $item_start_date_in_period,
      end_date => $self->add_months(
        $item_start_date_in_period, $i_period_length
      )->subtract(days => 1),
    };
  }
}

sub _adjust_sellprices_for_period {
  my $self = shift;

  my %params = validate(@_, {
    invoice_date => { callbacks => { is_date => \&_is_date, } },
    order_item => { isa => 'SL::DB::OrderItem' },
  });
  my $item = $params{order_item};

  my $config = $self;

  my $billing_len     = $config->get_billing_period_length;
  my $order_value_len = $config->get_order_value_period_length;

  return $item if $billing_len == $order_value_len;
  return $item if $billing_len == 0;

  my $is_last_invoice_in_cycle = $config->is_last_invoice_date_in_order_value_cycle(date => $params{invoice_date});

  my $multiplier_per_invoice = $billing_len / $order_value_len;
  my $sellprice_one_invoice = $::form->round_amount($item->sellprice * $multiplier_per_invoice, 2);
  if ($multiplier_per_invoice < 1 && $is_last_invoice_in_cycle) {
    # add rounding difference on last cycle
    my $num_invoices_in_cycle = $order_value_len / $billing_len;
    $item->sellprice($item->sellprice - ($num_invoices_in_cycle - 1) * $sellprice_one_invoice);
  } else {
    $item->sellprice($sellprice_one_invoice);
  }

  return $item;
}

sub calculate_invoice_dates {
  my $self = shift;

  my %params = validate(@_, {
    start_date => {
      callbacks => { is_date => \&_is_date, },
      default   => $self->start_date,
    },
    end_date   => {
      callbacks => { is_date => \&_is_date, },
      default   => DateTime->today_local,
    },
  });

  my $start_date = DateTime->from_ymd($params{start_date});
  my $end_date   = DateTime->from_ymd($params{end_date});
  my $last_end_date = $self->last_end_date;
  $end_date = min($end_date, $last_end_date) if $last_end_date;

  my $last_created_on_date = $self->get_previous_billed_period_start_date;

  my $first_invoice_date = $self->first_billing_date || $self->start_date;
  $first_invoice_date = $self->add_months(
    $first_invoice_date, $self->get_billing_period_length || 1
  ) while $first_invoice_date < $self->start_date;

  my @invoice_dates;
  if ($self->periodicity ne 'o') {
    my $billing_period_length = $self->get_billing_period_length;
    my $months_first_invoice_date =
      $first_invoice_date->year * 12 + $first_invoice_date->month;

    my $month_to_start = $start_date->year * 12 + $start_date->month - $months_first_invoice_date;
    $month_to_start++
      if $self->add_months($first_invoice_date, $month_to_start) < $start_date;

    my $month_after_last_created = 0;
    if ($last_created_on_date) {
      $month_after_last_created =
        $last_created_on_date->year * 12 + $last_created_on_date->month - $months_first_invoice_date;
      $month_after_last_created += 1
        if $self->add_months($first_invoice_date, $month_after_last_created) <= $last_created_on_date;
    }

    my $months_from_period_start = max(
      $month_to_start,
      $month_after_last_created,
      0);

    my $period_count = int($months_from_period_start / $billing_period_length); # floor
    $period_count += $months_from_period_start % $billing_period_length != 0 ? 1 : 0; # ceil

    my $next_period_start_date = $self->add_months($first_invoice_date, $period_count * $billing_period_length);
    while ($next_period_start_date <= $end_date) {
      push @invoice_dates, $next_period_start_date;
      $period_count++;
      $next_period_start_date = $self->add_months($first_invoice_date, $period_count * $billing_period_length);
    }
  } else { # single
    push @invoice_dates, $first_invoice_date
      unless $last_created_on_date
          || $first_invoice_date < $start_date
          || $first_invoice_date > $end_date;
  }

  return @invoice_dates;
}

sub last_end_date {
  my ($self) = @_;
  my $end_date = $self->end_date or
    return undef; # don't have a end_date
  if ($self->extend_automatically_by && !$self->terminated) {
    return undef;
  }
  for my $item (@{$self->order->items()}) {
    my $item_config = $item->periodic_invoice_items_config
      or next;
    next if $item_config->periodicity eq 'n';
    if ($item_config->periodicity eq 'o') {
      if (!$item_config->once_invoice_id) {
        return undef; # allways create for once positions
      } else {
        next;
      }
    } else {
      if ($item_config->end_date) {
        if ($item_config->extend_automatically_by && !$item_config->terminated) {
          return undef; # active end_date
        } else {
          $end_date = max($end_date, $item_config->end_date);
        }
      }
    }
  }
  return $end_date;
}

sub get_billing_period_length {
  my $self = shift;
  return $PERIOD_LENGTHS{ $self->periodicity };
}

sub get_order_value_period_length {
  my $self = shift;
  return $self->get_billing_period_length if $self->order_value_periodicity eq 'p';
  return $ORDER_VALUE_PERIOD_LENGTHS{ $self->order_value_periodicity };
}

sub add_months {
  validate_pos(@_,
    1,
    { callbacks => { is_date => \&_is_date, } },
    { type => SCALAR },
  );
  my ($self, $date, $months) = @_;
  $date = DateTime->from_ymd($date);

  return $date unless $months;

  my $start_months_of_date = $date->month;
  $date = $date->clone();
  my $new_date = $date->clone();
  $new_date->add(months => $months);
  # stay in month: 31.01 + 1 month should be 28.02 or 29.02 (not 03.03. or 02.03)
  while (($start_months_of_date + $months) % 12 != $new_date->month % 12) {
    $new_date->subtract(days => 1);
  }

  # if date was at end of month -> move new date also to end of month
  if ($date->is_last_day_of_month()) {
    return DateTime->last_day_of_month(year => $new_date->year, month => $new_date->month)
  }

  return $new_date
};

sub sub_months {
  my ($self, $date, $months) = @_;
  return $self->add_months($date, -1 * $months);
}

sub _is_date {
   return !!DateTime->from_ymd($_[0]); # can also be a DateTime object
}

sub _log_msg {
  $::lxdebug->message(LXDebug->DEBUG1(), join('', 'SL::DB::PeriodicInvoicesConfig: ', @_));
}

sub handle_automatic_extension {
  my $self = shift;

  my $today = DateTime->now_local;
  my $active = 0; # inactivate if end date is reached (for self and all positions)

  if ($self->end_date && $self->end_date < $today) {
    if (!$self->terminated && $self->extend_automatically_by) {
      $active = 1;

      my $end_date = $self->end_date;
      $end_date = $self->add_months($end_date, $self->extend_automatically_by) while $today > $end_date;
      _log_msg("HAE for " . $self->id . " from " . $self->end_date . " to " . $end_date . " on " . $today . "\n");
      $self->update_attributes(end_date => $end_date);
    }
  } else {
    $active = 1;
  }

  # check for positions with separate config
  for my $item ($self->order->items()) {
    my $item_config = $item->periodic_invoice_items_config;
    next unless $item_config;
    if ($item_config->end_date && $item_config->end_date < $today) {
      if (!$item_config->terminated && $item_config->extend_automatically_by) {
        $active = 1;

        my $end_date = $item_config->end_date;
        $end_date = $self->add_months($end_date, $item_config->extend_automatically_by) while $today > $end_date;
        _log_msg("HAE for item " . $item->id . " from " . $item_config->end_date . " to " . $end_date . " on " . $today . "\n");
        $item_config->update_attributes(end_date => $end_date);
      }
    } else {
      $active = 1;
    }
  }

  unless ($active) {
    $self->update_attributes(active => 0)
  }

  return;
}

sub get_previous_billed_period_start_date {
  my $self  = shift;

  my $query = <<SQL;
    SELECT MAX(period_start_date)
    FROM periodic_invoices
    WHERE config_id = ?
SQL

  my ($date) = $self->dbh->selectrow_array($query, undef, $self->id);

  return undef unless $date;
  return ref $date ? $date : $self->db->parse_date($date);
}

sub is_last_invoice_date_in_order_value_cycle {
  my $self    = shift;

  my %params = validate(@_, {
    date => { callbacks => { is_date => \&_is_date, } },
  });

  my $months_billing     = $self->get_billing_period_length;
  my $months_order_value = $self->get_order_value_period_length;

  return 1 if $months_billing >= $months_order_value;

  my $invoice_date = DateTime->from_ymd($params{date});
  my $first_date   = $self->first_billing_date || $self->start_date;

  return (12 * ($invoice_date->year - $first_date->year) + $invoice_date->month + $months_billing) % $months_order_value
    == $first_date->month % $months_order_value;
}

sub disable_one_time_config {
  my $self = shift;

  _log_msg("check one time for " . $self->id . "\n");

  # A periodicity of one time was set. Deactivate this config now.
  if ($self->periodicity eq 'o') {
    _log_msg("setting inactive\n");
    if (!$self->db->with_transaction(sub {
      1;                          # make Emacs happy
      $self->active(0);
      $self->order->update_attributes(closed => 1);
      $self->save;
      1;
    })) {
      $::lxdebug->message(LXDebug->WARN(), "disalbe_one_time config failed: " . join("\n", (split(/\n/, $self->{db_obj}->db->error))[0..2]));
      return undef;
    }
    return $self->order->ordnumber;
  }
  return undef;
}
1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::PeriodicInvoicesConfig - DB model for the configuration for periodic invoices

=head1 SYNOPSIS

  $open_orders = $config->get_open_orders_for_period(
    start_date => $config->start_date,
    end_date   => DateTime->today_local,
  );

  # Same as:
  $open_orders = $config->get_open_orders_for_period();

  # create invoices
  SL::DB::Invoice->new_from($_)->post() for @{$open_orders}
  # TODO: update configs with periodicity once

  # sum netamount
  my $netamount = 0;
  $netamount += $_->netamount for @{$open_orders};

=head1 FUNCTIONS

=over 4

=item C<get_open_orders_for_period %params>

Creates a list of copies of the order associated with this configuration for
each date a invoice would be created in the given period. Each copie has the
correct dates and items set to be converted to a invoice or used in a report.
The period can be specified using the parameters C<start_date> and C<end_date>.

Parameters:

=over 2

=item * C<start_date> specifies the start of the period. It can be a L<DateTime>
object or a string in the fromat C<YYYY-MM-DD>. It defaults to the C<start_date>
of the configuration.

=item * C<end_date> specifies the end of the period. It has the same type as
C<start_date>. It defaults to the current local time.

=back

=item C<calculate_invoice_dates %params>

Calculates dates for which invoices will have to be created in the period given
by the parameters C<start_date> and C<end_date>. Returns a list of L<DateTime>
objects.

This function looks at the configuration settings and at the list of
invoices that have already been created for this configuration. The
date range for which dates are created are controlled by several
values:

=over 2

=item * The properties C<first_billing_date> and C<start_date>
determine the first invoice date.

=item * The properties C<end_date>, C<terminated> and C<extend_automatically_by>
determine the end date.

=item * The parameter C<start_date> of the period defaults to the start date
from the configuration.

=item * The parameter C<end_date> defaults to current date.

=back

=item C<item_count_and_dates_in_period %params>

Return a hash reference with the C<count> and the C<start_date> and C<end_date>
of the period for a item which would be on a invoice created on specific date.
If C<count> is 0 C<start_date> and C<end_date> are not set. For items with a
'once' periodicity C<end_date> is not set.

=over 2

=item C<item>  a item of the order corresponding to this configuration

=item C<invoice_date> the date on which the invoice would be created

=back

=item C<get_billing_period_length>

Returns the number of months corresponding to the billing
periodicity. This means that a new invoice has to be created every x
months starting with the value in C<first_billing_date> (or
C<start_date> if C<first_billing_date> is unset).

=item C<get_order_value_period_length>

Returns the number of months the order's value refers to. This looks
at the C<order_value_periodicity>.

Each invoice's value is calculated as C<order value *
billing_period_length / order_value_period_length>.

=item C<get_previous_billed_period_start_date>

Returns the highest date (as an instance of L<DateTime>) for which an
invoice has been created from this configuration.

=item C<handle_automatic_extension>

Updates the C<end_date>s according to C<terminated> and
C<extend_automatically_by> of this configuration and the corresponding item
configuration if the C<end_date> is after the current date. If at the end all
configurations are after the corresponding C<end_date>, e.g. C<end_date> is
reached and C<terminated> is set to true or C<extend_automatically_by> is set to
0, this configuration is set to inactive.

=item C<is_last_billing_date_in_order_value_cycle %params>

Determines whether or not the mandatory parameter C<date>, an instance
of L<DateTime>, is the last billing date within the cycle given by the
order value periodicity. Returns a truish value if this is the case
and a falsish value otherwise.

This check is always true if the billing periodicity is longer than or
equal to the order value periodicity. For example, if you have an
order whose value is given for three months and you bill every six
months and you have twice the order value on each invoice, meaning
each invoice is itself the last invoice for not only one but two order
value cycles.

Otherwise (if the order value periodicity is longer than the billing
periodicity) this function iterates over all eligible dates starting
with C<first_billing_date> (or C<start_date> if C<first_billing_date>
is unset) and adding the order value length with each step. If the
date given by the C<date> parameter plus the billing period length
equals one of those dates then the given date is indeed the date of
the last invoice in that particular order value cycle.

=item C<sub disable_one_time_config>

Sets the state of the periodic_invoices_configs to inactive
(active => false) and closes the source order (closed => true)
if the periodicity is <Co> (one time).

Returns undef if the periodicity is not 'one time' otherwise the
order number of the deactivated periodic order.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
