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
use SL::Helper::Inventory qw(:ALL);
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
  counting     => t8('Stock Counting'),
  counted_at   => t8('Counted At'),
  qty          => t8('Qty'),
  part         => t8('Article'),
  chargenumber => t8('Chargenumber'),
  bin          => t8('Bin'),
  employee     => t8('Employee'),
);


################ actions #################

sub action_select_counting {
  my ($self) = @_;

  $::form->error(t8('There are no stock countings yet. You can create one via the menu "System -> Stock Countings"')) if !@{$self->countings};

  $self->countings([ grep { !$_->reconciliated } @{$self->countings} ]);

  $::form->error(t8('There are no stock countings that are not reconciled')) if !@{$self->countings};

  if (!$::request->is_mobile) {
    $self->setup_select_counting_action_bar;
  }

  $self->render('stock_counting/select_counting', { }, title => t8('Stock Counting'));
}

sub action_start_counting {
  my ($self) = @_;

  if (!$::request->is_mobile) {
    $self->setup_count_action_bar;
  }

  $self->render('stock_counting/count', { }, title => t8('Stock Counting'));
}

sub action_count {
  my ($self) = @_;

  my @errors;
  my $parts;
  my $qty;

  $self->js->clear_flash('info');
  $self->js->val('[name="ean"]', '');

  if ($::request->is_mobile) {
    $qty = 1;
  } else {
    $qty = $::form->{qty} == 0 ? 0 : $::form->{qty} || 1;
    $self->setup_count_action_bar;
  }

  if (!$::form->{ean} && !$::form->{part_id} ) {
    push @errors, t8('EAN or Partnumber is missing') ;
  }

  return $self->render_count_error(\@errors) if @errors;

  if ($::form->{ean}) {
   $parts = SL::DB::Manager::Part->get_all(where => [ean => $::form->{ean}, obsolete => 0]);
  }
  if ($::form->{part_id}) {
   $parts = SL::DB::Manager::Part->get_all(where => [id => $::form->{part_id}, obsolete => 0]);
  }
  push @errors, t8 ('Part not found')    if scalar(@{$parts}) == 0;
  push @errors, t8 ('Part is ambiguous') if scalar(@{$parts}) >  1;

  return $self->render_count_error(\@errors) if @errors;

  $self->stock_counting_item->part($parts->[0]);

  my @validation_errors = $self->stock_counting_item->validate;
  push @errors, @validation_errors if @validation_errors;

  return $self->render_count_error(\@errors) if @errors;

  $self->stock_counting_item->qty($qty);
  $self->stock_counting_item->chargenumber($::form->{chargenumber});
  $self->stock_counting_item->save;

  $self->js->flash('info', t8('Part successfully counted'));

  $::request->is_mobile ? $self->js->render
                        : $self->action_show_parts_in_bin();
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
      if (!$grouped_objects_by->{$object->counting_id}{$object->part_id}{$object->bin_id}{$object->chargenumber}) {
        $group_object = SL::DB::StockCountingItem->new(
          counting => $object->counting, part => $object->part, bin => $object->bin, qty => 0, chargenumber => $object->chargenumber, encountered => 0);
        $group_object->{reconciliated} = 1;
        push @grouped_objects, $group_object;
        $grouped_objects_by->{$object->counting_id}{$object->part_id}{$object->bin_id}{$object->chargenumber} = $group_object;

      } else {
        $group_object = $grouped_objects_by->{$object->counting_id}{$object->part_id}{$object->bin_id}{$object->chargenumber};
      }

      $group_object->id($group_object->id ? ($group_object->id . ',' . $object->id) : $object->id);
      $group_object->qty($group_object->qty + $object->qty);
      $group_object->encountered($group_object->encountered || $object->encountered);
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

sub action_show_parts_in_bin {
  my ($self) = @_;

  my $html    = $self->render('stock_counting/last_counting_operations', { output => 0 });

  $self->js->html('#list_data', $html)
           ->reinit_widgets
           ->render;
}

sub last_counting_operations {
  my ($self) = @_;

  $::form->{filter}{counting_id} = $::form->{stock_counting_item}{counting_id};
  $::form->{sort_by} = 'counted_at';
  $::form->{sort_dir} = 0;

  return $self->models->get;
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
    paginated      => { per_page => 20 },
    with_objects   => [ 'counting', 'employee', 'part', 'bin' ],
  );
}

sub prepare_report {
  my ($self) = @_;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns = $::form->{group_counting_items} ? qw(counting encountered part chargenumber bin qty stocked reconciliated)
              : qw(counting encountered counted_at part chargenumber bin qty stocked employee reconciliated);

  my %column_defs = (
    counting      => { text => t8('Stock Counting'), sub => sub { $_[0]->counting->name }, },
    counted_at    => { text => t8('Counted At'),     sub => sub { $_[0]->counted_at_as_timestamp }, },
    encountered   => { text => t8('Encountered'),    sub => sub { $_[0]->encountered ? t8('Yes') : t8('No') }, },
    qty           => { text => t8('Qty'),            sub => sub { $_[0]->qty_as_number }, align => 'right' },
    part          => { text => t8('Article'),        sub => sub { $_[0]->part && $_[0]->part->displayable_name } },
    chargenumber  => { text => t8('Chargenumber'),   sub => sub { $_[0]->chargenumber }, },
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
    controller_class      => 'StockCounting',
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

  $_->{stocked} = get_stock(part => $_->part, bin_id => $_->bin_id, chargenumber => $_->chargenumber) for @$objects;
}

sub render_count_error {
  my ($self, $errors) = @_;

  $self->js->flash('error', $_) for @{$errors};
  $self->js->render;
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
        call      => [ 'kivi.StockCounting.submit_count' ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
