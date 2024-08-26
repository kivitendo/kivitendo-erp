package SL::Controller::StockCountingReconciliation;

use strict;
use parent qw(SL::Controller::Base);

use English qw(-no_match_vars);
use List::Util qw(any sum sum0);
use POSIX qw(strftime);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::DB::Employee;
use SL::DB::Inventory;
use SL::DB::StockCounting;
use SL::DB::StockCountingItem;
use SL::Helper::Flash qw(flash_later);
use SL::Helper::Number qw(_format_total);
use SL::Locale::String qw(t8);
use SL::ReportGenerator;
use SL::WH;


            use Data::Dumper;

use Rose::Object::MakeMethods::Generic(
  #scalar => [ qw() ],
  'scalar --get_set_init' => [ qw(countings models) ],
);

# check permissions
__PACKAGE__->run_before(sub { $::auth->assert('warehouse_management'); });

# load js
__PACKAGE__->run_before(sub { $::request->layout->add_javascripts('kivi.Validator.js'); });

my %sort_columns = (
  counting   => t8('Stock Counting'),
  counted_at => t8('Counted At'),
  qty        => t8('Qty'),
  part       => t8('Article'),
  bin        => t8('Bin'),
  employee   => t8('Employee'),
);


sub action_list {
  my ($self, %params) = @_;

  # we need a counting selected
  if (!$::form->{filter}->{counting_id}) {
    $::form->{filter}->{counting_id} = 0;
  }

  $self->make_filter_summary;
  $self->prepare_report;

  my $objects = $self->models->get;

  # group always
  $objects = $self->group_items_by_part_and_bin($objects);
  $self->get_stocked($objects);
  $self->get_inbetweens($objects);

  $self->setup_list_action_bar;
  $self->report_generator_list_objects(report => $self->{report}, objects => $objects);
}

