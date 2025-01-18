package SL::DB::Part;

use strict;

use Carp;
use List::MoreUtils qw(any uniq);
use List::Util qw(sum);
use Rose::DB::Object::Helpers qw(as_tree);

use SL::Locale::String qw(t8);
use SL::Helper::Inventory;
use SL::DBUtils;
use SL::DB::MetaSetup::Part;
use SL::DB::Manager::Part;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::AttrSorted;
use SL::DB::Helper::TransNumberGenerator;
use SL::DB::Helper::CustomVariables (
  module      => 'IC',
  cvars_alias => 1,
);
use SL::DB::Helper::DisplayableNamePreferences (
  title   => t8('Article'),
  options => [ {name => 'partnumber',  title => t8('Part Number')     },
               {name => 'description', title => t8('Description')    },
               {name => 'notes',       title => t8('Notes')},
               {name => 'partsgroup',  title => t8('Partsgroup'), sub => sub { $_[0]->partsgroup && $_[0]->partsgroup->partsgroup } },
               {name => 'ean',         title => t8('EAN')            }, ],
);


__PACKAGE__->meta->add_relationships(
  assemblies                     => {
    type         => 'one to many',
    class        => 'SL::DB::Assembly',
    manager_args => { sort_by => 'position' },
    column_map   => { id => 'id' },
  },
  prices         => {
    type         => 'one to many',
    class        => 'SL::DB::Price',
    column_map   => { id => 'parts_id' },
    manager_args => { with_objects => [ 'pricegroup' ] }
  },
  makemodels     => {
    type         => 'one to many',
    class        => 'SL::DB::MakeModel',
    manager_args => { sort_by => 'sortorder' },
    column_map   => { id => 'parts_id' },
  },
  businessmodels     => {
    type         => 'one to many',
    class        => 'SL::DB::BusinessModel',
    column_map   => { id => 'parts_id' },
  },
  customerprices => {
    type         => 'one to many',
    class        => 'SL::DB::PartCustomerPrice',
    column_map   => { id => 'parts_id' },
  },
  translations   => {
    type         => 'one to many',
    class        => 'SL::DB::Translation',
    column_map   => { id => 'parts_id' },
  },
  assortment_items => {
    type         => 'one to many',
    class        => 'SL::DB::AssortmentItem',
    column_map   => { id => 'assortment_id' },
    manager_args => { sort_by => 'position' },
  },
  history_entries   => {
    type            => 'one to many',
    class           => 'SL::DB::History',
    column_map      => { id => 'trans_id' },
    query_args      => [ what_done => 'part' ],
    manager_args    => { sort_by => 'itime' },
  },
  shop_parts     => {
    type         => 'one to many',
    class        => 'SL::DB::ShopPart',
    column_map   => { id => 'part_id' },
    manager_args => { with_objects => [ 'shop' ] },
  },
  last_price_update => {
    type         => 'one to one',
    class        => 'SL::DB::PartsPriceHistory',
    column_map   => { id => 'part_id' },
    manager_args => { sort_by => 'valid_from DESC, id DESC', limit => 1 },
  },
  purchase_basket_item => {
    type         => 'one to one',
    class        => 'SL::DB::PurchaseBasketItem',
    column_map   => { id => 'part_id' },
  },
);

__PACKAGE__->meta->initialize;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(onhandqty stockqty get_open_ordered_qty) ],
);
__PACKAGE__->attr_html('notes');
__PACKAGE__->attr_sorted({ unsorted => 'makemodels',     position => 'sortorder' });
__PACKAGE__->attr_sorted({ unsorted => 'customerprices', position => 'sortorder' });
__PACKAGE__->attr_sorted('businessmodels');

__PACKAGE__->before_save('_before_save_set_partnumber');
__PACKAGE__->before_save('_before_save_set_assembly_weight');

sub _before_save_set_partnumber {
  my ($self) = @_;

  $self->create_trans_number if !$self->partnumber;
  return 1;
}

sub _before_save_set_assembly_weight {
  my ($self) = @_;

  if ( $self->part_type eq 'assembly' ) {
    my $weight_sum = $self->items_weight_sum;
    $self->weight($self->items_weight_sum) if $weight_sum;
  }
  return 1;
}

sub items {
  my ($self) = @_;

  if ( $self->part_type eq 'assembly' ) {
    return $self->assemblies;
  } elsif ( $self->part_type eq 'assortment' ) {
    return $self->assortment_items;
  } else {
    return undef;
  }
}

