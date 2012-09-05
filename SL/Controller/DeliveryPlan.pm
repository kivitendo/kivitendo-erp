package SL::Controller::DeliveryPlan;

use strict;
use parent qw(SL::Controller::Base);

use Clone qw(clone);
use SL::DB::OrderItem;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Sorted;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(db_args flat_filter) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('sales_order_edit'); });

__PACKAGE__->get_models_url_params('flat_filter');
__PACKAGE__->make_paginated(
  MODEL         => 'OrderItem',
  PAGINATE_ARGS => 'db_args',
  ONLY          => [ qw(list) ],
);

__PACKAGE__->make_sorted(
  MODEL       => 'OrderItem',
  ONLY        => [ qw(list) ],

  DEFAULT_BY  => 'reqdate',
  DEFAULT_DIR => 1,

  reqdate     => 'Reqdate',
  description => 'Description',
  partnumber  => 'Part Number',
  qty         => 'Qty',
  missing     => 'Missing qty',
  shipped_qty => 'shipped',
  ordnumber   => 'Order',
  customer    => 'Customer',
);

sub action_list {
  my ($self) = @_;
  my %list_params = (
    filter   => $::form->{filter},
  );

  $self->db_args($self->setup_for_list(%list_params));
  $self->flat_filter({ map { $_->{key} => $_->{value} } $::form->flatten_variables('filter') });
  $self->make_filter_summary;

  my $top    = $::form->parse_html_template('delivery_plan/report_top', { FORM => $::form, SELF => $self });
  my $bottom = $::form->parse_html_template('delivery_plan/report_bottom', { SELF => $self });

  $self->prepare_report(
    report_generator_options => {
      raw_top_info_text    => $top,
      raw_bottom_info_text => $bottom,
      controller_class     => 'DeliveryPlan',
    },
    report_generator_export_options => [ qw(list filter) ],
  );

  $self->{orderitems} = $self->get_models(%{ $self->db_args });

  $self->list_objects;
}

# private functions

sub setup_for_list {
  my ($self, %params) = @_;
  $self->{filter} = {};
  my %args = (
    parse_filter(
      $self->_pre_parse_filter($::form->{filter}, $self->{filter}),
      with_objects => [ 'order', 'order.customer', 'part' ],
      launder_to => $self->{filter},
    ),
  );

  $args{query} = [ @{ $args{query} || [] },
    (
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
      " ],
    )
  ];

  return \%args;
}

