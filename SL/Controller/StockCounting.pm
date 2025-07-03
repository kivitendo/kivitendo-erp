package SL::Controller::StockCounting;

use strict;
use parent qw(SL::Controller::Base);

use POSIX qw(strftime);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;

use SL::DB::Employee;
use SL::DB::StockCounting;
use SL::DB::StockCountingItem;

use SL::Helper::Flash qw(flash);
use SL::Helper::Number qw(_format_total);
use SL::Locale::String qw(t8);
use SL::ReportGenerator;

use Rose::Object::MakeMethods::Generic(
  #scalar => [ qw() ],
  'scalar --get_set_init' => [ qw(is_developer countings stock_counting_item models) ],
);

# check permissions
__PACKAGE__->run_before(sub { $::auth->assert('warehouse_management'); });

# load js
__PACKAGE__->run_before(sub { $::request->layout->add_javascripts('kivi.Validator.js', 'kivi.StockCounting.js'); },
                        except => [ qw(list) ]);


my %sort_columns = (
  counting   => t8('Stock Counting'),
  counted_at => t8('Counted At'),
  qty        => t8('Qty'),
  part       => t8('Article'),
  bin        => t8('Bin'),
  employee   => t8('Employee'),
);


################ actions #################

sub action_select_counting {
  my ($self) = @_;

  $self->countings([ grep { !$_->is_reconciliated } @{$self->countings} ]);

  if (!$::request->is_mobile) {
    $self->setup_select_counting_action_bar;
  }

  $self->render('stock_counting/select_counting');
}

sub action_start_counting {
  my ($self) = @_;

  if (!$::request->is_mobile) {
    $self->setup_count_action_bar;
  }

  $self->render('stock_counting/count');
}

sub action_count {
  my ($self) = @_;

  if (!$::request->is_mobile) {
    $self->setup_count_action_bar;
  }

  my @errors;
  push @errors, t8('EAN is missing')    if !$::form->{ean};

  return $self->render_count_error(\@errors) if @errors;

  my $parts = SL::DB::Manager::Part->get_all(where => [ean => $::form->{ean},
                                                       or  => [obsolete => 0, obsolete => undef]]);
  push @errors, t8 ('Part not found')    if scalar(@$parts) == 0;
  push @errors, t8 ('Part is ambiguous') if scalar(@$parts) >  1;

  return $self->render_count_error(\@errors) if @errors;

  $self->stock_counting_item->part($parts->[0]);

  my @validation_errors = $self->stock_counting_item->validate;
  push @errors, @validation_errors if @validation_errors;

  return $self->render_count_error(\@errors) if @errors;

  $self->stock_counting_item->qty(1);
  $self->stock_counting_item->save;

  if ($::request->is_mobile) {
    $self->render('stock_counting/count', successfully_counted => 1);
  } else {
    flash('info', t8('Part successfully counted'));
    $self->render('stock_counting/count');
  }
}

sub action_list {
  my ($self, %params) = @_;

  $self->make_filter_summary;
  $self->prepare_report;

  my $objects = $self->models->get;

  if ($::form->{group_counting_items}) {
    my $grouped_objects_by;
    my @grouped_objects;
    foreach my $object (@$objects) {
      my $group_object;
      if (!$grouped_objects_by->{$object->counting_id}->{$object->part_id}->{$object->bin_id}) {
        $group_object = SL::DB::StockCountingItem->new(
          counting => $object->counting, part => $object->part, bin => $object->bin, qty => 0);
        $group_object->{reconciliated} = 1;
        push @grouped_objects, $group_object;
        $grouped_objects_by->{$object->counting_id}->{$object->part_id}->{$object->bin_id} = $group_object;

      } else {
        $group_object = $grouped_objects_by->{$object->counting_id}->{$object->part_id}->{$object->bin_id}
      }

      $group_object->id($group_object->id ? ($group_object->id . ',' . $object->id) : $object->id);
      $group_object->qty($group_object->qty + $object->qty);
      $group_object->{reconciliated} &&= !!$object->correction_inventory_id;
    }

    $objects = \@grouped_objects;

  } else {
    $_->{reconciliated} = !!$_->correction_inventory_id for @$objects;
  }

  $self->get_stocked($objects);

  $self->setup_list_action_bar;
  $self->report_generator_list_objects(report => $self->{report}, objects => $objects);
}