sub items_checksum {
  my ($self) = @_;

  # for detecting if the items of an (orphaned) assembly or assortment have
  # changed when saving

  return join(' ', sort map { $_->part->id } @{$self->items});
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The partnumber is missing.')     if $self->id and !$self->partnumber;
  push @errors, $::locale->text('The unit is missing.')           unless $self->unit;
  push @errors, $::locale->text('The buchungsgruppe is missing.') unless $self->buchungsgruppen_id or $self->buchungsgruppe;

  if ( $::instance_conf->get_partsgroup_required
       && ( !$self->partsgroup_id or ( $self->id && !$self->partsgroup_id && $self->partsgroup ) ) ) {
    # when unsetting an existing partsgroup in the interface, $self->partsgroup_id will be undef but $self->partsgroup will still have a value
    # this needs to be checked, as partsgroup dropdown has an empty value
    push @errors, $::locale->text('The partsgroup is missing.');
  }

  unless ( $self->id ) {
    push @errors, $::locale->text('The partnumber already exists.') if SL::DB::Manager::Part->get_all_count(where => [ partnumber => $self->partnumber ]);
  }

  if ($self->is_assortment && $self->orphaned && scalar @{$self->assortment_items} == 0) {
    # when assortment isn't orphaned form doesn't contain any items
    push @errors, $::locale->text('The assortment doesn\'t have any items.');
  }

  if ($self->is_assembly && scalar @{$self->assemblies} == 0) {
    push @errors, $::locale->text('The assembly doesn\'t have any items.');
  }

  return @errors;
}

sub is_type {
  my $self = shift;
  my $type  = lc(shift || '');
  die 'invalid type' unless $type =~ /^(?:part|service|assembly|assortment)$/;

  return $self->type eq $type ? 1 : 0;
}

sub is_part       { $_[0]->part_type eq 'part'       }
sub is_assembly   { $_[0]->part_type eq 'assembly'   }
sub is_service    { $_[0]->part_type eq 'service'    }
sub is_assortment { $_[0]->part_type eq 'assortment' }

sub type {
  return $_[0]->part_type;
  # my ($self, $type) = @_;
  # if (@_ > 1) {
  #   die 'invalid type' unless $type =~ /^(?:part|service|assembly)$/;
  #   $self->assembly(          $type eq 'assembly' ? 1 : 0);
  #   $self->inventory_accno_id($type ne 'service'  ? 1 : undef);
  # }

  # return 'assembly' if $self->assembly;
  # return 'part'     if $self->inventory_accno_id;
  # return 'service';
}

sub new_part {
  my ($class, %params) = @_;
  $class->new(%params, part_type => 'part');
}

sub new_assembly {
  my ($class, %params) = @_;
  $class->new(%params, part_type => 'assembly');
}

sub new_service {
  my ($class, %params) = @_;
  $class->new(%params, part_type => 'service');
}

sub new_assortment {
  my ($class, %params) = @_;
  $class->new(%params, part_type => 'assortment');
}

sub last_modification {
  my ($self) = @_;
  return $self->mtime // $self->itime;
}

sub used_in_record {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  return 1 unless $self->id;

  my @relations = qw(
    SL::DB::InvoiceItem
    SL::DB::OrderItem
    SL::DB::DeliveryOrderItem
  );

  for my $class (@relations) {
    eval "require $class";
    return 1 if $class->_get_manager_class->get_all_count(query => [ parts_id => $self->id ]);
  }
  return 0;
}

sub orphaned {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  return 1 unless $self->id;

  my @relations = qw(
    SL::DB::InvoiceItem
    SL::DB::OrderItem
    SL::DB::DeliveryOrderItem
    SL::DB::Inventory
    SL::DB::AssortmentItem
  );

  for my $class (@relations) {
    eval "require $class";
    return 0 if $class->_get_manager_class->get_all_count(query => [ parts_id => $self->id ]);
  }
  return 1;
}

sub get_sellprice_info {
  my $self   = shift;
  my %params = @_;

  confess "Missing part id" unless $self->id;

  my $object = $self->load;

  return { sellprice       => $object->sellprice,
           price_factor_id => $object->price_factor_id };
}

sub get_ordered_qty {
  my $self   = shift;
  my %result = SL::DB::Manager::Part->get_ordered_qty($self->id);

  return $result{ $self->id };
}

