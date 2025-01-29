package SL::Controller::DeliveryValueReport;

use strict;
use parent qw(SL::Controller::Base);

use Clone qw(clone);
use SL::DB::OrderItem;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::Business;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String;
use SL::Helper::ShippedQty;
use SL::AM;
use SL::DBUtils qw(selectall_as_map);
use List::MoreUtils qw(uniq);
use Carp;
use Data::Dumper;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(models vc all_employees all_businesses all_partsgroups) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('delivery_value_report'); });

my %sort_columns = (
  reqdate                 => t8('Reqdate'),
  customer                => t8('Customer'),
  vendor                  => t8('Vendor'),
  ordnumber               => t8('Order'),
  partnumber              => t8('Part Number'),
  description             => t8('Description'),
  qty                     => t8('Qty in Order'),
  unit                    => t8('Unit'),
  netto_qty               => t8('Net value in Order'),
  not_shipped_qty         => t8('not shipped'),
  netto_not_shipped_qty   => t8('Net value without delivery orders'),
  shipped_qty             => t8('Qty in delivery orders'),
  netto_shipped_qty       => t8('Net Value in delivery orders'),
  delivered_qty           => t8('transferred in / out'),
  netto_delivered_qty     => t8('Net value transferred in / out'),
  do_closed_qty           => t8('Qty in closed delivery orders'),
  netto_do_closed_qty     => t8('Net value in closed delivery orders'),
);




#
# action
#

sub action_list {
  my ($self) = @_;
  $self->make_filter_summary;
  $self->prepare_report;

  my $orderitems = $self->models->get;
  $self->calc_qtys_price($orderitems);
  $self->setup_list_action_bar;
  $self->report_generator_list_objects(report => $self->{report}, objects => $orderitems);
}

sub prepare_report {
  my ($self)      = @_;

  my $vc           = $self->vc;
  my $report       = SL::ReportGenerator->new(\%::myconfig, $::form);
  my $csv_option   = $::form->{report_generator_output_format};
  $report->{title} = t8('Delivery Value Report');
  $self->{report}  = $report;

  my @columns     = qw(reqdate customer vendor ordnumber partnumber description unit qty netto_qty
                       not_shipped_qty netto_not_shipped_qty shipped_qty netto_shipped_qty delivered_qty
                       netto_delivered_qty do_closed_qty netto_do_closed_qty);


  my @sortable    = qw(reqdate customer vendor ordnumber partnumber description);

  # if csv report export no units
  my $rp_csv_mod  = ($csv_option eq 'CSV') ? 1 : '';

  my %column_defs = (
    reqdate           => {      sub => sub { $_[0]->reqdate_as_date || $_[0]->order->reqdate_as_date          } },
    description       => {      sub => sub { $_[0]->description                                               },
                           obj_link => sub { $self->link_to($_[0]->part)                                      } },
    partnumber        => {      sub => sub { $_[0]->part->partnumber                                          },
                           obj_link => sub { $self->link_to($_[0]->part)                                      } },
    qty               => {      sub => sub { _format_qty($_[0], 'qty', $rp_csv_mod)                           } },
    netto_qty         => {      sub => sub { _format_val($_[0], 'qty')                                        },},
    unit              => {      sub => sub {  $_[0]->unit                                                     },
                            visible => $rp_csv_mod                                                              },
    shipped_qty       => {      sub => sub { _format_qty($_[0], 'shipped_qty', $rp_csv_mod)                   } },
    netto_shipped_qty => {      sub => sub { _format_val($_[0], 'shipped_qty')                                },},
    not_shipped_qty   => {      sub => sub { _format_qty($_[0], 'not_shipped_qty', $rp_csv_mod)               } },
    netto_not_shipped_qty => {  sub => sub { _format_val($_[0], 'not_shipped_qty')                            },},
    delivered_qty     => {      sub => sub { _format_qty($_[0], 'delivered_qty', $rp_csv_mod)                 } },
    netto_delivered_qty => {    sub => sub { _format_val($_[0], 'delivered_qty')                              },},
    do_closed_qty     => {      sub => sub { _format_qty($_[0], 'do_closed_qty', $rp_csv_mod)                 },},
    netto_do_closed_qty => {    sub => sub { _format_val($_[0], 'do_closed_qty')                              },},
    ordnumber         => {      sub => sub { $_[0]->order->ordnumber                                           },
                           obj_link => sub { $self->link_to($_[0]->order)                                      } },
    vendor            => {      sub => sub { $_[0]->order->vendor->name                                        },
                            visible => $vc eq 'vendor',
                           obj_link => sub { $self->link_to($_[0]->order->vendor)                              } },
    customer          => {      sub => sub { $_[0]->order->customer->name                                      },
                            visible => $vc eq 'customer',
                           obj_link => sub { $self->link_to($_[0]->order->customer)                            } },
  );

  $column_defs{$_}->{text} = $sort_columns{$_} for keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'DeliveryValueReport',
    output_format         => 'HTML',
    top_info_text         => ($vc eq 'customer') ? t8('Delivery Value Report for currently open sales orders') :
                                                   t8('Delivery Value Report for currently outstanding purchase orders'),
    title                 => $::locale->text('Delivery Value Report'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter vc));
  $report->set_options_from_form;
  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->finalize; # for filter laundering
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);
  $report->set_options(
    raw_top_info_text     => $self->render('delivery_value_report/report_top',    { output => 0 }),
    raw_bottom_info_text  => $self->render('delivery_value_report/report_bottom', { output => 0 }, models => $self->models),
  );
}