sub prepare_report {
  my ($self, %params) = @_;

  my $objects  = $params{objects} || [];
  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns  = qw(reqdate customer ordnumber partnumber description qty shipped_qty);
  my @visible  = qw(reqdate partnumber description qty shipped_qty ordnumber customer);
  my @sortable = qw(reqdate partnumber description                 ordnumber customer);

  my %column_defs = (
    reqdate                 => {      sub => sub { $_[0]->reqdate_as_date || $_[0]->order->reqdate_as_date }},
    description             => {      sub => sub { $_[0]->description },
                                 obj_link => sub { $self->link_to($_[0]->part) }},
    partnumber              => {      sub => sub { $_[0]->part->partnumber },
                                 obj_link => sub { $self->link_to($_[0]->part) }},
    qty                     => {      sub => sub { $_[0]->qty_as_number . ' ' . $_[0]->unit }},
    missing                 => {      sub => sub { $::form->format_amount(\%::myconfig, $_[0]->qty - $_[0]->shipped_qty, 2) . ' ' . $_[0]->unit }},
    shipped_qty             => {      sub => sub { $::form->format_amount(\%::myconfig, $_[0]->shipped_qty, 2) . ' ' . $_[0]->unit }},
    ordnumber               => {      sub => sub { $_[0]->order->ordnumber },
                                 obj_link => sub { $self->link_to($_[0]->order) }},
    customer                => {      sub => sub { $_[0]->order->customer->name },
                                 obj_link => sub { $self->link_to($_[0]->order->customer) }},
  );

  map { $column_defs{$_}->{text} = $::locale->text( $self->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  map { $column_defs{$_}->{visible} = 1 } @visible;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_options(allow_pdf_export => 1, allow_csv_export => 1);
  $report->set_export_options(@{ $params{report_generator_export_options} || [] });
  $report->set_options(
    %{ $params{report_generator_options} || {} },
    output_format        => 'HTML',
    top_info_text        => $::locale->text('Delivery Plan for currently outstanding sales orders'),
    title                => $::locale->text('Delivery Plan'),
  );
  $report->set_options_from_form;
  $self->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);

  $self->disable_pagination if $report->{options}{output_format} =~ /^(pdf|csv)$/i;

  $self->{report_data} = {
    column_defs => \%column_defs,
    columns     => \@columns,
    visible     => \@visible,
    sortable    => \@sortable,
  };
}

sub list_objects {
  my ($self) = @_;
  my $column_defs = $self->{report_data}{column_defs};
  for my $obj (@{ $self->{orderitems} || [] }) {
    $self->{report}->add_data({
      map {
        $_ => {
          data => $column_defs->{$_}{sub} ? $column_defs->{$_}{sub}->($obj)
                : $obj->can($_)           ? $obj->$_
                :                           $obj->{$_},
          link => $column_defs->{$_}{obj_link} ? $column_defs->{$_}{obj_link}->($obj) : '',
        },
      } @{ $self->{report_data}{columns} || {} }
    });
  }

  return $self->{report}->generate_with_headers;
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my @filters = (
    [ $filter->{order}{"ordnumber:substr::ilike"}, $::locale->text('Number') ],
    [ $filter->{part}{"partnumber:substr::ilike"}, $::locale->text('Part Number') ],
    [ $filter->{"description:substr::ilike"}, $::locale->text('Part Description') ],
    [ $filter->{"reqdate:date::ge"}, $::locale->text('Delivery Date') . " " . $::locale->text('From Date') ],
    [ $filter->{"reqdate:date::le"}, $::locale->text('Delivery Date') . " " . $::locale->text('To Date') ],
    [ $filter->{"qty:number"}, $::locale->text('Quantity') ],
    [ $filter->{order}{customer}{"name:substr::ilike"}, $::locale->text('Customer') ],
    [ $filter->{order}{customer}{"customernumber:substr::ilike"}, $::locale->text('Customer Number') ],
  );

  my @flags = (
    [ $filter->{part}{type}{part}, $::locale->text('Parts') ],
    [ $filter->{part}{type}{service}, $::locale->text('Services') ],
    [ $filter->{part}{type}{assembly}, $::locale->text('Assemblies') ],
  );

  for (@flags) {
    push @filter_strings, "$_->[1]" if $_->[0];
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
    return "ct.pl?action=$action&id=$id&db=customer";
  }
}

# unfortunately ParseFilter can't handle compount filters.
# so we clone the original filter (still need that for serializing)
# rip out the options we know an replace them with the compound options.
# ParseFilter will take care of the prefixing then.
sub _pre_parse_filter {
  my ($self, $orig_filter, $launder_to) = @_;

  return undef unless $orig_filter;

  my $filter = clone($orig_filter);
  if ($filter->{part} && $filter->{part}{type}) {
    $launder_to->{part}{type} = delete $filter->{part}{type};
    my @part_filters = grep $_, map {
      $launder_to->{part}{type}{$_} ? SL::DB::Manager::Part->type_filter($_) : ()
    } qw(part service assembly);

    push @{ $filter->{and} }, or => [ @part_filters ] if @part_filters;
  }

  for my $op (qw(le ge)) {
    if ($filter->{"reqdate:date::$op"}) {
      $launder_to->{"reqdate_date__$op"} = delete $filter->{"reqdate:date::$op"};
      my $parsed_date = DateTime->from_lxoffice($launder_to->{"reqdate_date__$op"});
      push @{ $filter->{and} }, or => [
        'reqdate' => { $op => $parsed_date },
        and => [
          'reqdate' => undef,
          'order.reqdate' => { $op => $parsed_date },
        ]
      ] if $parsed_date;
    }
  }

  if (my $style = delete $filter->{searchstyle}) {
    $self->{searchstyle}       = $style;
    $launder_to->{searchstyle} = $style;
  }

  return $filter;
}

1;
