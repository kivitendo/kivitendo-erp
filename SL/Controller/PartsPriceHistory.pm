package SL::Controller::PartsPriceHistory;

use strict;
use parent qw(SL::Controller::Base);

use Clone qw(clone);
use SL::DB::PartsPriceHistory;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;

sub action_list {
  my ($self) = @_;
  $self->{action} = 'list';

  my %list_params = (
    sort_by  => $::form->{sort_by} || 'valid_from',
    sort_dir => $::form->{sort_dir},
    filter   => $::form->{filter},
    page     => $::form->{page},
  );

  my $db_args    = $self->setup_for_list(%list_params);
  $self->{pages} = SL::DB::Manager::PartsPriceHistory->paginate(%list_params, args => $db_args, per_page => 5);

  my $bottom     = $::form->parse_html_template('parts_price_history/report_bottom', { SELF => $self });

  $self->prepare_report(
    db_args                  => $db_args,
    report_generator_options => {
      raw_bottom_info_text => $bottom,
      controller_class     => 'PartsPriceHistory',
    },
  );

  my $history = SL::DB::Manager::PartsPriceHistory->get_all(%{ $db_args });

  $self->report_generator_list_objects(
    report  => $self->{report},
    objects => $history,
    layout  => 0,
    header  => 0,
  );
}

# private functions

sub setup_for_list {
  my ($self, %params) = @_;

  $self->{filter} = clone($params{filter});

  my %args = (
    parse_filter($self->{filter}),
    sort_by => $self->set_sort_params(%params),
    page    => $params{page},
  );

  return \%args;
}

sub set_sort_params {
  my ($self, %params) = @_;

  my $sort_str;
  ($self->{sort_by}, $self->{sort_dir}, $sort_str) = SL::DB::Manager::PartsPriceHistory->make_sort_string(%params);
  return $sort_str;
}

sub column_defs {
  my ($self) = @_;

  return {
    valid_from => { text => $::locale->text('Date'),       sub => sub { $_[0]->valid_from_as_timestamp }},
    lastcost   => { text => $::locale->text('Lastcost'),   sub => sub { $_[0]->lastcost_as_number }},
    listprice  => { text => $::locale->text('List Price'), sub => sub { $_[0]->listprice_as_number }},
    sellprice  => { text => $::locale->text('Sell Price'), sub => sub { $_[0]->sellprice_as_number }},
  };
}

sub prepare_report {
  my ($self, %params) = @_;

  my $objects     = $params{objects} || [];
  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my $title       = $::locale->text('Price history for master data');

  my @columns     = qw(valid_from lastcost listprice sellprice);

  my $column_defs = $self->column_defs;

  for my $col (@columns) {
    $column_defs->{$col}{link} = $self->self_url(
      sort_by  => $col,
      sort_dir => ($self->{sort_by} eq $col ? 1 - $self->{sort_dir} : $self->{sort_dir}),
      page     => $self->{pages}{cur},
    );
  }

  $column_defs->{$_}{visible} = 1 for @columns;

  $report->set_columns(%$column_defs);
  $report->set_column_order(@columns);
  $report->set_options(allow_pdf_export => 0, allow_csv_export => 0);
  $report->set_sort_indicator($self->{sort_by}, $self->{sort_dir});
  $report->set_export_options(@{ $params{report_generator_export_options} || [] });
  $report->set_options(
    %{ $params{report_generator_options} || {} },
    output_format => 'HTML',
    top_info_text => $self->displayable_filter($::form->{filter}),
    title         => $title,
  );
  $report->set_options_from_form;
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
