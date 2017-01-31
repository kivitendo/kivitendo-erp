package ARAP;

use SL::AM;
use SL::Common;
use SL::DBUtils;
use SL::MoreCommon;
use SL::DB;
use Data::Dumper;

use strict;

sub close_orders_if_billed {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my %params = @_;

  Common::check_params(\%params, qw(arap_id table));

  my $myconfig  = \%main::myconfig;
  my $form      = $main::form;

  my $dbh       = $params{dbh} || SL::DB->client->dbh;

  # First, find all order IDs from which this invoice has been
  # created. Either directly by a conversion from an order to this invoice
  # or indirectly from an order to one or more delivery orders and
  # from those to this invoice.

  # Direct conversion "order -> invoice":
  my @links     = RecordLinks->get_links('dbh'        => $dbh,
                                         'from_table' => 'oe',
                                         'to_table'   => $params{table},
                                         'to_id'      => $params{arap_id});

  my %oe_id_map = map { $_->{from_id} => 1 } @links;

  # Indirect conversion "order -> delivery orders -> invoice":
  my @do_links  = RecordLinks->get_links('dbh'        => $dbh,
                                         'from_table' => 'delivery_orders',
                                         'to_table'   => $params{table},
                                         'to_id'      => $params{arap_id});

  foreach my $do_link (@do_links) {
    @links      = RecordLinks->get_links('dbh'        => $dbh,
                                         'from_table' => 'oe',
                                         'to_table'   => 'delivery_orders',
                                         'to_id'      => $do_link->{from_id});

    map { $oe_id_map{$_->{from_id}} = 1 } @links;
  }

  my @oe_ids = keys %oe_id_map;

  # No orders found? Nothing to do then, so let's return.
  return $main::lxdebug->leave_sub unless @oe_ids;

  my $all_units = AM->retrieve_all_units;

  my $qtyfactor = $params{table} eq 'ap' ? '* -1' : '';
  my $q_billed  = qq|SELECT i.parts_id, i.qty ${qtyfactor} AS qty, i.unit, p.unit AS partunit
                     FROM invoice i
                     LEFT JOIN parts p ON (i.parts_id = p.id)
                     WHERE i.trans_id = ? AND i.assemblyitem is false|;
  my $h_billed  = prepare_query($form, $dbh, $q_billed);

  my $q_ordered = qq|SELECT oi.parts_id, oi.qty, oi.unit, p.unit AS partunit
                      FROM orderitems oi
                      LEFT JOIN parts p ON (oi.parts_id = p.id)
                      WHERE oi.trans_id = ?|;
  my $h_ordered = prepare_query($form, $dbh, $q_ordered);

  my @close_oe_ids;

  # Interate over each order and look up all invoices created for
  # said order. Again consider both direct conversions and indirect
  # conversions via delivery orders.
  foreach my $oe_id (@oe_ids) {

    # Dont close orders with periodic invoice
    next if SL::DB::Manager::PeriodicInvoicesConfig->find_by(oe_id => $oe_id);

    # Direct conversions "order -> invoice":
    @links          = RecordLinks->get_links('dbh'        => $dbh,
                                             'from_table' => 'oe',
                                             'from_id'    => $oe_id,
                                             'to_table'   => $params{table},);

    my %arap_id_map = map { $_->{to_id} => 1 } @links;

    # Indirect conversions "order -> delivery orders -> invoice":
    @do_links       = RecordLinks->get_links('dbh'        => $dbh,
                                             'from_table' => 'oe',
                                             'from_id'    => $oe_id,
                                             'to_table'   => 'delivery_orders',);
    foreach my $do_link (@do_links) {
      @links        = RecordLinks->get_links('dbh'        => $dbh,
                                             'from_table' => 'delivery_orders',
                                             'from_id'    => $do_link->{to_id},
                                             'to_table'   => $params{table},);

      map { $arap_id_map{$_->{to_id}} = 1 } @links;
    }

    my @arap_ids = keys %arap_id_map;

    next if (!scalar @arap_ids);

    # Retrieve all positions for this order. Calculate the ordered quantity for each position.
    my %ordered = ();

    do_statement($form, $h_ordered, $q_ordered, $oe_id);

    while (my $ref = $h_ordered->fetchrow_hashref()) {
      $ref->{baseqty} = $ref->{qty} * AM->convert_unit($ref->{unit}, $ref->{partunit}, $all_units);

      if ($ordered{$ref->{parts_id}}) {
        $ordered{$ref->{parts_id}}->{baseqty} += $ref->{baseqty};
      } else {
        $ordered{$ref->{parts_id}}             = $ref;
      }
    }

    # Retrieve all positions for all invoices that have been created from this order.
    my %billed  = ();

    foreach my $arap_id (@arap_ids) {
      do_statement($form, $h_billed, $q_billed, $arap_id);

      while (my $ref = $h_billed->fetchrow_hashref()) {
        $ref->{baseqty} = $ref->{qty} * AM->convert_unit($ref->{unit}, $ref->{partunit}, $all_units);

        if ($billed{$ref->{parts_id}}) {
          $billed{$ref->{parts_id}}->{baseqty} += $ref->{baseqty};
        } else {
          $billed{$ref->{parts_id}}             = $ref;
        }
      }
    }

    # Check all ordered positions. If all positions have been billed completely then this order can be closed.
    my $all_billed = 1;
    foreach my $part (values %ordered) {
      if (!$billed{$part->{parts_id}} || ($billed{$part->{parts_id}}->{baseqty} < $part->{baseqty})) {
        $all_billed = 0;
        last;
      }
    }

    push @close_oe_ids, $oe_id if ($all_billed);
  }

  $h_billed->finish;
  $h_ordered->finish;

  # Close orders that have been billed fully.
  if (scalar @close_oe_ids) {
    SL::DB->client->with_transaction(sub {
      my $query = qq|UPDATE oe SET closed = TRUE WHERE id IN (| . join(', ', ('?') x scalar @close_oe_ids) . qq|)|;
      do_query($form, $dbh, $query, @close_oe_ids);
      1;
    }) or do { die SL::DB->client->error };
  }

  $main::lxdebug->leave_sub();
}

1;