sub available_units {
  shift->unit_obj->convertible_units;
}

# autogenerated accessor is slightly off...
sub buchungsgruppe {
  shift->buchungsgruppen(@_);
}

sub get_taxkey {
  my ($self, %params) = @_;

  my $date     = $params{date} || DateTime->today_local;
  my $is_sales = !!$params{is_sales};
  my $taxzone  = $params{ defined($params{taxzone}) ? 'taxzone' : 'taxzone_id' } * 1;
  my $tk_info  = $::request->cache('get_taxkey');

  $tk_info->{$self->id}                                      //= {};
  $tk_info->{$self->id}->{$taxzone}                          //= { };
  my $cache = $tk_info->{$self->id}->{$taxzone}->{$is_sales} //= { };

  if (!exists $cache->{$date}) {
    $cache->{$date} =
      $self->get_chart(type => $is_sales ? 'income' : 'expense', taxzone => $taxzone)
      ->get_active_taxkey($date);
  }

  return $cache->{$date};
}

sub get_chart {
  my ($self, %params) = @_;
  require SL::DB::Chart;

  my $type    = (any { $_ eq $params{type} } qw(income expense inventory)) ? $params{type} : croak("Invalid 'type' parameter '$params{type}'");
  my $taxzone = $params{ defined($params{taxzone}) ? 'taxzone' : 'taxzone_id' } * 1;

  my $charts     = $::request->cache('get_chart_id/by_part_id_and_taxzone')->{$self->id} //= {};
  my $all_charts = $::request->cache('get_chart_id/by_id');

  $charts->{$taxzone} ||= { };

  if (!exists $charts->{$taxzone}->{$type}) {
    require SL::DB::Buchungsgruppe;
    my $bugru    = SL::DB::Buchungsgruppe->load_cached($self->buchungsgruppen_id);
    my $chart_id = ($type eq 'inventory') ? ($self->is_part ? $bugru->inventory_accno_id : undef)
                 :                          $bugru->call_sub("${type}_accno_id", $taxzone);

    if ($chart_id) {
      my $chart                    = $all_charts->{$chart_id} // SL::DB::Chart->load_cached($chart_id)->load;
      $all_charts->{$chart_id}     = $chart;
      $charts->{$taxzone}->{$type} = $chart;
    }
  }

  return $charts->{$taxzone}->{$type};
}

sub get_stock {
  my ($self, %params) = @_;

  return undef unless $self->id;

  my $query = 'SELECT SUM(qty) FROM inventory WHERE parts_id = ?';
  my @values = ($self->id);

  if ( $params{bin_id} ) {
    $query .= ' AND bin_id = ?';
    push(@values, $params{bin_id});
  }

  if ( $params{warehouse_id} ) {
    $query .= ' AND warehouse_id = ?';
    push(@values, $params{warehouse_id});
  }

  if ( $params{shippingdate} ) {
    die unless ref($params{shippingdate}) eq 'DateTime';
    $query .= ' AND shippingdate <= ?';
    push(@values, $params{shippingdate});
  }

  my ($stock) = selectrow_query($::form, $self->db->dbh, $query, @values);

  return $stock || 0; # never return undef
}


# this is designed to ignore chargenumbers, expiration dates and just give a list of how much <-> where
sub get_simple_stock {
  my ($self, %params) = @_;

  return [] unless $self->id;

  my $query = <<'';
    SELECT sum(qty), warehouse_id, bin_id FROM inventory WHERE parts_id = ?
    GROUP BY warehouse_id, bin_id

  my $stock_info = selectall_hashref_query($::form, $::form->get_standard_dbh, $query, $self->id);
  [ map { bless $_, 'SL::DB::Part::SimpleStock'} @$stock_info ];
}
# helper class to have bin/warehouse accessors in stock result
{ package SL::DB::Part::SimpleStock;
  sub warehouse { require SL::DB::Warehouse; SL::DB::Manager::Warehouse->find_by_or_create(id => $_[0]->{warehouse_id}) }
  sub bin       { require SL::DB::Bin;       SL::DB::Manager::Bin      ->find_by_or_create(id => $_[0]->{bin_id}) }
}