#
# filter
#

sub make_filter_summary {
  my ($self) = @_;
  my $vc     = $self->vc;
  my ($business, $employee, $partsgroup);

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  $business   = SL::DB::Business->new(id => $filter->{order}{customer}{"business_id"})->load->description if $filter->{order}{customer}{"business_id"};
  $employee   = SL::DB::Employee->new(id => $filter->{order}{employee_id})->load->name                    if $filter->{order}{employee_id};
  $partsgroup = SL::DB::PartsGroup->new(id => $filter->{part}{partsgroup_id})->load->partsgroup           if $filter->{part}{partsgroup_id};

  my @filters = (
    [ $filter->{order}{"ordnumber:substr::ilike"},                    $::locale->text('Number')                                             ],
    [ $filter->{order}{globalproject}{"projectnumber:substr::ilike"}, $::locale->text('Document Project Number')                            ],
    [ $filter->{part}{"partnumber:substr::ilike"},                    $::locale->text('Part Number')                                        ],
    [ $filter->{"description:substr::ilike"},                         $::locale->text('Part Description')                                   ],
    [ $filter->{"reqdate:date::ge"},                                  $::locale->text('Delivery Date') . " " . $::locale->text('From Date') ],
    [ $filter->{"reqdate:date::le"},                                  $::locale->text('Delivery Date') . " " . $::locale->text('To Date')   ],
    [ $filter->{"qty:number"},                                        $::locale->text('Quantity')                                           ],
    [ $filter->{order}{vendor}{"name:substr::ilike"},                 $::locale->text('Vendor')                                             ],
    [ $filter->{order}{vendor}{"vendornumber:substr::ilike"},         $::locale->text('Vendor Number')                                      ],
    [ $filter->{order}{customer}{"name:substr::ilike"},               $::locale->text('Customer')                                           ],
    [ $filter->{order}{customer}{"customernumber:substr::ilike"},     $::locale->text('Customer Number')                                    ],
    [ $business,                                                      $::locale->text('Customer type')                                      ],
    [ $employee,                                                      $::locale->text('Employee')                                           ],
    [ $partsgroup,                                                    $::locale->text('Partsgroup')                                         ],
  );

  # flags for with_object 'part'
  my %flags = (
    part     => $::locale->text('Parts'),
    service  => $::locale->text('Services'),
    assembly => $::locale->text('Assemblies'),
  );
  my @flags = map { $flags{$_} } @{ $filter->{part}{type} || [] };

  for (@flags) {
    push @filter_strings, $_ if $_;
  }
  for (@filters) {
    push @filter_strings, "$_->[1]: $_->[0]" if $_->[0];
  }
  $self->{filter_summary} = join ', ', @filter_strings;
}



#
# helpers
#
sub init_models {
  my ($self) = @_;
  my $vc     = $self->vc;
  my $record_type = ($vc eq 'customer' ? SALES_ORDER_TYPE() : PURCHASE_ORDER_TYPE());
  SL::Controller::Helper::GetModels->new(
    controller            => $self,
    model                 => 'OrderItem',
    sorted                => {
      _default              => {
        by                    => 'reqdate',
        dir                   => 1,
      },
      %sort_columns,
    },
    # show only open (sales|purchase) orders
    query                 => [ 'order.closed' => '0',  "order.${vc}_id" => { gt => 0 },
                               'order.record_type' => $record_type                       ],
    with_objects          => [ 'order', "order.$vc", 'part' ],
    additional_url_params => { vc => $vc},
  )
}

sub init_vc {
  return $::form->{vc} if ($::form->{vc} eq 'customer' || $::form->{vc} eq 'vendor') || croak "self (DeliveryValueReport) has no vc defined";
}
sub init_all_employees {
  return SL::DB::Manager::Employee->get_all_sorted;
}
sub init_all_businesses {
  return SL::DB::Manager::Business->get_all_sorted;
}
sub init_all_partsgroups {
  return SL::DB::Manager::PartsGroup->get_all_sorted;
}


sub link_to {
  my ($self, $object, %params) = @_;

  return unless $object;
  my $action = $params{action} || 'edit';

  if ($object->isa('SL::DB::Order')) {
    my $type   = $object->type;
    my $id     = $object->id;
    return "controller.pl?action=Order/$action&type=$type&id=$id";
  }
  if ($object->isa('SL::DB::Part')) {
    my $id     = $object->id;
    return "controller.pl?action=Part/$action&part.id=$id";
  }
  if ($object->isa('SL::DB::Customer')) {
    my $id     = $object->id;
    return "controller.pl?action=CustomerVendor/$action&id=$id&db=customer";
  }
}

