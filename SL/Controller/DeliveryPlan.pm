package SL::Controller::DeliveryPlan;

use strict;
use parent qw(SL::Controller::Base);

use Clone qw(clone);
use SL::DB::OrderItem;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Sorted;
use SL::Controller::Helper::Filtered;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(db_args flat_filter) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('sales_order_edit'); });

__PACKAGE__->make_filtered(
  MODEL             => 'OrderItem',
  LAUNDER_TO        => 'filter'
);
__PACKAGE__->make_paginated(
  MODEL         => 'OrderItem',
  ONLY          => [ qw(list) ],
);

__PACKAGE__->make_sorted(
  MODEL             => 'OrderItem',
  ONLY              => [ qw(list) ],

  DEFAULT_BY        => 'reqdate',
  DEFAULT_DIR       => 1,

  reqdate           => t8('Reqdate'),
  description       => t8('Description'),
  partnumber        => t8('Part Number'),
  qty               => t8('Qty'),
  shipped_qty       => t8('shipped'),
  not_shipped_qty   => t8('not shipped'),
  ordnumber         => t8('Order'),
  customer          => t8('Customer'),
);

my $delivery_plan_query = [
  'order.customer_id' => { gt => 0 },
  'order.closed' => 0,
  or => [ 'order.quotation' => 0, 'order.quotation' => undef ],

  # filter by shipped_qty < qty, read from innermost to outermost
  'id' => [ \"
    -- 3. resolve the desired information about those
    SELECT oi.id FROM (
      -- 2. slice only part, orderitem and both quantities from it
      SELECT parts_id, trans_id, qty, SUM(doi_qty) AS doi_qty FROM (
        -- 1. join orderitems and deliverorder items via record_links.
        --    also add customer data to filter for sales_orders
        SELECT oi.parts_id, oi.trans_id, oi.id, oi.qty, doi.qty AS doi_qty
        FROM orderitems oi, oe, record_links rl, delivery_order_items doi
        WHERE
          oe.id = oi.trans_id AND
          oe.customer_id IS NOT NULL AND
          (oe.quotation = 'f' OR oe.quotation IS NULL) AND
          NOT oe.closed AND
          rl.from_id = oe.id AND
          rl.from_id = oi.trans_id AND
          oe.id = oi.trans_id AND
          rl.from_table = 'oe' AND
          rl.to_table = 'delivery_orders' AND
          rl.to_id = doi.delivery_order_id AND
          oi.parts_id = doi.parts_id
      ) tuples GROUP BY parts_id, trans_id, qty
    ) partials
    LEFT JOIN orderitems oi ON partials.parts_id = oi.parts_id AND partials.trans_id = oi.trans_id
    WHERE oi.qty > doi_qty

    UNION ALL

    -- 4. since the join over record_links fails for sales_orders wihtout any delivery order
    --    retrieve those without record_links at all
    SELECT oi.id FROM orderitems oi, oe
    WHERE
      oe.id = oi.trans_id AND
      oe.customer_id IS NOT NULL AND
      (oe.quotation = 'f' OR oe.quotation IS NULL) AND
      NOT oe.closed AND
      oi.trans_id NOT IN (
        SELECT from_id
        FROM record_links rl
        WHERE
          rl.from_table ='oe' AND
          rl.to_table = 'delivery_orders'
      )

    UNION ALL

    -- 5. In case someone deleted a line of the delivery_order there will be a record_link (4 fails)
    --    but there won't be a delivery_order_items to find (3 fails too). Search for orphaned orderitems this way
    SELECT oi.id FROM orderitems AS oi, oe, record_links AS rl
    WHERE
      rl.from_table = 'oe' AND
      rl.to_table = 'delivery_orders' AND

      oi.trans_id = rl.from_id AND
      oi.parts_id NOT IN (
        SELECT doi.parts_id FROM delivery_order_items AS doi WHERE doi.delivery_order_id = rl.to_id
      ) AND

      oe.id = oi.trans_id AND

      oe.customer_id IS NOT NULL AND
      (oe.quotation = 'f' OR oe.quotation IS NULL) AND
      NOT oe.closed
  " ],
];

sub action_list {
  my ($self) = @_;

  $self->make_filter_summary;

  my $orderitems = $self->get_models(query => $delivery_plan_query, with_objects => [ 'order', 'order.customer', 'part' ]);

  $self->prepare_report;
  $self->report_generator_list_objects(report => $self->{report}, objects => $orderitems);
}

# private functions
#
sub prepare_report {
  my ($self)      = @_;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = qw(reqdate customer ordnumber partnumber description qty shipped_qty not_shipped_qty);
  my @sortable    = qw(reqdate customer ordnumber partnumber description);

  my %column_defs = (
    reqdate           => {      sub => sub { $_[0]->reqdate_as_date || $_[0]->order->reqdate_as_date                         } },
    description       => {      sub => sub { $_[0]->description                                                              },
                           obj_link => sub { $self->link_to($_[0]->part)                                                     } },
    partnumber        => {      sub => sub { $_[0]->part->partnumber                                                         },
                           obj_link => sub { $self->link_to($_[0]->part)                                                     } },
    qty               => {      sub => sub { $_[0]->qty_as_number . ' ' . $_[0]->unit                                        } },
    shipped_qty       => {      sub => sub { $::form->format_amount(\%::myconfig, $_[0]->shipped_qty, 2) . ' ' . $_[0]->unit } },
    not_shipped_qty   => {      sub => sub { $::form->format_amount(\%::myconfig, $_[0]->qty - $_[0]->shipped_qty, 2) . ' ' . $_[0]->unit } },
    ordnumber         => {      sub => sub { $_[0]->order->ordnumber                                                         },
                           obj_link => sub { $self->link_to($_[0]->order)                                                    } },
    customer          => {      sub => sub { $_[0]->order->customer->name                                                    },
                           obj_link => sub { $self->link_to($_[0]->order->customer)                                          } },
  );

  map { $column_defs{$_}->{text} = $::locale->text( $self->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'DeliveryPlan',
    output_format         => 'HTML',
    top_info_text         => $::locale->text('Delivery Plan for currently outstanding sales orders'),
    raw_top_info_text     => $self->render('delivery_plan/report_top',    { output => 0 }),
    raw_bottom_info_text  => $self->render('delivery_plan/report_bottom', { output => 0 }),
    title                 => $::locale->text('Delivery Plan'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;
  $self->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);

  $self->disable_pagination if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my @filters = (
    [ $filter->{order}{"ordnumber:substr::ilike"},                $::locale->text('Number')                                             ],
    [ $filter->{part}{"partnumber:substr::ilike"},                $::locale->text('Part Number')                                        ],
    [ $filter->{"description:substr::ilike"},                     $::locale->text('Part Description')                                   ],
    [ $filter->{"reqdate:date::ge"},                              $::locale->text('Delivery Date') . " " . $::locale->text('From Date') ],
    [ $filter->{"reqdate:date::le"},                              $::locale->text('Delivery Date') . " " . $::locale->text('To Date')   ],
    [ $filter->{"qty:number"},                                    $::locale->text('Quantity')                                           ],
    [ $filter->{order}{customer}{"name:substr::ilike"},           $::locale->text('Customer')                                           ],
    [ $filter->{order}{customer}{"customernumber:substr::ilike"}, $::locale->text('Customer Number')                                    ],
  );

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

sub link_to {
  my ($self, $object, %params) = @_;

  return unless $object;
  my $action = $params{action} || 'edit';

  if ($object->isa('SL::DB::Order')) {
    my $type   = $object->type;
    my $vc     = $object->is_sales ? 'customer' : 'vendor';
    my $id     = $object->id;

    return "oe.pl?action=$action&type=$type&vc=$vc&id=$id";
  }
  if ($object->isa('SL::DB::Part')) {
    my $id     = $object->id;
    return "ic.pl?action=$action&id=$id";
  }
  if ($object->isa('SL::DB::Customer')) {
    my $id     = $object->id;
    return "controller.pl?action=CustomerVendor/$action&id=$id&db=customer";
  }
}

1;