sub init_is_developer {
  !!$::auth->assert('developer', 'may_fail')
}

sub init_countings {
  SL::DB::Manager::StockCounting->get_all_sorted;
}

sub init_stock_counting_item {
  SL::DB::StockCountingItem->new(%{$::form->{stock_counting_item}},
                                 employee => SL::DB::Manager::Employee->current);
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller     => $_[0],
    model          => 'StockCountingItem',
    sorted         => \%sort_columns,
    disable_plugin => 'paginated',
    with_objects   => [ 'counting', 'employee', 'part' ],
  );
}

sub prepare_report {
  my ($self) = @_;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns = $::form->{group_counting_items} ? qw(counting part bin qty stocked reconciliated)
              : qw(counting counted_at part bin qty stocked employee reconciliated);

  my %column_defs = (
    counting      => { text => t8('Stock Counting'), sub => sub { $_[0]->counting->name }, },
    counted_at    => { text => t8('Counted At'),     sub => sub { $_[0]->counted_at_as_timestamp }, },
    qty           => { text => t8('Qty'),            sub => sub { $_[0]->qty_as_number }, align => 'right' },
    part          => { text => t8('Article'),        sub => sub { $_[0]->part && $_[0]->part->displayable_name } },
    bin           => { text => t8('Bin'),            sub => sub { $_[0]->bin->full_description } },
    employee      => { text => t8('Employee'),       sub => sub { $_[0]->employee ? $_[0]->employee->safe_name : '---'} },
    stocked       => { text => t8('Stocked Qty'),    sub => sub { _format_total($_[0]->{stocked}) }, align => 'right'},
    reconciliated => { text => t8('Reconciliated'),  sub => sub { $_[0]->{reconciliated} ? t8('Yes') : t8('No') }, align => 'right'},
  );

  # remove columns from defs which are not in @columns
  foreach my $column (keys %column_defs) {
    delete $column_defs{$column} if !grep { $column eq $_ } @columns;
  }

  my $title        = t8('Stock Counting Items');
  $report->{title} = $title;    # for browser titlebar (title-tag)

  $report->set_options(
    controller_class      => 'StockCountingItem',
    std_column_visibility => 1,
    output_format         => 'HTML',
    title                 => $title, # for heading
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter group_counting_items));
  $report->set_options_from_form;

  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->add_additional_url_params(filter => $::form->{filter}, group_counting_items => $::form->{group_counting_items});
  $self->models->finalize;
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => [keys %sort_columns]);

  $report->set_options(
    raw_top_info_text    => $self->render('stock_counting/report_top',    { output => 0 }),
    raw_bottom_info_text => $self->render('stock_counting/report_bottom', { output => 0 }, models => $self->models),
    attachment_basename  => t8('stock_countings') . strftime('_%Y%m%d', localtime time),
  );
}

sub make_filter_summary {
  my ($self) = @_;

  my @filter_strings;

  push @filter_strings, t8('Group Counting Items') if $::form->{group_counting_items};

  my $filter = $::form->{filter} || {};

  my $counting = $filter->{counting_id} ? SL::DB::StockCounting->new(id => $filter->{counting_id})->load->name : '';

  my @filters = (
    [ $counting, t8('Stock Counting') ],
  );

  for (@filters) {
    push @filter_strings, "$_->[1]: $_->[0]" if $_->[0];
  }

  $self->{filter_summary} = join ', ', @filter_strings;
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#filter_form', { action => 'StockCounting/list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub get_stocked {
  my ($self, $objects) = @_;

  $_->{stocked} = $_->part->get_stock(bin_id => $_->bin_id) for @$objects;
}

sub render_count_error {
  my ($self, $errors) = @_;

  if ($::request->is_mobile) {
    $self->render('stock_counting/count', errors => $errors);
  } else {
    flash('error', @{$errors || [] });
    $self->render('stock_counting/count');
  }
}

sub setup_select_counting_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Start Counting'),
        submit    => [ '#count_form', { action => 'StockCounting/start_counting' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_count_action_bar {
  my ($self) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Do count'),
        checks    => [ ['kivi.validate_form', '#count_form'] ],
        submit    => [ '#count_form', { action => 'StockCounting/count' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