sub get_simple_stock_sql {
  my ($self, %params) = @_;

  return [] unless $self->id;

  my $query = <<SQL;
     SELECT w.description                         AS warehouse_description,
            b.description                         AS bin_description,
            SUM(i.qty)                            AS qty,
            SUM(i.qty * p.lastcost / COALESCE(pfac.factor, 1))               AS stock_value,
            p.unit                                AS unit,
            LEAD(w.description)           OVER pt AS wh_lead,            -- to detect warehouse changes for subtotals in template
            SUM( SUM(i.qty) )             OVER pt AS run_qty,            -- running total of total qty
            SUM( SUM(i.qty) )             OVER wh AS wh_run_qty,         -- running total of warehouse qty
            SUM( SUM(i.qty * p.lastcost / COALESCE(pfac.factor, 1))) OVER pt AS run_stock_value,    -- running total of total stock_value
            SUM( SUM(i.qty * p.lastcost / COALESCE(pfac.factor, 1))) OVER wh AS wh_run_stock_value  -- running total of warehouse stock_value
       FROM inventory i
            LEFT JOIN parts p     ON (p.id           = i.parts_id)
            LEFT JOIN warehouse w ON (i.warehouse_id = w.id)
            LEFT JOIN bin b       ON (i.bin_id       = b.id)
            LEFT JOIN price_factors pfac ON (p.price_factor_id = pfac.id)
      WHERE parts_id = ?
   GROUP BY w.description, w.sortkey, b.description, p.unit, i.parts_id
     HAVING SUM(qty) != 0
     WINDOW pt AS (PARTITION BY i.parts_id    ORDER BY w.sortkey, b.description, p.unit),
            wh AS (PARTITION by w.description ORDER BY w.sortkey, b.description, p.unit)
   ORDER BY w.sortkey, b.description, p.unit
SQL

  my $stock_info = selectall_hashref_query($::form, $self->db->dbh, $query, $self->id);
  return $stock_info;
}

sub get_mini_journal {
  my ($self) = @_;

  # inventory ids of the most recent 10 inventory trans_ids

  # duplicate code copied from SL::Controller::Inventory mini_journal, except
  # for the added filter on parts_id

  my $parts_id = $self->id;
  my $query = <<"SQL";
with last_inventories as (
   select id,
          trans_id,
          itime
     from inventory
    where parts_id = $parts_id
 order by itime desc
    limit 20
),
grouped_ids as (
   select trans_id,
          array_agg(id) as ids
     from last_inventories
 group by trans_id
 order by max(itime)
     desc limit 10
)
select unnest(ids)
  from grouped_ids
 limit 20  -- so the planner knows how many ids to expect, the cte is an optimisation fence
SQL

  my $objs  = SL::DB::Manager::Inventory->get_all(
    query        => [ id => [ \"$query" ] ],                           # make emacs happy "]]
    with_objects => [ 'parts', 'trans_type', 'bin', 'bin.warehouse' ], # prevent lazy loading in template
    sort_by      => 'itime DESC',
  );
  # remember order of trans_ids from query, for ordering hash later
  my @sorted_trans_ids = uniq map { $_->trans_id } @$objs;

  # at most 2 of them belong to a transaction and the qty determines in or out.
  my %transactions;
  for (@$objs) {
    $transactions{ $_->trans_id }{ $_->qty > 0 ? 'in' : 'out' } = $_;
    $transactions{ $_->trans_id }{base} = $_;
  }

  # because the inventory transactions were built in a hash, we need to sort the
  # hash by using the original sort order of the trans_ids
  my @sorted = map { $transactions{$_} } @sorted_trans_ids;

  return \@sorted;
}

sub clone_and_reset_deep {
  my ($self) = @_;

  my $clone = $self->clone_and_reset; # resets id and partnumber (primary key and unique constraint)
  $clone->makemodels(   map { $_->clone_and_reset } @{$self->makemodels}   ) if @{$self->makemodels};
  $clone->translations( map { $_->clone_and_reset } @{$self->translations} ) if @{$self->translations};
  $clone->custom_variables( map { $_->clone_and_reset } @{$self->custom_variables} ) if @{$self->custom_variables};
  if ( $self->is_assortment ) {
    # use clone rather than reset_and_clone because the unique constraint would also remove parts_id
    $clone->assortment_items( map { $_->clone } @{$self->assortment_items} );
    $_->assortment_id(undef) foreach @{ $clone->assortment_items }
  }

  if ( $self->is_assembly ) {
    $clone->assemblies( map { $_->clone_and_reset } @{$self->assemblies});
  }

  if ( $self->prices ) {
    $clone->prices( map { $_->clone } @{$self->prices}); # pricegroup_id gets reset here because it is part of a unique contraint
    if ( $clone->prices ) {
      foreach my $price ( @{$clone->prices} ) {
        $price->id(undef);
        $price->parts_id(undef);
      }
    }
  }

  return $clone;
}

