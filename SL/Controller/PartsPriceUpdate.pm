package SL::Controller::PartsPriceUpdate;

use strict;
use parent qw(SL::Controller::Base);

use SL::DBUtils qw(prepare_query selectfirst_array_query prepare_query do_statement do_query);
use SL::JSON;
use SL::Helper::Flash qw(flash);
use SL::DB;
use SL::DB::Part;
use SL::DB::Pricegroup;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(pricegroups pricegroups_by_id filter) ],
);

__PACKAGE__->run_before('check_rights');


sub action_search_update_prices {
  my ($self) = @_;

  $self->setup_search_update_prices_action_bar;
  $self->render('ic/search_update_prices',
    title => t8('Update Prices'),
  );
}

sub action_confirm_price_update {
  my ($self) = @_;

  my @errors;
  my $found;

  for my $key (keys %{ $self->filter->{prices} || {} }) {
    my $row = $self->filter->{prices}{$key};

    next if $row->{price_as_number} eq '';

    my $type   = $row->{type};
    my $value  = $::form->parse_amount(\%::myconfig, $row->{price_as_number});
    my $name   = $key =~ /^\d+$/      ? $self->pricegroups_by_id->{$key}->pricegroup
               : $key eq 'sellprice'  ? t8('Sell Price')
               : $key eq 'listprice'  ? t8('List Price')
               :                        '';

    if (0 > $value && ($type eq 'percent')) {
      push @errors, t8('You cannot adjust the price for pricegroup "#1" by a negative percentage.', $name);
    } elsif (!$value) {
      push @errors, t8('No valid number entered for pricegroup "#1".', $name);
    } elsif (0 < $value) {
      $found = 1;
    }
  }

  push @errors, t8('No prices will be updated because no prices have been entered.') if !$found;

  my $num_matches = $self->get_num_matches_for_priceupdate();

  if (@errors) {
    flash('error', $_) for @errors;
    return $self->action_search_update_prices;
  } else {

    my $key = $::auth->create_unique_session_value(SL::JSON::to_json($self->filter));

    $self->setup_confirm_price_update_action_bar;
    $self->render('ic/confirm_price_update',
      num_matches => $num_matches,
      filter_key  => $key,
    );
  }
}

sub action_update_prices {
  my ($self) = @_;

  my $num_updated = $self->do_update_prices;

  if ($num_updated) {
    $::form->redirect(t8('#1 prices were updated.', $num_updated));
  } else {
    $::form->error(t8('Could not update prices!'));
  }
}

sub _create_filter_for_priceupdate {
  my ($self) = @_;
  my $filter = $self->filter;

  my @where_values;
  my $where = '1 = 1';

  for my $item (qw(partnumber drawing microfiche pg.partsgroup description serialnumber)) {
    my $column = $item;
    $column =~ s/.*\.//;
    next unless $filter->{$column};

    $where .= qq| AND $item ILIKE ?|;
    push @where_values, "%$filter->{$column}%";
  }

  # items which were never bought, sold or on an order
  if ($filter->{itemstatus} eq 'orphaned') {
    $where .=
      qq| AND (p.onhand = 0)
          AND p.id NOT IN
            (
              SELECT DISTINCT parts_id FROM invoice
              UNION
              SELECT DISTINCT parts_id FROM assembly
              UNION
              SELECT DISTINCT parts_id FROM orderitems
              UNION
              SELECT DISTINCT parts_id FROM delivery_order_items
            )|;

  } elsif ($filter->{itemstatus} eq 'active') {
    $where .= qq| AND p.obsolete = '0'|;

  } elsif ($filter->{itemstatus} eq 'obsolete') {
    $where .= qq| AND p.obsolete = '1'|;

  } elsif ($filter->{itemstatus} eq 'onhand') {
    $where .= qq| AND p.onhand > 0|;

  } elsif ($filter->{itemstatus} eq 'short') {
    $where .= qq| AND p.onhand < p.rop|;

  }

  if ($filter->{make}) {
    $where .= qq| AND p.id IN (SELECT DISTINCT parts_id FROM makemodel WHERE make = ?) |;
    push @where_values, $filter->{make};
  }

  if ($filter->{model}) {
    $where .= qq| AND p.id IN (SELECT DISTINCT parts_id FROM makemodel WHERE model ILIKE ?) |;
    push @where_values, "%$filter->{model}%";
  }

  return ($where, @where_values);
}

