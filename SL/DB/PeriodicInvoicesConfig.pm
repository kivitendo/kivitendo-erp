package SL::DB::PeriodicInvoicesConfig;

use strict;

use SL::DB::MetaSetup::PeriodicInvoicesConfig;

use List::Util qw(max min);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

our %PERIOD_LENGTHS             = ( o => 0, m => 1, q => 3, b => 6, y => 12 );
our %ORDER_VALUE_PERIOD_LENGTHS = ( %PERIOD_LENGTHS, 2 => 24, 3 => 36, 4 => 48, 5 => 60 );
our @PERIODICITIES              = keys %PERIOD_LENGTHS;
our @ORDER_VALUE_PERIODICITIES  = keys %ORDER_VALUE_PERIOD_LENGTHS;

sub get_billing_period_length {
  my $self = shift;
  return $PERIOD_LENGTHS{ $self->periodicity } || 1;
}

sub get_order_value_period_length {
  my $self = shift;
  return $self->get_billing_period_length if $self->order_value_periodicity eq 'p';
  return $ORDER_VALUE_PERIOD_LENGTHS{ $self->order_value_periodicity } || 1;
}

sub _log_msg {
  $::lxdebug->message(LXDebug->DEBUG1(), join('', 'SL::DB::PeriodicInvoicesConfig: ', @_));
}

sub handle_automatic_extension {
  my $self = shift;

  _log_msg("HAE for " . $self->id . "\n");
  # Don't extend configs that have been terminated. There's nothing to
  # extend if there's no end date.
  return if $self->terminated || !$self->end_date;

  my $today    = DateTime->now_local;
  my $end_date = $self->end_date;

  _log_msg("today $today end_date $end_date\n");

  # The end date has not been reached yet, therefore no extension is
  # needed.
  return if $today <= $end_date;

  # The end date has been reached. If no automatic extension has been
  # set then terminate the config and return.
  if (!$self->extend_automatically_by) {
    _log_msg("setting inactive\n");
    $self->active(0);
    $self->save;
    return;
  }

  # Add the automatic extension period to the new end date as long as
  # the new end date is in the past. Then save it and get out.
  $end_date->add(months => $self->extend_automatically_by) while $today > $end_date;
  _log_msg("new end date $end_date\n");

  $self->end_date($end_date);
  $self->save;

  return $end_date;
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

sub calculate_invoice_dates {
  my ($self, %params) = @_;

  my $period_len = $self->get_billing_period_length;
  my $cur_date   = ($self->first_billing_date || $self->start_date)->clone;
  my $end_date   = $self->terminated ? $self->end_date : undef;
  $end_date    //= DateTime->today_local->add(years => 100);
  my $start_date = $params{past_dates} ? undef                              : $self->get_previous_billed_period_start_date;
  $start_date    = $start_date         ? $start_date->clone->add(days => 1) : $cur_date->clone;

  $start_date    = max($start_date, $params{start_date}) if $params{start_date};
  $end_date      = min($end_date,   $params{end_date})   if $params{end_date};

  if ($self->periodicity eq 'o') {
    return ($cur_date >= $start_date) && ($cur_date <= $end_date) ? ($cur_date) : ();
  }

  my @dates;

  while ($cur_date <= $end_date) {
    push @dates, $cur_date->clone if $cur_date >= $start_date;

    $cur_date->add(months => $period_len);
  }

  return @dates;
}

sub is_last_bill_date_in_order_value_cycle {
  my ($self, %params)    = @_;

  my $months_billing     = $self->get_billing_period_length;
  my $months_order_value = $self->get_order_value_period_length;

  return 1 if $months_billing >= $months_order_value;

  my $next_billing_date = $params{date}->clone->add(months => $months_billing);
  my $date_itr          = max($self->start_date, $self->first_billing_date || $self->start_date)->clone;

  _log_msg("is_last_billing_date_in_order_value_cycle start: id " . $self->id . " date_itr $date_itr start " . $self->start_date);

  $date_itr->add(months => $months_order_value) while $date_itr < $next_billing_date;

  _log_msg("is_last_billing_date_in_order_value_cycle end: refdate $params{date} next_billing_date $next_billing_date date_itr $date_itr months_billing $months_billing months_order_value $months_order_value result "
           . ($date_itr == $next_billing_date));

  return $date_itr == $next_billing_date;
}

sub disable_one_time_config {
  my $self = shift;

  _log_msg("check one time for " . $self->id . "\n");

  # A periodicity of one time was set. Deactivate this config now.
  if ($self->periodicity eq 'o') {
    _log_msg("setting inactive\n");
    $self->active(0);
    $self->save;
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

=head1 FUNCTIONS

=over 4

=item C<calculate_invoice_dates %params>

Calculates dates for which invoices will have to be created. Returns a
list of L<DateTime> objects.

This function looks at the configuration settings and at the list of
invoices that have already been created for this configuration. The
date range for which dates are created are controlled by several
values:

=over 2

=item * The properties C<first_billing_date> and C<start_date>
determine the start date.

=item * The properties C<end_date> and C<terminated> determine the end
date.

=item * The optional parameter C<past_dates> determines whether or not
dates for which invoices have already been created will be included in
the list. The default is not to include them.

=item * The optional parameters C<start_date> and C<end_date> override
the start and end dates from the configuration.

=item * If no end date is set or implied via the configuration and no
C<end_date> parameter is given then the function will use 100 years
in the future as the end date.

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

Configurations which haven't been terminated and which have an end
date set may be eligible for automatic extension by a certain number
of months. This what the function implements.

If the configuration is not eligible or if the C<end_date> hasn't been
reached yet then nothing is done and C<undef> is returned. Otherwise
its behavior is determined by the C<extend_automatically_by> property.

If the property C<extend_automatically_by> is not 0 then the
C<end_date> will be extended by C<extend_automatically_by> months, and
the configuration will be saved. In this case the new end date will be
returned.

Otherwise (if C<extend_automatically_by> is 0) the property C<active>
will be set to 1, and the configuration will be saved. In this case
C<undef> will be returned.

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
(active => false) if the periodicity is <Co> (one time).
Returns undef if the periodicity is not 'one time' otherwise the
order number of the deactivated periodic order.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
