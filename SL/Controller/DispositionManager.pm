package SL::Controller::DispositionManager;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::DB::Part;
use SL::DB::PurchaseBasketItem;
use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::Vendor;
use SL::PriceSource;
use SL::Locale::String qw(t8);
use SL::Helper::Flash qw(flash flash_later);
use SL::DBUtils;

use Data::Dumper;

use Rose::Object::MakeMethods::Generic (
 'scalar --get_set_init' => [ qw(models) ],
);

sub action_list_parts {
  my ($self) = @_;
  $self->prepare_report(t8('Reorder Level List'), $::form->{noshow} ? 1 : 0 );

  my $objects = $::form->{noshow} ? [] : $self->models->get;

  $self->_setup_list_action_bar;
  $self->report_generator_list_objects(
    report => $self->{report}, objects => $objects);
}

sub prepare_report {
  my ($self, $title, $noshow ) = @_;

  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns  = qw(
    partnumber description available onhand rop ordered
    );
  my @visible  = qw(
    partnumber description available onhand rop ordered
    );
  my @sortable = qw(partnumber description);

  my %column_defs = (
    partnumber  => {
      sub      => sub { $_[0]->partnumber },
      text     => t8('Part Number'),
      obj_link => sub { $_[0]->presenter->link_to },
    },
    description => {
      sub      => sub { $_[0]->description },
      text     => t8('Part Description'),
      obj_link => sub { $_[0]->presenter->link_to },
    },
    available   => {
      sub  => sub { $::form->format_amount(\%::myconfig,$_[0]->onhandqty,2); },
      text => t8('Available Stock'),
    },
    onhand      => {
      sub  => sub { $::form->format_amount(\%::myconfig,$_[0]->stockqty,2); },
      text => t8('Total Stock'),
    },
    rop         => {
      sub  => sub { $::form->format_amount(\%::myconfig,$_[0]->rop,2); },
      text => t8('Rop'),
    },
    ordered     => {
      sub => sub { $::form->format_amount(
                     \%::myconfig,$_[0]->get_open_ordered_qty,2); },
      text => t8('Ordered purchase'),
    },
  );

  map { $column_defs{$_}->{visible} = 1 } @visible;

  $report->set_options(
    controller_class     => 'DispositionManager',
    output_format        => 'HTML',
    title                => t8($title),
    allow_pdf_export     => 0,
    allow_csv_export     => 0,
    allow_chart_export   => 0,
    no_data_message      => !$noshow,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  unless ( $noshow ) {
    if ($report->{options}{output_format} =~ /^(pdf|csv)$/i) {
      $self->models->disable_plugin('paginated');
    }
    $self->models->finalize; # for filter laundering
    $self->models->set_report_generator_sort_options(
      report => $report, sortable_columns => \@sortable
    );
  }
  my $parts = $self->_get_parts(0);
  my $top    = $self->render('disposition_manager/list_parts', { output => 0 },
                             noshow => $noshow,
                             PARTS => $parts,
                             title => t8('Short onhand Ordered'),
                           );
  my $bottom = $noshow ? undef : $self->render(
    'disposition_manager/reorder_level_list/report_bottom',
    { output => 0}, models => $self->models );
  $report->set_options(
    raw_top_info_text    => $top,
    raw_bottom_info_text => $bottom,
  );
}

sub action_add_to_purchase_basket{
  my ($self) = @_;

  my $employee = SL::DB::Manager::Employee->current;

  my $parts_to_add = delete($::form->{ids}) || [];
  foreach my $id (@{ $parts_to_add }) {
    my $part = SL::DB::Manager::Part->find_by(id => $id)
      or die "Can't find part with id: $id\n";
    my $needed_qty = $part->order_qty < ($part->rop - $part->onhandqty) ?
                       $part->rop - $part->onhandqty
                     : $part->order_qty;
    my $basket_part = SL::DB::PurchaseBasketItem->new(
      part_id    => $part->id,
      qty        => $needed_qty,
      orderer_id => $employee->id,
    )->save;
 }

 $self->redirect_to(
   controller => 'DispositionManager',
   action     => 'show_basket',
 );

}

sub action_show_basket {
  my ($self) = @_;

  $::request->{layout}->add_javascripts(
    'kivi.DispositionManager.js', 'kivi.Part.js'
  );
  my $basket_items = SL::DB::Manager::PurchaseBasketItem->get_all(
    query => [ cleared => 'F' ],
    with_objects => [ 'part', 'part.makemodels' ]
  );
  $self->_setup_show_basket_action_bar;
  $self->render(
    'disposition_manager/show_purchase_basket',
    BASKET_ITEMS => $basket_items,
    title => t8('Purchase basket'),
  );
}

sub action_show_vendor_items {
  my ($self) = @_;

  my $makemodels_parts;
  if ($::form->{vendor_id}) {
    $makemodels_parts = SL::DB::Manager::Part->get_all(
      query => [
        'purchase_basket_item.id' => undef,
        'makemodels.make' => $::form->{vendor_id},
      ],
      sort_by => 'onhand',
      with_objects => [ 'makemodels', 'purchase_basket_item' ]
    );
  };

  $self->render(
    'disposition_manager/_show_vendor_parts',
    { layout => 0 },
    MAKEMODEL_ITEMS => $makemodels_parts
  );
}

sub action_transfer_to_purchase_order {
  my ($self) = @_;
  my @error_report;

  my $basket_item_ids = $::form->{ids};
  my $vendor_item_ids = $::form->{vendor_part_ids};

  unless (($basket_item_ids && scalar @{ $basket_item_ids})
      || ( $vendor_item_ids && scalar @{ $vendor_item_ids}))
    {
    $self->js->flash('error', t8('There are no items selected'));
    return $self->js->render();
  }

  my $vendor_id =  $::form->{vendor_ids}->[0];

  # check for same vendor
  my %basket_id_vendor_id_map =
    map {$::form->{basket_ids}->[$_] => $::form->{vendor_ids}->[$_]}
    (0..$#{$::form->{vendor_ids}});
  my @different_vendor_ids =
    grep { $basket_id_vendor_id_map{$_} ne $vendor_id }
    @{$basket_item_ids};
  if (scalar @different_vendor_ids) {
    $self->js->flash('error', t8('There are mulitple vendors selected'));
    return $self->js->render();
  }

  $self->redirect_to(
    controller => 'Order',
    action     => 'add_from_purchase_basket',
    type       => 'purchase_order',
    basket_item_ids => $basket_item_ids,
    vendor_item_ids => $vendor_item_ids,
    vendor_id       => $vendor_id,
  );
}

sub action_delete_purchase_basket_items {

  my ($self) = @_;
  my @error_report;

  my $basket_item_ids = $::form->{ids};

  if ($basket_item_ids && scalar @{ $basket_item_ids}) {
    SL::DB::Manager::PurchaseBasketItem->delete_all(
      where => [ id => $basket_item_ids]);
  } else {
    $self->js->flash('error', t8('There are no items selected'));
    return $self->js->render();
  }

  flash_later('info', t8('Selected items deleted'));

  $self->redirect_to(
    controller => 'DispositionManager',
    action     => 'show_basket',
  );
}

sub _get_parts {
  my ($self, $ordered) = @_;

  my $query = <<SQL;
 WITH available AS (
   SELECT inv.parts_id, sum(qty) as sum
   FROM inventory inv
   LEFT JOIN warehouse w ON inv.warehouse_id = w.id
   WHERE NOT w.invalid
   GROUP BY inv.parts_id
 
   UNION ALL
 
   SELECT p.id, 0 as sum
   FROM parts p
   WHERE p.id NOT IN ( SELECT distinct parts_id from inventory)
     AND NOT p.obsolete
     AND p.rop != 0
 )

 SELECT p.id
 FROM parts p
 LEFT JOIN available ava ON ava.parts_id = p.id
 WHERE ( ava.sum < p.rop )
   AND p.id NOT IN ( SELECT part_id FROM purchase_basket_items )
   AND NOT p.obsolete
 ORDER BY p.partnumber
SQL
  my @ids = selectall_array_query($::form, $::form->get_standard_dbh, $query);
  return unless scalar @ids;
  my $parts = SL::DB::Manager::Part->get_all( query => [ id => \@ids ] );
  my $parts_to_order = [ grep { !$_->get_open_ordered_qty } @{$parts} ];
  return $parts_to_order if !$ordered;
  my $parts_ordered = [
    map { $_->id } grep { $_->get_open_ordered_qty } @{$parts}
  ];
  return $parts_ordered if $ordered;
};

sub init_models {
  my ($self) = @_;
  my $parts1 = $self->_get_parts(1) || [];
  my @parts = @{$parts1};
  my $get_models =  SL::Controller::Helper::GetModels->new(
    controller => $self,
    model => 'Part',
    sorted => {
      _default => {
        by  => 'partnumber',
        dir => 1,
      },
      partnumber  => $::locale->text('Part Number'),
      description => $::locale->text('Description'),
     },
    query => [
      (id => \@parts) x !!@parts,
      (id => undef) x !@parts,
    ],
    paginated => {
      form_params => [ qw(page per_page) ],
      per_page    => 35,
    }
  );
  return $get_models;
}



sub _setup_list_action_bar {
  my ($self) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Purchasebasket'),
        submit  => [
          '#form', { action => "DispositionManager/add_to_purchase_basket" } ],
        tooltip => t8('Add to purchase basket'),
      ],
    );
  }
}

