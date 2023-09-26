package SL::BackgroundJob::SelfTest::NovoclonStrict;

use utf8;
use strict;
use parent qw(SL::BackgroundJob::SelfTest::Base);

use DateTime;
use List::MoreUtils qw(none notall);
use SL::DB::DeliveryOrder;
use SL::DB::Order;
use SL::DB::PurchaseInvoice;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(start_date) ],
);

sub init_start_date {
  DateTime->new(day => 1, month => 1, year => DateTime->today->year);
}


sub run {
  my ($self) = @_;

  $self->tester->plan(tests => 8);

  $self->check_no_missing_invoices;
  $self->check_no_missing_deliveries;
  $self->check_no_missing_order_confirmations;
  $self->check_invoices_mailed;
  $self->check_order_confirmations_mailed;
  $self->check_quotations_mailed;
  $self->check_purchase_invoices_sums_against_purchase_orders;
  $self->check_purchase_invoices_sums_against_sales_orders;
}

sub check_no_missing_invoices {
  my ($self) = @_;

  my $days_delta           = 4;
  my $title                = "Alle Verkaufslieferscheine sind $days_delta Werktage nach Lieferterimin geschlossen.";

  my $latest_reqdate       = DateTime->today_local->subtract_businessdays(days => $days_delta);
  my $open_delivery_orders = SL::DB::Manager::DeliveryOrder->get_all_sorted(where => ['!customer_id'  => undef,
                                                                                      '!cusordnumber' => { ilike => ['muster'] },
                                                                                      delivered       => 1,
                                                                                      or              => [closed => undef, closed => 0],
                                                                                      reqdate         => {le => $latest_reqdate},
                                                                                      transdate       => {ge => $self->start_date},]
  );

  if (@$open_delivery_orders) {
    $self->tester->ok(0, $title);
    $self->tester->diag("Folgende Verkaufslieferscheine sind geliefert und nach Liefertermin länger als $days_delta Werktage offen. Vermutlich fehlt die Rechnung:");
    $self->tester->diag("Lieferschein-Nummer: " . $_->donumber) for @$open_delivery_orders;

  } else {
    $self->tester->ok(1, $title);
  }
}

sub check_no_missing_deliveries {
  my ($self) = @_;

  my $days_delta     = 2;
  my $title          = "Alle offenen Auftragsbestätigungen mit Liefertermin vor mindestens $days_delta Werktagen haben eine Lieferung.";

  my $latest_reqdate = DateTime->today_local->subtract_businessdays(days => $days_delta);
  my $orders         = SL::DB::Manager::Order->get_all_sorted(where => [record_type     => 'sales_order',
                                                                        or              => [closed    => undef, closed    => 0],
                                                                        reqdate         => {le => $latest_reqdate},
                                                                        transdate       => {ge => $self->start_date},]);
  my %not_delivered;
  foreach my $order (@$orders) {
    my $lr = $order->linked_records(to => 'DeliveryOrder');
    $lr    = [grep { !!$_->customer_id } @$lr];

    if (scalar @$lr == 0) {
      push @{ $not_delivered{no_delivery_order} }, $order->ordnumber;
      next;
    }

    if (none { $_->delivered } @$lr) {
      push @{ $not_delivered{none_delivered}    }, $order->ordnumber;
      next;
    }

    if (notall { $_->delivered } @$lr) {
      push @{ $not_delivered{notall_delivered}  }, $order->ordnumber;
      next;
    }
  }

  if (@{ $not_delivered{no_delivery_order} || [] } || @{ $not_delivered{none_delivered} || [] } || @{ $not_delivered{notall_delivered} || [] }) {
    $self->tester->ok(0, $title);

    if (@{ $not_delivered{no_delivery_order} || [] }) {
      $self->tester->diag("Folgende offene fällige Auftragsbestätigungen haben keine Verkaufslieferscheine:");
      $self->tester->diag("Auftrags-Nummer: " . $_) for @{ $not_delivered{no_delivery_order} };
    }
    if (@{ $not_delivered{none_delivered} || [] }) {
      $self->tester->diag("Folgende offene fällige Auftragsbestätigungen haben Verkaufslieferscheine, von denen keine geliefert sind:");
      $self->tester->diag("Auftrags-Nummer: " . $_) for @{ $not_delivered{none_delivered} };
    }
    if (@{ $not_delivered{notall_delivered} || [] }) {
      $self->tester->diag("Folgende offene fällige Auftragsbestätigungen haben einen oder mehrere nicht gelieferte Verkaufslieferscheine:");
      $self->tester->diag("Auftrags-Nummer: " . $_) for @{ $not_delivered{notall_delivered} };
    }

  } else {
    $self->tester->ok(1, $title);
  }
}

