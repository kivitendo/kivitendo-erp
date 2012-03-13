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

  $self->{orderitems} = SL::DB::Manager::OrderItem->get_all(%$db_args);

  $self->list_objects;
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

#  $args{query} = [ @{ $args{query} || [] } ];

  return \%args;
}

sub set_sort_params {
  my ($self, %params) = @_;
  my $sort_str;
  ($self->{sort_by}, $self->{sort_dir}, $sort_str) =
    SL::DB::Manager::OrderItem->make_sort_string(%params);
  return $sort_str;
}

sub prepare_report {
  my ($self, %params) = @_;

  my $objects  = $params{objects} || [];
  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns  = qw(transdate ordnumber customer ship qty sellprice discount amount);
  my @visible  = qw(transdate ordnumber customer ship qty sellprice discount amount);
  my @sortable = qw(transdate ordnumber customer          sellprice discount       );

  my %column_defs = (
    transdate               => { text => $::locale->text('Date'),
                                  sub => sub { $_[0]->order->transdate_as_date }},
    ordnumber               => { text => $::locale->text('Number'),
                                  sub => sub { $_[0]->order->ordnumber },
                             obj_link => sub { $self->link_to($_[0]->order) }},
    customer                => { text => $::locale->text('Customer'),
                                  sub => sub { $_[0]->order->customer->name },
                             obj_link => sub { $self->link_to($_[0]->order->customer) }},
    customer                => { text => $::locale->text('Customer'),
                                  sub => sub { $_[0]->order->customer->name },
                             obj_link => sub { $self->link_to($_[0]->order->customer) }},
    ship                    => { text => $::locale->text('Delivered'),
                                  sub => sub { $::form->format_amount(\%::myconfig, $_[0]->shipped_qty) . ' ' . $_[0]->unit }},
    qty                     => { text => $::locale->text('Qty'),
                                  sub => sub { $_[0]->qty_as_number . ' ' . $_[0]->unit }},
    sellprice               => { text => $::locale->text('Sell Price'),
                                  sub => sub { $_[0]->sellprice_as_number }},
    discount                => { text => $::locale->text('Discount'),
                                  sub => sub { $_[0]->discount_as_percent . "%" }},
    amount                  => { text => $::locale->text('Amount'),
                                  sub => sub { $::form->format_amount(\%::myconfig, $_[0]->qty * $_[0]->sellprice * (1 - $_[0]->discount), 2) }},
  );

  for my $col (@sortable) {
    $column_defs{$col}{link} = $self->self_url(
      sort_by  => $col,
      sort_dir => ($self->{sort_by} eq $col ? 1 - $self->{sort_dir} : $self->{sort_dir}),
      page     => $self->{pages}{cur},
    );
  }

  map { $column_defs{$_}->{visible} = 1 } @visible;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_options(allow_pdf_export => 0, allow_csv_export => 0);
  $report->set_sort_indicator(%params);
  $report->set_export_options(@{ $params{report_generator_export_options} || [] });
  $report->set_options(
    %{ $params{report_generator_options} || {} },
    output_format        => 'HTML',
    top_info_text        => $::locale->text('Sales Price Information'),
    title                => $::locale->text('Sales Price information'),
  );
  $report->set_options_from_form;

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
  if ($object->isa('SL::DB::Customer')) {
    my $id     = $object->id;
    return "ct.pl?action=$action&id=$id&db=customer";
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

sub self_url {
  my ($self, %params) = @_;
  %params = (
    action   => $self->{action},
    sort_by  => $self->{sort},
    sort_dir => $self->{sort_dir},
    page     => $self->{pages}{cur},
    filter   => $::form->{filter},
    %params,
  );

  return $self->url_for(%params);
}

1;
