package SL::Controller::DeliveryPlan;

use strict;
use parent qw(SL::Controller::Base);

use Clone qw(clone);
use SL::DB::OrderItem;
use SL::DB::Business;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String;
use SL::Helper::ShippedQty;
use SL::AM;
use SL::DBUtils ();
use Carp;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(db_args flat_filter) ],
  'scalar --get_set_init' => [ qw(models all_edit_right vc use_linked_items all_employees all_businesses all_departments) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('delivery_plan'); });

my %sort_columns = (
  reqdate           => t8('Reqdate'),
  description       => t8('Description'),
  partnumber        => t8('Part Number'),
  qty               => t8('Qty'),
  shipped_qty       => t8('shipped'),
  not_shipped_qty   => t8('not shipped'),
  ordnumber         => t8('Order'),
  customer          => t8('Customer'),
  vendor            => t8('Vendor'),
);


sub action_list {
  my ($self) = @_;
  $self->make_filter_summary;
  $self->prepare_report;

  my $orderitems = $self->models->get;
  $self->calc_qtys($orderitems);
  $self->setup_list_action_bar;
  $self->report_generator_list_objects(report => $self->{report}, objects => $orderitems);
}

# private functions
#
sub prepare_report {
  my ($self)      = @_;

  my $vc          = $self->vc;
  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = qw(reqdate customer vendor ordnumber partnumber description qty shipped_qty not_shipped_qty);

  my @sortable    = qw(reqdate customer vendor ordnumber partnumber description);

  my %column_defs = (
    reqdate           => {      sub => sub { $_[0]->reqdate_as_date || $_[0]->order->reqdate_as_date                         } },
    description       => {      sub => sub { $_[0]->description                                                              },
                           obj_link => sub { $self->link_to($_[0]->part)                                                     } },
    partnumber        => {      sub => sub { $_[0]->part->partnumber                                                         },
                           obj_link => sub { $self->link_to($_[0]->part)                                                     } },
    qty               => {      sub => sub { $_[0]->qty_as_number . ' ' . $_[0]->unit                                        } },
    shipped_qty       => {      sub => sub { $::form->format_amount(\%::myconfig, $_[0]{shipped_qty}, 2) . ' ' . $_[0]->unit } },
    not_shipped_qty   => {      sub => sub { $::form->format_amount(\%::myconfig, $_[0]->qty - $_[0]{shipped_qty}, 2) . ' ' . $_[0]->unit } },
    ordnumber         => {      sub => sub { $_[0]->order->ordnumber                                                         },
                           obj_link => sub { $self->link_to($_[0]->order)                                                    } },
    vendor            => {      sub => sub { $_[0]->order->vendor->name                                                      },
                            visible => $vc eq 'vendor',
                           obj_link => sub { $self->link_to($_[0]->order->vendor)                                            } },
    customer          => {      sub => sub { $_[0]->order->customer->name                                                    },
                            visible => $vc eq 'customer',
                           obj_link => sub { $self->link_to($_[0]->order->customer)                                          } },
  );

  $column_defs{$_}->{text} = $sort_columns{$_} for keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'DeliveryPlan',
    output_format         => 'HTML',
    top_info_text         => ($vc eq 'customer') ? $::locale->text('Delivery Plan for currently outstanding sales orders') :
                                                   $::locale->text('Delivery Plan for currently outstanding purchase orders'),
    title                 => $::locale->text('Delivery Plan'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter vc use_linked_items));
  $report->set_options_from_form;
  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->finalize; # for filter laundering
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);
  $report->set_options(
    raw_top_info_text     => $self->render('delivery_plan/report_top',    { output => 0 }),
    raw_bottom_info_text  => $self->render('delivery_plan/report_bottom', { output => 0 }, models => $self->models),
  );
}

sub calc_qtys {
  my ($self, $orderitems) = @_;

  return unless scalar @$orderitems;

  SL::Helper::ShippedQty
    ->new(fill_up => !$self->use_linked_items)
    ->calculate($orderitems)
    ->write_to_objects;
}