sub check_no_missing_order_confirmations {
  my ($self) = @_;

  my $days_delta       = 3;
  my $title            = "Alle offenen Auftragseingänge älter als $days_delta Werktage haben eine Auftragsbestätigung.";

  my $latest_transdate = DateTime->today_local->subtract_businessdays(days => $days_delta);

  my $orders           = SL::DB::Manager::Order->get_all_sorted(where => [record_type     => 'sales_order_intake',
                                                                          or              => [closed    => undef, closed    => 0],
                                                                          transdate       => {le => $latest_transdate},
                                                                          transdate       => {ge => $self->start_date},]);

  # Check, if order confirmations are in the worklfow.
  # (Maybe it is sufficient to list all order intakes which are not closed because
  # they will be closed when an related order confirmation is created.)
  my @not_confirmed_order_intakes;
  foreach my $order (@$orders) {
    my $lr = $order->linked_records(direction => 'to', recursive => 1);
    $lr    = [grep { 'SL::DB::Order' eq ref $_ && $_->is_type('sales_order') } @$lr];
    push @not_confirmed_order_intakes, $order->ordnumber if scalar @$lr == 0;
  }

  if (@not_confirmed_order_intakes) {
    $self->tester->ok(0, $title);

    $self->tester->diag("Folgende offene Auftragseingänge älter als $days_delta haben keine Auftragsbestätigung:");
    $self->tester->diag("Auftrageingangs-Nummer: " . $_) for @not_confirmed_order_intakes;

  } else {
    $self->tester->ok(1, $title);
  }

}

sub check_invoices_mailed {
  my ($self) = @_;

  my $title    = "Alle offenen Verkaufsrechnungen sind per Mail verschickt worden.";

  my $invoices = SL::DB::Manager::Invoice->get_all_sorted(where => [invoice => 1,
                                                                    type      => 'invoice',
                                                                    or        => [storno => undef, storno => 0],
                                                                    transdate => {ge => $self->start_date},]);
  $invoices    = [grep { !$_->closed } @$invoices];

  my @documents_not_mailed = $self->get_documents_not_mailed($invoices);
  $self->complain_documtens_not_mailed(
    \@documents_not_mailed,
    main_title => $title,
    sub_title  => "Folgende offenen Verkaufsrechungen sind nicht per Mail verschickt worden",
    nr_title   => "Rechnungs-Nummer"
  );
}

sub check_order_confirmations_mailed {
  my ($self) = @_;

  my $days_delta       = 1;
  my $title            = "Alle offenen Auftragsbestätigungen älter als $days_delta Werktage sind per Mail verschickt worden.";

  my $latest_transdate = DateTime->today_local->subtract_businessdays(days => $days_delta);

  my $orders           = SL::DB::Manager::Order->get_all_sorted(where => [record_type     => 'sales_order',
                                                                          or              => [closed    => undef, closed    => 0],
                                                                          transdate       => {le => $latest_transdate},
                                                                          transdate       => {ge => $self->start_date},]);

  my @documents_not_mailed = $self->get_documents_not_mailed($orders);
  $self->complain_documtens_not_mailed(
    \@documents_not_mailed,
    main_title => $title,
    sub_title  => "Folgende offenen Auftragsbestätigungen älter als $days_delta Werktage sind nicht per Mail verschickt worden",
    nr_title   => "Auftrags-Nummer"
  );
}

sub check_quotations_mailed {
  my ($self) = @_;

  my $days_delta       = 3;
  my $title            = "Alle offenen Angebote älter als $days_delta Werktage sind per Mail verschickt worden.";

  my $latest_transdate = DateTime->today_local->subtract_businessdays(days => $days_delta);

  my $orders           = SL::DB::Manager::Order->get_all_sorted(where => [record_type     => 'request_quotion',
                                                                          or              => [closed    => undef, closed    => 0],
                                                                          transdate       => {le => $latest_transdate},
                                                                          transdate       => {ge => $self->start_date},]);

  my @documents_not_mailed = $self->get_documents_not_mailed($orders);
  $self->complain_documtens_not_mailed(
    \@documents_not_mailed,
    main_title => $title,
    sub_title  => "Folgende offenen Angebote älter als $days_delta Werktage sind nicht per Mail verschickt worden",
    nr_title   => "Angebots-Nummer"
  );
}