sub _format_qty {
  my ($item, $col, $csv_mod) = @_;

  $::form->format_amount(\%::myconfig, $item->{$col}, 2) .  ($csv_mod ? '' : ' ' .  $item->unit)
}

sub _format_val {
  my ($item, $col) = @_;

  $::form->format_amount(\%::myconfig, $item->{$col} * $item->sellprice * (1 - $item->discount) / ($item->price_factor || 1), 2)
}


sub calc_qtys_price {
  my ($self, $orderitems) = @_;

  return unless scalar @$orderitems;

  SL::Helper::ShippedQty
    ->new(require_stock_out => 1)
    ->calculate($orderitems)
    ->write_to_objects;

  $_->{delivered_qty} = delete $_->{shipped_qty} for @$orderitems;

  my $helper = SL::Helper::ShippedQty
    ->new(require_stock_out => 0, keep_matches => 1)
    ->calculate($orderitems)
    ->write_to_objects;

  for my $item (@$orderitems) {
    $item->{not_shipped_qty} = $item->qty - $item->{shipped_qty};
    $item->{do_closed_qty}   = 0;

    my $price_factor = $item->price_factor || 1;
  }

  if (my @all_doi_ids = uniq map { $_->[1] } @{ $helper->matches }) {
    my %oi_by_id = map { $_->id => $_ } @$orderitems;
    my $query    = sprintf <<'', join ', ', ("?")x@all_doi_ids;
      SELECT DISTINCT doi.id, closed FROM delivery_orders
      LEFT JOIN delivery_order_items doi ON (doi.delivery_order_id = delivery_orders.id)
      WHERE doi.id IN (%s)

    my %doi_is_closed = selectall_as_map($::form, SL::DB->client->dbh, $query, (id => 'closed'), @all_doi_ids);

    for my $match (@{ $helper->matches }) {
      next unless $doi_is_closed{$match->[1]};
      $oi_by_id{$match->[0]}->{do_closed_qty} += $match->[2];
    }
  }
}

sub setup_list_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#filter_form', { action => 'DeliveryValueReport/list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::DeliveryValueReport - Controller for Delivery Value Report

=head2 OVERVIEW

Controller class for Delivery Value Report

The goal of the report is to determine which goods and at what costs are already delivered, transfered in
relation to open orders, orders in process.


Inherited from the base controller class, this controller implements the Delivery Value Report.
Historically the idea derived from a customer extension by thinking: Ah, we just need the Delivery Plan
put some more columns in it and then we have a pseudo "Production, Planing, Report" with an additional
emphasis on expected future cashflow.
Some problems exists with the current report: The definition of not fully delivered sales / purchase order
is very (customer) special, in general a simple check on order is open should be a sensible workflow value.
Secondly a major database flaw (no persistent ids in order_items) made it impossible to determine the origin
of items in terms of linked records. One assumption build in the original DeliveryPlan was that the part_ids
are equal. This breaks if the document has the same item on different positions. The next idea was to check
for individual item reqdates.
After some arguing we decided to implement persistent ids for all items and link them directly via record_links.
This linking has been secrectly active since version 3.2, therefore this redesign is possible.
Currently the report even works correctly even if the same part has been manually put in another position, renamed or some
other metadata for the position has been altered. This is due to the fact that a hidden converted_from_previous_document is
used in the position.

The main intelligence is this query (qty_stocked as comments):

    SELECT oi.id,and more metadata , -- dois.qty as qty_stocked,
    FROM record_links rl
    INNER JOIN delivery_order_items doi ON (doi.id = rl.to_id)
    INNER JOIN orderitems oi            ON (oi.id  = rl.from_id)
    INNER JOIN delivery_orders doe      ON (doe.id = doi.delivery_order_id)
    --INNER JOIN delivery_order_items_stock dois ON (doi.id = dois.delivery_order_item_id)
    WHERE rl.from_table = 'orderitems'
      AND rl.to_table   = 'delivery_order_items'

Get all entries which were converted from orderitems to delivery_order_items (WHERE).
The persistent id are in rl, therefore we can fetch orderitems and delivery_order_items.
The join on delivery_orders (doe) is only needed for the current state of the delivery order (closed, delivered).

=head1 FUNCTIONS

=over 2

=item C<action_list>

=item C<prepare_report>

=item C<make_filter_summary>

=item C<calc_qtys_price>

=item C<link_to>

=item C<init_models>

=item C<init_vc>

=item C<init_all_employees>

=item C<init_all_businesses>

=back

=head1 TODOS

Currently no foreign currencies and OrderItems with taxincluded are calculated / supported. The report can be easily extended
for the real stocked qty. The report is really easy to implement and customise if your model is focussed straight.
For long term maintaineance it would be wise to add more testcases for the conversion from orders to delivery_orders.
Right now record_links are tested only from document to document and the convert_invoice method (via task server) has a
test case with record_links items included. Furhtermore I personally dislike the calcs in the %columns_def, but for a quick report
this is ok, though if we redesign this further, the taxincluded / currency cases should be implemented as well.


=head1 AUTHOR

Jan Büren E<lt>jan@kivitendo-premium.deE<gt> (based on DeliveryPlan.pm by Sven)

=cut