sub make_filter_summary {
  my ($self) = @_;
  my $vc     = $self->vc;
  my ($business, $employee, $department);

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  $business = SL::DB::Business->new(id => $filter->{order}{customer}{"business_id"})->load->description if $filter->{order}{customer}{"business_id"};
  $employee = SL::DB::Employee->new(id => $filter->{order}{employee_id})->load->name if $filter->{order}{employee_id};
  $department = SL::DB::Department->new(id => $filter->{order}{department_id})->load->description if $filter->{order}{department_id};

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
    [ $department,                                                    $::locale->text('Department')                                         ],
    [ $employee,                                                      $::locale->text('Employee')                                           ],
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

sub delivery_plan_query {
  my ($self) = @_;
  my $vc     = $self->vc;
  my $employee_id = SL::DB::Manager::Employee->current->id;
  my $oe_owner = $_[0]->all_edit_right ? '' : " oe.employee_id = $employee_id AND";

  [
  "order.${vc}_id" => { gt => 0 },
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
          oe.${vc}_id IS NOT NULL AND
          (oe.quotation = 'f' OR oe.quotation IS NULL) AND
          NOT oe.closed AND
          $oe_owner
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

    -- 4. since the join over record_links fails for sales_orders without any delivery order
    --    retrieve those without record_links at all
    SELECT oi.id FROM orderitems oi, oe
    WHERE
      oe.id = oi.trans_id AND
      oe.${vc}_id IS NOT NULL AND
      (oe.quotation = 'f' OR oe.quotation IS NULL) AND
      NOT oe.closed AND
      $oe_owner
      oi.trans_id NOT IN (
        SELECT from_id
        FROM record_links rl
        WHERE
          rl.from_table ='oe' AND
          rl.to_table = 'delivery_orders'
      )

    UNION ALL

    -- 5. now for the really nasty cases.
    --    If someone partially delivered an order in several delivery orders,
    --    there will be lots of record_links (4 doesn't catch those) but those
    --    won't have matching part_ids in delivery_order_items, so 1-3 can't
    --    find anything
    --    In this case aggreg record_links - delivery_order - delivery_order_items
    --    slice only oe.id, parts_id and sum of of qty
    --    left join that onto orderitems to get matching qtys in doi while retaining
    --    entrys without matches and then throw out those without record_links
    --    TODO: join this and 1-3 into a general case
                  -- need debug info? uncomment these:
    SELECT oi.id  -- ,oi.trans_id, oi.parts_id, coalesce(sum, 0), agg.parts_id
    FROM orderitems oi LEFT JOIN (
      SELECT rl.from_id as oid, doi.parts_id, sum(doi.qty) FROM (
        SELECT from_id, to_id
        FROM record_links rl
        LEFT JOIN oe ON oe.id = from_id
        WHERE
          rl.from_table = 'oe' AND
          rl.to_table = 'delivery_orders' AND

          oe.${vc}_id IS NOT NULL AND
          $oe_owner
          (oe.quotation = 'f' OR oe.quotation IS NULL) AND NOT oe.closed
      ) rl
      LEFT JOIN delivery_order_items doi ON (rl.to_id = doi.delivery_order_id)
      GROUP BY rl.from_id, doi.parts_id
    ) agg ON (agg.oid = oi.trans_id AND agg.parts_id = oi.parts_id)
    LEFT JOIN oe ON oe.id = oi.trans_id
    WHERE
      EXISTS (
        SELECT to_id
        FROM record_links rl
        WHERE oi.trans_id = rl.from_id AND rl.from_table = 'oe' AND rl.to_table = 'delivery_orders'
      ) AND
      coalesce(sum, 0) < oi.qty AND
      oe.${vc}_id IS NOT NULL AND
      $oe_owner
      (oe.quotation = 'f' OR oe.quotation IS NULL) AND NOT oe.closed
  " ], # make emacs happy again: '
  ]
}

sub delivery_plan_query_linked_items {
  my ($self) = @_;
  my $vc     = $self->vc;
  my $employee_id = SL::DB::Manager::Employee->current->id;
  my $oe_owner = $_[0]->all_edit_right ? '' : " oe.employee_id = $employee_id AND";

  [
  "order.${vc}_id" => { gt => 0 },
  'order.closed' => 0,
  or => [ 'order.quotation' => 0, 'order.quotation' => undef ],

  # filter by shipped_qty < qty, read from innermost to outermost
  'id' => [ \"
    SELECT id FROM (
      SELECT oi.qty, oi.id, SUM(doi.qty) AS doi_qty
      FROM orderitems oi, oe, record_links rl, delivery_order_items doi
      WHERE
        oe.id = oi.trans_id AND
        oe.${vc}_id IS NOT NULL AND
        (oe.quotation = 'f' OR oe.quotation IS NULL) AND
        NOT oe.closed AND
        $oe_owner
        doi.id = rl.to_id AND
        rl.from_table = 'orderitems'AND
        rl.to_table   = 'delivery_order_items' AND
        rl.from_id = oi.id
      GROUP BY oi.id
    ) linked
    WHERE qty > doi_qty

    UNION ALL

    -- 2. since the join over record_links fails for items not in any delivery order
    --    retrieve those without record_links at all
    SELECT oi.id FROM orderitems oi, oe
    WHERE
      oe.id = oi.trans_id AND
      oe.${vc}_id IS NOT NULL AND
      (oe.quotation = 'f' OR oe.quotation IS NULL) AND
      NOT oe.closed AND
      $oe_owner
      oi.id NOT IN (
        SELECT from_id
        FROM record_links rl
        WHERE
          rl.from_table ='orderitems' AND
          rl.to_table = 'delivery_order_items'
      )

  " ], # make emacs happy again: " ]
  ]
}

sub init_models {
  my ($self) = @_;
  my $vc     = $self->vc;

  my $query = $self->use_linked_items ? $self->delivery_plan_query_linked_items
            :                           $self->delivery_plan_query;

  SL::Controller::Helper::GetModels->new(
    controller   => $self,
    model        => 'OrderItem',
    sorted       => {
      _default     => {
        by           => 'reqdate',
        dir          => 1,
      },
      %sort_columns,
    },
    query        => $query,
    with_objects => [ 'order', "order.$vc", 'part' ],
    additional_url_params => { vc => $vc, use_linked_items => $self->use_linked_items },
  );
}

sub init_all_edit_right {
  $::auth->assert('sales_all_edit', 1)
}
sub init_vc {
  return $::form->{vc} if ($::form->{vc} eq 'customer' || $::form->{vc} eq 'vendor') || croak "self (DeliveryPlan) has no vc defined";
}

sub init_use_linked_items {
  !!$::form->{use_linked_items};
}

sub init_all_employees {
  return SL::DB::Manager::Employee->get_all_sorted;
}
sub init_all_businesses {
  return SL::DB::Manager::Business->get_all_sorted;
}
sub init_all_departments {
  return SL::DB::Manager::Department->get_all_sorted;
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
    return "controller.pl?action=Part/$action&part.id=$id";
  }
  if ($object->isa('SL::DB::Customer')) {
    my $id     = $object->id;
    return "controller.pl?action=CustomerVendor/$action&id=$id&db=customer";
  }
}

sub setup_list_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#filter_form', { action => 'DeliveryPlan/list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