sub action_reconcile {
  my ($self) = @_;

  my $counting = SL::DB::StockCounting->new(id => $::form->{counting_id})->load;
  # todo: sanity checks
  # return if $counting->is_reconciliated;
  # return if scalar(@{$counting->items}) == 0;

#  my $counting_items = $counting->items;
  my $grouped_counting_items = $self->group_items_by_part_and_bin(\@{$counting->items});
  $self->get_stocked($grouped_counting_items);
  $self->get_inbetweens($grouped_counting_items);

  my $comment = t8('correction from stock counting (counting "#1")', $counting->name);

  my $transfer_error;
  $::form->throw_on_error(sub {
    eval {
      SL::DB->client->with_transaction(sub {
        foreach my $group_item (@$grouped_counting_items) {
          my $counted_qty   = $group_item->qty;
          my $stocked_qty   = $group_item->{stocked};
          my $inbetween_qty = $group_item->{inbetweens};

          my $transfer_qty  = $counted_qty - $stocked_qty + $inbetween_qty;

          my $src_or_dst = $transfer_qty < 0? 'src' : 'dst';
          $transfer_qty  = abs($transfer_qty);

          # Do stock.
          # todo: run in transaction and record the inventory id in the counting items
          my %transfer_params = (
            parts_id              => $group_item->part_id,
            $src_or_dst.'_bin_id' => $group_item->bin_id,
            qty                   => $transfer_qty,
            transfer_type         => 'correction',
            comment               => $comment,
          );

          my @trans_ids = WH->transfer(\%transfer_params);

          if (scalar(@trans_ids) != 1) {
            die "Program logic error: no error, but no transfer" if scalar(@trans_ids) == 0;
            die "Program logic error: too many transfers"        if scalar(@trans_ids) >  1;
          }

          # Get inventory entries via trans_ids-
          my $inventories = SL::DB::Manager::Inventory->get_all(where => [trans_id => $trans_ids[0]]);
          if (scalar(@$inventories) != 1) {
            die "Program logic error: no error, but no inventory entry" if scalar(@$inventories) == 0;
            die "Program logic error: too many inventory entries"       if scalar(@$inventories) >  1;
          }


          SL::DB::Manager::StockCountingItem->update_all(set   => {correction_inventory_id => $inventories->[0]->id},
                                                         where => [id => $group_item->{ids}]);
        }

        1;
      }) or do { die SL::DB->client->error; }; # end of with_transaction

      1;
    } or do { $transfer_error = ref($EVAL_ERROR) eq 'SL::X::FormError' ? $EVAL_ERROR->error : $EVAL_ERROR; }; # end of eval

  });                           # end of throw_on_error

  if ($transfer_error) {
    flash_later('error', $transfer_error);
  } else {
    flash_later('info', t8('successfully reconciled'));
  }

  return $self->redirect_to($::form->{callback}) if $::form->{callback};
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

sub init_countings {
  my $countings = SL::DB::Manager::StockCounting->get_all_sorted;
  $countings    = [ grep { !$_->is_reconciliated } @$countings ];

  return $countings;
}


sub prepare_report {
  my ($self) = @_;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns = qw(counting part bin qty stocked inbetweens);

  my %column_defs = (
    counting   => { text => t8('Stock Counting'), sub => sub { $_[0]->counting->name }, },
    counted_at => { text => t8('Counted At'),     sub => sub { $_[0]->counted_at_as_timestamp }, },
    qty        => { text => t8('Qty'),            sub => sub { $_[0]->qty_as_number }, align => 'right' },
    part       => { text => t8('Article'),        sub => sub { $_[0]->part && $_[0]->part->displayable_name } },
    bin        => { text => t8('Bin'),            sub => sub { $_[0]->bin->full_description } },
    employee   => { text => t8('Employee'),       sub => sub { $_[0]->employee ? $_[0]->employee->safe_name : '---'} },
    stocked    => { text => t8('Stocked Qty'),    sub => sub { _format_total($_[0]->{stocked}) }, align => 'right'},
    inbetweens => { text => t8('Inbetweens Qty'), sub => sub { _format_total($_[0]->{inbetweens}) }, align => 'right'},
  );

  # remove columns from defs which are not in @columns
  foreach my $column (keys %column_defs) {
    delete $column_defs{$column} if !grep { $column eq $_ } @columns;
  }

  my $title        = t8('Stock Countings');
  $report->{title} = $title;    # for browser titlebar (title-tag)

  $report->set_options(
    controller_class      => 'StockCountingReconciliation',
    std_column_visibility => 1,
    output_format         => 'HTML',
    title                 => $title, # for heading
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;

  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->add_additional_url_params(filter => $::form->{filter});
  $self->models->finalize;
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => [keys %sort_columns]);

  $report->set_options(
    raw_top_info_text    => $self->render('stock_counting_reconciliation/report_top',    { output => 0 }),
    raw_bottom_info_text => $self->render('stock_counting_reconciliation/report_bottom', { output => 0 }, models => $self->models, counting_id => $::form->{filter}->{counting_id}),
    attachment_basename  => t8('stock_countings') . strftime('_%Y%m%d', localtime time),
  );
}

sub make_filter_summary {
  my ($self) = @_;

  my @filter_strings;

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

sub group_items_by_part_and_bin {
  my ($self, $objects) = @_;

  return [] if scalar @{$objects || []} == 0;

  if (any { $_->counting_id != $objects->[0]->counting_id } @$objects) {
    die 'can only group stock counting items if they belong too the same counting';
  }

  my $grouped_objects_by;
  my @grouped_objects;
  foreach my $object (@$objects) {
    my $group_object;
    if (!$grouped_objects_by->{$object->part_id}->{$object->bin_id}) {
      $group_object = SL::DB::StockCountingItem->new(
        counting => $object->counting, part => $object->part, bin => $object->bin, qty => 0);
      push @grouped_objects, $group_object;
      $grouped_objects_by->{$object->part_id}->{$object->bin_id} = $group_object;

    } else {
      $group_object = $grouped_objects_by->{$object->part_id}->{$object->bin_id}
    }

    push @{$group_object->{ids}}, $object->id;
    $group_object->qty($group_object->qty + $object->qty);
  }

  return \@grouped_objects;
}

sub get_stocked {
  my ($self, $objects) = @_;

  $_->{stocked} = $_->part->get_stock(bin_id => $_->bin_id) for @$objects;
}

sub get_inbetweens {
  my ($self, $objects) = @_;

  # Get changes in stock while a counting was active.
  # (i.e. from start of counting till now).
  # Use itime, because shippingdate has no time component.
  # Ignore stock counting corrections.
  # Todo: warn if itime::date != shippingdate?

  my $correction_inventory_ids = SL::DB::Manager::StockCountingItem->get_all(where    => ['!correction_inventory_id' => undef],
                                                                             select   => ['correction_inventory_id'],
                                                                             distcint => 1);
  foreach my $object (@$objects) {
    my $start      = $object->counting->start_time_of_counting;
    my $inbetweens = SL::DB::Manager::Inventory->get_all(where  => [itime    => { ge => $start },
                                                                    parts_id => $object->part_id,
                                                                    bin_id   => $object->bin_id,
                                                                    '!id'    => [map { $_->correction_inventory_id } @$correction_inventory_ids]],
                                                         select => ['qty']);
    $object->{inbetweens} = sum map { $_->qty } @$inbetweens;
  }
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#filter_form', { action => 'StockCountingReconciliation/list' } ],
        checks    => [ ['kivi.validate_form', '#filter_form'] ],
        accesskey => 'enter',
      ],
      action => [
        t8('Reconcile'),
        submit  => [ '#form', { action => 'StockCountingReconciliation/reconcile', callback => $self->models->get_callback } ],
        checks  => [ ['kivi.validate_form', '#filter_form'] ],
        confirm => t8('Do you really want the selected entries to be reconciled?'),
      ],
    );
  }
}


1;