sub get_documents_not_mailed {
  my ($self, $objects) = @_;

  my @documents_not_mailed;
  foreach my $object (@$objects) {
    my $mails = $object->linked_records(to => 'EmailJournal');
    push @documents_not_mailed, $object->record_number if scalar @$mails == 0;
  }

  return @documents_not_mailed;
}

sub complain_documtens_not_mailed {
  my ($self, $documents_not_mailed, %params) = @_;

  my $main_title = $params{main_title} | '';
  my $sub_title  = $params{sub_title}  | '';
  my $nr_title   = $params{nr_title}   | '';

  if (@{ $documents_not_mailed || [] }) {
    $self->tester->ok(0, $main_title);

    $self->tester->diag($sub_title . ":");
    $self->tester->diag($nr_title . ": " . $_) for @$documents_not_mailed;

  } else {
    $self->tester->ok(1, $main_title);
  }
}

# Check for all purchase invoices if the sum of all related purchase
# orders is greater than the sum of all related purchase invoices.
sub check_purchase_invoices_sums_against_purchase_orders {
  my ($self) = @_;

  my $title = "Die Netto-Summe der Einkaufsrechnungen ist kleiner oder gleich der Netto-Summe der Lieferantenaufträge.";

  my $purchase_invoices = SL::DB::Manager::PurchaseInvoice->get_all_sorted(where => ['!storno' => 1,
                                                                                     invoice   => 1,
                                                                                     transdate => {ge => $self->start_date},]);

  my @purchase_invoices_with_wrong_sums;
  foreach my $purchase_invoice (@$purchase_invoices) {
    if (!$purchase_invoice->check_sums_against_purchase_orders($purchase_invoice)) {
      push @purchase_invoices_with_wrong_sums, $purchase_invoice;
    }
  }

  if (@purchase_invoices_with_wrong_sums) {
    $self->tester->ok(0, $title);
    $self->tester->diag("Folgende " . scalar @purchase_invoices_with_wrong_sums . " Einkaufsrechnungen ergeben eine viel höhere Netto-Summe alsergeben eine viel höhere Netto-Summe als ursprüngliche beauftragt:");
    $self->tester->diag("Einkaufsrechnungs-Nummer vom " . $_->transdate_as_date . ": " . $_->record_number) for @purchase_invoices_with_wrong_sums;

  } else {
    $self->tester->ok(1, $title);
  }
}

# Check for all purchase invoices if the sum of all related sales
# orders is greater than the sum of all related purchase invoices.
sub check_purchase_invoices_sums_against_sales_orders {
  my ($self) = @_;

  my $title = "Die Summe der Einkaufsrechnungen ist kleiner oder gleich der Summe der Auftragsbestätigungen.";

  my $purchase_invoices = SL::DB::Manager::PurchaseInvoice->get_all_sorted(where => ['!storno' => 1,
                                                                                     invoice   => 1,
                                                                                     transdate => {ge => $self->start_date},]);

  my @purchase_invoices_with_wrong_sums;
  foreach my $purchase_invoice (@$purchase_invoices) {
    if (!$purchase_invoice->check_sums_against_sales_orders($purchase_invoice)) {
      push @purchase_invoices_with_wrong_sums, $purchase_invoice;
    }
  }

  if (@purchase_invoices_with_wrong_sums) {
    $self->tester->ok(0, $title);
    $self->tester->diag("Folgende " . scalar @purchase_invoices_with_wrong_sums . " Einkaufsrechnungen haben eine zu hohe Summe:");
    $self->tester->diag("Einkaufsrechnungs vom " . $_->transdate_as_date . ": " . $_->record_number) for @purchase_invoices_with_wrong_sums;

  } else {
    $self->tester->ok(1, $title);
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::BackgroundJob::SelfTest::NovoclonStrict - special tests novoclon

=head1 DESCRIPTION

Special tests for novoclon.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
