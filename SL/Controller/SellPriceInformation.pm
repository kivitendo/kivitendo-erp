package SL::Controller::SellPriceInformation;

use strict;
use parent qw(SL::Controller::Base);

use Clone qw(clone);
use SL::DB::OrderItem;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;

sub action_list {
  my ($self) = @_;
  $self->{action} = 'list';

  my %list_params = (
    sort_by  => $::form->{sort_by} || 'reqdate',
    sort_dir => $::form->{sort_dir},
    filter   => $::form->{filter},
    page     => $::form->{page},
  );

  my $db_args = $self->setup_for_list(%list_params);
  $self->{pages} = SL::DB::Manager::OrderItem->paginate(%list_params, args => $db_args, per_page => 5);

  my $bottom = $::form->parse_html_template('price_information/report_bottom', { SELF => $self });

  $self->prepare_report(
    report_generator_options => {
      raw_bottom_info_text => $bottom,
      controller_class     => 'SellPriceInformation',
    },
    db_args => $db_args,
  );

  my $orderitems = SL::DB::Manager::OrderItem->get_all(%$db_args);

  $self->report_generator_list_objects(report => $self->{report}, objects => $orderitems, layout => 0, header => 0);
}

# private functions

sub setup_for_list {
  my ($self, %params) = @_;
  $self->{filter} = _pre_parse_filter($params{filter});

  my %args = (
    parse_filter($self->{filter},
      with_objects => [ 'order', 'order.customer', 'part' ],
    ),
    sort_by => $self->set_sort_params(%params),
    page    => $params{page},
  );

  return \%args;
}

sub set_sort_params {
  my ($self, %params) = @_;
  my $sort_str;
  ($self->{sort_by}, $self->{sort_dir}, $sort_str) =
    SL::DB::Manager::OrderItem->make_sort_string(%params);
  return $sort_str;
}

sub column_defs {
  my ($self) = @_;
  return {
    transdate    => { text => $::locale->text('Date'),
                       sub => sub { $_[0]->order->transdate_as_date }},
    ordnumber    => { text => $::locale->text('Number'),
                       sub => sub { $_[0]->order->number },
                  obj_link => sub { $self->link_to($_[0]->order) }},
    customer     => { text => $::locale->text('Customer'),
                       sub => sub { $_[0]->order->customer->name },
                  obj_link => sub { $self->link_to($_[0]->order->customer) }},
    customer     => { text => $::locale->text('Customer'),
                       sub => sub { $_[0]->order->customer->name },
                  obj_link => sub { $self->link_to($_[0]->order->customer) }},
    ship         => { text => $::locale->text('Delivered'),
                       sub => sub { $::form->format_amount(\%::myconfig, $_[0]->shipped_qty) . ' ' . $_[0]->unit }},
    qty          => { text => $::locale->text('Qty'),
                       sub => sub { $_[0]->qty_as_number . ' ' . $_[0]->unit }},
    price_factor => { text => $::locale->text('Price Factor'),
                      sub => sub { $_[0]->price_factor_as_number }},
    sellprice    => { text => $::locale->text('Sell Price'),
                       sub => sub { $_[0]->sellprice_as_number }},
    discount     => { text => $::locale->text('Discount'),
                       sub => sub { $_[0]->discount_as_percent . "%" }},
    amount       => { text => $::locale->text('Amount'),
                       sub => sub { $::form->format_amount(\%::myconfig, $_[0]->qty * $_[0]->sellprice * (1 - $_[0]->discount) / ($_[0]->price_factor ? $_[0]->price_factor : 1.0), 2) }},
  };
}

sub prepare_report {
  my ($self, %params) = @_;

  my $objects  = $params{objects} || [];
  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my $title    = $::locale->text('Sales Price information');
  $title      .= ': ' . $::locale->text($::form->{filter}->{order}{type}) if $::form->{filter}->{order}{type};

  my @columns  = qw(transdate ordnumber customer ship qty price_factor sellprice discount amount);
  my @visible  = qw(transdate ordnumber customer ship qty price_factor sellprice discount amount);
  my @sortable = qw(transdate ordnumber customer          sellprice              discount       );

  my $column_defs = $self->column_defs;

  for my $col (@sortable) {
    $column_defs->{$col}{link} = $self->self_url(
      sort_by  => $col,
      sort_dir => ($self->{sort_by} eq $col ? 1 - $self->{sort_dir} : $self->{sort_dir}),
      page     => $self->{pages}{cur},
    );
  }

  map { $column_defs->{$_}{visible} = 1 } @visible;

  $report->set_columns(%$column_defs);
  $report->set_column_order(@columns);
  $report->set_options(allow_pdf_export => 0, allow_csv_export => 0);
  $report->set_sort_indicator($self->{sort_by}, $self->{sort_dir});
  $report->set_export_options(@{ $params{report_generator_export_options} || [] });
  $report->set_options(
    %{ $params{report_generator_options} || {} },
    output_format        => 'HTML',
    top_info_text        => $self->displayable_filter($::form->{filter}),
    title                => $title,
  );
  $report->set_options_from_form;
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
  if ($object->isa('SL::DB::Customer')) {
    my $id     = $object->id;
    return "controller.pl?action=CustomerVendor/$action&id=$id&db=customer";
  }
}

sub _pre_parse_filter {
  my $filter = clone(shift);

  if (  exists $filter->{order}
     && exists $filter->{order}{type}) {
     push @{ $filter->{and} }, SL::DB::Manager::Order->type_filter(delete $filter->{order}{type}, "order."),
  }

  return $filter;
}

sub displayable_filter {
  my ($self, $filter) = @_;

  my $column_defs = $self->column_defs;
  my @texts;

  push @texts, [ $::locale->text('Sort By'), $column_defs->{$self->{sort_by}}{text}  ] if $column_defs->{$self->{sort_by}}{text};
  push @texts, [ $::locale->text('Page'),    $::locale->text($self->{pages}{cur})    ] if $self->{pages}{cur} > 1;

  return join '; ', map { "$_->[0]: $_->[1]" } @texts;
}

sub self_url {
  my ($self, %params) = @_;
  %params = (
    action   => $self->{action},
    sort_by  => $self->{sort_by},
    sort_dir => $self->{sort_dir},
    page     => $self->{pages}{cur},
    filter   => $::form->{filter},
    %params,
  );

  return $self->url_for(%params);
}

1;