sub _setup_show_basket_action_bar {
  my ($self) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Reload'),
        link => $self->url_for(
          controller => 'DispositionManager',
          action     => 'show_basket',
        ),
      ],
      action => [
        t8('Action'),
        call    => [ 'kivi.DispositionManager.create_purchase_order' ],
        tooltip => t8('Create purchase order'),
      ],
      action => [
        t8('Delete'),
        call    => [ 'kivi.DispositionManager.delete_purchase_basket_items' ],
        tooltip => t8('Delete selected from purchase basket'),
      ],
    );
  }
}
1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::DispositionManager Controller to manage purchase orders for parts

=head1 DESCRIPTION

This controller shows a list of parts using the filter minimum stock (rop).
From this list it is possible to put parts in a purchase basket to order.
It's also possible to put parts from the parts edit form in the purchase basket.

From the purchase basket you can create a purchase order by using the filter vendor.
The quantity to order will be prefilled by the value min_qty_to_order from parts or
makemodel(vendor_parts) or default to qty 1.

Tables:

=over 2

=item purchase_basket

=back

Dependencies:

=over 2

=item parts

=item makemodels


=back

=head1 URL ACTIONS

=over 4

=item C<action_list_parts>

List the parts by the filter min stock (rop) and not in an open purchase order.

=item C<action_add_to_purchase_basket>

Adds one or more parts to the purchase basket.

=item C<action_show_basket>

Shows a list with parts which are in the basket.
This list can be filtered by vendor. Then you can create a purchase order.
When filtered by vendor, a table with the parts from the vendor of the purchase basket and
a table with all parts from the vendor will be shown. From there you can mark
the parts and create an order

=item C<action_transfer_to_purchase_order>

Transfers the marked and by vendor filtered parts to a purchase order.
Deletes the entry in the purchase basket.

=back

=head1 BUGS

None yet. :)

=head1 AUTHOR

W. Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