sub item_diffs {
  my ($self, $comparison_part) = @_;

  die "item_diffs needs a part object" unless ref($comparison_part) eq 'SL::DB::Part';
  die "part and comparison_part need to be of the same part_type" unless
        ( $self->part_type eq 'assembly' or $self->part_type eq 'assortment' )
    and ( $comparison_part->part_type eq 'assembly' or $comparison_part->part_type eq 'assortment' )
    and $self->part_type eq $comparison_part->part_type;

  # return [], [] if $self->items_checksum eq $comparison_part->items_checksum;
  my @self_part_ids       = map { $_->parts_id } $self->items;
  my @comparison_part_ids = map { $_->parts_id } $comparison_part->items;

  my %orig       = map{ $_ => 1 } @self_part_ids;
  my %comparison = map{ $_ => 1 } @comparison_part_ids;
  my (@additions, @removals);
  @additions = grep { !exists( $orig{$_}       ) } @comparison_part_ids if @comparison_part_ids;
  @removals  = grep { !exists( $comparison{$_} ) } @self_part_ids       if @self_part_ids;

  return \@additions, \@removals;
}

sub items_sellprice_sum {
  my ($self, %params) = @_;

  return unless $self->is_assortment or $self->is_assembly;
  return unless $self->items;

  if ($self->is_assembly) {
    return sum map { $_->linetotal_sellprice          } @{$self->items};
  } else {
    return sum map { $_->linetotal_sellprice(%params) } grep { $_->charge } @{$self->items};
  }
}

sub items_lastcost_sum {
  my ($self) = @_;

  return unless $self->is_assortment or $self->is_assembly;
  return unless $self->items;
  sum map { $_->linetotal_lastcost } @{$self->items};
}

sub items_weight_sum {
  my ($self) = @_;

  return unless $self->is_assembly;
  return unless $self->items;
  sum map { $_->linetotal_weight} @{$self->items};
}

sub set_lastcost_assemblies_and_assortiments {
  my ($self) = @_;

  return 1 unless $self->id;  # not saved yet

  require SL::DB::AssortmentItem;
  require SL::DB::Assembly;

  # 1. check all
  my $assortments = SL::DB::Manager::AssortmentItem->get_all(where => [parts_id => $self->id ]);
  my $assemblies  = SL::DB::Manager::Assembly->get_all(      where => [parts_id => $self->id ]);

  foreach my $assembly (@{ $assemblies }) {
    my $a = $assembly->assembly_part;
    $a->update_attributes(lastcost => $a->items_lastcost_sum);
    $a->set_lastcost_assemblies_and_assortiments;
  }
  foreach my $assortment (@{ $assortments }) {
    my $a = $assortment->assortment;
    $a->update_attributes(lastcost => $a->items_lastcost_sum);
    $a->set_lastcost_assemblies_and_assortiments;
  }
  return 1;
}

sub init_onhandqty{
  my ($self) = @_;
  my $qty = SL::Helper::Inventory::get_onhand(part => $self->id) || 0;
  return $qty;
}

sub init_stockqty{
  my ($self) = @_;
  my $qty = SL::Helper::Inventory::get_stock(part => $self->id) || 0;
  return $qty;
}