sub get_num_matches_for_priceupdate {
  my ($self)   = @_;
  my $filter   = $self->filter;
  my $dbh      = SL::DB->client->dbh;
  my ($where, @where_values) = $self->_create_filter_for_priceupdate;

  my $num_updated = 0;
  my $query;

  for my $column (qw(sellprice listprice)) {
    next if $filter->{prices}{$column}{price_as_number} eq "";

    $query =
      qq|SELECT COUNT(*)
         FROM parts
         WHERE id IN
           (SELECT p.id
            FROM parts p
            LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
            WHERE $where)|;
    my ($result)  = selectfirst_array_query($::form, $dbh, $query, @where_values);
    $num_updated += $result if (0 <= $result);
  }

  my @ids = grep { $filter->{prices}{$_}{price_as_number} } map { $_->id } @{ $self->pricegroups };
  if (@ids) {
    $query =
      qq|SELECT COUNT(*)
         FROM prices
         WHERE parts_id IN
           (SELECT p.id
            FROM parts p
            LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
            WHERE $where)
         AND pricegroup_id IN (@{[ join ',', ('?')x@ids ]})|;

    my ($result)  = selectfirst_array_query($::form, $dbh, $query, @where_values, @ids);
    $num_updated += $result if (0 <= $result);
  }

  return $num_updated;
}

sub do_update_prices {
  SL::DB->client->with_transaction(\&_update_prices, $_[0]);
}

sub _update_prices {
  my ($self) = @_;
  my $filter_json = $::auth->get_session_value($::form->{filter_key});
  my $filter = SL::JSON::from_json($filter_json);
  $self->filter($filter);
  die "missing filter" unless $filter;

  my ($where, @where_values) = $self->_create_filter_for_priceupdate;
  my $num_updated = 0;

  # connect to database
  my $dbh = SL::DB->client->dbh;

  for my $column (qw(sellprice listprice)) {
    my $row = $filter->{prices}{$column};
    next if ($row->{price_as_number} eq "");

    my $value = $::form->parse_amount(\%::myconfig, $row->{price_as_number});
    my $operator = '+';

    if ($row->{type} eq "percent") {
      $value = ($value / 100) + 1;
      $operator = '*';
    }

    my $query =
      qq|UPDATE parts SET $column = $column $operator ?
         WHERE id IN
           (SELECT p.id
            FROM parts p
            LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
            WHERE $where)|;
    my $result    = do_query($::form, $dbh, $query, $value, @where_values);
    $num_updated += $result if 0 <= $result;
  }

  my $q_add =
    qq|UPDATE prices SET price = price + ?
       WHERE parts_id IN
         (SELECT p.id
          FROM parts p
          LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
          WHERE $where) AND (pricegroup_id = ?)|;
  my $sth_add = prepare_query($::form, $dbh, $q_add);

  my $q_multiply =
    qq|UPDATE prices SET price = price * ?
       WHERE parts_id IN
         (SELECT p.id
          FROM parts p
          LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
          WHERE $where) AND (pricegroup_id = ?)|;
  my $sth_multiply = prepare_query($::form, $dbh, $q_multiply);

  for my $pg (@{ $self->pricegroups }) {
    my $row = $filter->{prices}{$pg->id};
    next if $row->{price_as_number} eq "";

    my $value = $::form->parse_amount(\%::myconfig, $row->{price_as_number});
    my $result;

    if ($row->{type} eq "percent") {
      $result = do_statement($::form, $sth_multiply, $q_multiply, ($value / 100) + 1, @where_values, $pg->id);
    } else {
      $result = do_statement($::form, $sth_add, $q_add, $value, @where_values, $pg->id);
    }

    $num_updated += $result if (0 <= $result);
  }

  $sth_add->finish;
  $sth_multiply->finish;

  1;
}

sub init_pricegroups {
  SL::DB::Manager::Pricegroup->get_all_sorted(query => [
    obsolete => 0,
  ]);
}

sub init_pricegroups_by_id {
  +{ map { $_->id => $_ } @{ $_[0]->pricegroups } }
}

sub check_rights {
  $::auth->assert('part_service_assembly_edit & part_service_assembly_edit_prices');
}

sub init_filter {
  $::form->{filter} || {};
}

sub setup_search_update_prices_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Continue'),
        submit    => [ '#form', { action => 'PartsPriceUpdate/confirm_price_update' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_confirm_price_update_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Continue'),
        submit    => [ '#form', { action => 'PartsPriceUpdate/update_prices' } ],
        accesskey => 'enter',
      ],

      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

1;