sub init_get_open_ordered_qty {
  my ($self) = @_;
  my $result = SL::DB::Manager::Part->get_open_ordered_qty($self->id);

  return $result;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::DB::Part: Model for the 'parts' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 TYPES

Although the base class is called C<Part> we usually talk about C<Articles> if
we mean instances of this class. This is because articles come in three
flavours called:

=over 4

=item Part     - a single part

=item Service  - a part without onhand, and without inventory accounting

=item Assembly - a collection of both parts and services

=item Assortment - a collection of items (parts or assemblies)

=back

These types are sadly represented by data inside the class and cannot be
migrated into a flag. To work around this, each C<Part> object knows what type
it currently is. Since the type is data driven, there ist no explicit setting
method for it, but you can construct them explicitly with C<new_part>,
C<new_service>, C<new_assembly> and C<new_assortment>. A Buchungsgruppe should be supplied in this
case, but it will use the default Buchungsgruppe if you don't.

Matching these there are assorted helper methods dealing with types,
e.g.  L</new_part>, L</new_service>, L</new_assembly>, L</type>,
L</is_type> and others.

=head1 FUNCTIONS

=over 4

=item C<new_part %PARAMS>

=item C<new_service %PARAMS>

=item C<new_assembly %PARAMS>

Will set the appropriate data fields so that the resulting instance will be of
the requested type. Since accounting targets are part of the distinction,
providing a C<Buchungsgruppe> is recommended. If none is given the constructor
will load a default one and set the accounting targets from it.

=item C<type>

Returns the type as a string. Can be one of C<part>, C<service>, C<assembly>.

=item C<is_type $TYPE>

Tests if the current object is a part, a service or an
assembly. C<$type> must be one of the words 'part', 'service' or
'assembly' (their plurals are ok, too).

Returns 1 if the requested type matches, 0 if it doesn't and
C<confess>es if an unknown C<$type> parameter is encountered.

=item C<is_part>

=item C<is_service>

=item C<is_assembly>

Shorthand for C<is_type('part')> etc.

=item C<get_sellprice_info %params>

Retrieves the C<sellprice> and C<price_factor_id> for a part under
different conditions and returns a hash reference with those two keys.

If C<%params> contains a key C<project_id> then a project price list
will be consulted if one exists for that project. In this case the
parameter C<country_id> is evaluated as well: if a price list entry
has been created for this country then it will be used. Otherwise an
entry without a country set will be used.

If none of the above conditions is met then the information from
C<$self> is used.

=item C<get_ordered_qty %params>

Retrieves the quantity that has been ordered from a vendor but that
has not been delivered yet. Only open purchase orders are considered.

=item C<get_taxkey %params>

Retrieves and returns a taxkey object valid for the given date
C<$params{date}> and tax zone C<$params{taxzone}>
(C<$params{taxzone_id}> is also recognized). The date defaults to the
current date if undefined.

This function looks up the income (for trueish values of
C<$params{is_sales}>) or expense (for falsish values of
C<$params{is_sales}>) account for the current part. It uses the part's
associated buchungsgruppe and uses the fields belonging to the tax
zone given by C<$params{taxzone}>.

The information retrieved by the function is cached.

=item C<get_chart %params>

Retrieves and returns a chart object valid for the given type
C<$params{type}> and tax zone C<$params{taxzone}>
(C<$params{taxzone_id}> is also recognized). The type must be one of
the three key words C<income>, C<expense> and C<inventory>.

This function uses the part's associated buchungsgruppe and uses the
fields belonging to the tax zone given by C<$params{taxzone}>.

The information retrieved by the function is cached.

=item C<used_in_record>

Checks if this article has been used in orders, invoices or delivery orders.

=item C<orphaned>

Checks if this article is used in orders, invoices, delivery orders or
assemblies.

=item C<buchungsgruppe BUCHUNGSGRUPPE>

Used to set the accounting information from a L<SL:DB::Buchungsgruppe> object.
Please note, that this is a write only accessor, the original Buchungsgruppe can
not be retrieved from an article once set.

=item C<get_simple_stock_sql>

Fetches the qty and the stock value for the current part for each bin and
warehouse where the part is in stock (or rather different from 0, might be
negative).

Runs some additional window functions to add the running totals (total running
total and total per warehouse) for qty and stock value to each line.

Using the LEAD(w.description) the template can check if the warehouse
description is about to change, i.e. the next line will contain numbers from a
different warehouse, so that a subtotal line can be added.

The last row will contain the running qty total (run_qty) and the running total
stock value (run_stock_value) over all warehouses/bins and can be used to add a
line for the grand totals.

=item C<items_lastcost_sum>

Non-recursive lastcost sum of all the items in an assembly or assortment.

=item C<get_stock %params>

Fetches stock qty in the default unit for a part.

bin_id and warehouse_id may be passed as params. If only a bin_id is passed,
the stock qty for that bin is returned. If only a warehouse_id is passed, the
stock qty for all bins in that warehouse is returned.  If a shippingdate is
passed the stock qty for that date is returned.

Examples:
 my $qty = $part->get_stock(bin_id => 52);

 $part->get_stock(shippingdate => DateTime->today->add(days => -5));

=back

=head1 AUTHORS

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>,
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
