package SL::Controller::Part;

use strict;
use parent qw(SL::Controller::Base);

use Carp;
use Clone qw(clone);
use Data::Dumper;
use DateTime;
use File::Temp;
use List::Util qw(sum);
use List::UtilsBy qw(extract_by);
use POSIX qw(strftime);
use Text::CSV_XS;

use SL::CVar;
use SL::Controller::Helper::GetModels;
use SL::DB::Business;
use SL::DB::BusinessModel;
use SL::DB::Helper::ValidateAssembly qw(validate_assembly);
use SL::DB::History;
use SL::DB::Part;
use SL::DB::PartsGroup;
use SL::DB::PriceRuleItem;
use SL::DB::PurchaseBasketItem;
use SL::DB::Shop;
use SL::Helper::Flash;
use SL::Helper::PrintOptions;
use SL::Helper::UserPreferences::PartPickerSearch;
use SL::JSON;
use SL::Locale::String qw(t8);
use SL::MoreCommon qw(save_form);
use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Part;
use SL::Presenter::Tag qw(select_tag);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(parts models part p warehouses multi_items_models
                                  makemodels businessmodels shops_not_assigned
                                  customerprices
                                  orphaned
                                  assortment assortment_items assembly assembly_items
                                  all_pricegroups all_translations all_partsgroups all_units
                                  all_buchungsgruppen all_payment_terms all_warehouses
                                  parts_classification_filter
                                  all_languages all_units all_price_factors
                                  all_businesses) ],
  'scalar'                => [ qw(warehouse bin stock_amounts journal) ],
);

# safety
__PACKAGE__->run_before(sub { $::auth->assert('part_service_assembly_edit', 1) || $::auth->assert('part_service_assembly_details') },
                        except => [ qw(ajax_autocomplete part_picker_search part_picker_result) ]);

__PACKAGE__->run_before(sub { $::auth->assert('developer') },
                        only => [ qw(test_page) ]);

__PACKAGE__->run_before('check_part_id', only   => [ qw(edit delete) ]);

# actions for editing parts
#
sub action_add_part {
  my ($self, %params) = @_;

  $self->part( SL::DB::Part->new_part );
  $self->add;
};

sub action_add_service {
  my ($self, %params) = @_;

  $self->part( SL::DB::Part->new_service );
  $self->add;
};

sub action_add_assembly {
  my ($self, %params) = @_;

  $self->part( SL::DB::Part->new_assembly );
  $self->add;
};

sub action_add_assortment {
  my ($self, %params) = @_;

  $self->part( SL::DB::Part->new_assortment );
  $self->add;
};

sub action_add_from_record {
  my ($self) = @_;

  check_has_valid_part_type($::form->{part}{part_type});

  die 'parts_classification_type must be "sales" or "purchases"'
    unless $::form->{parts_classification_type} =~ m/^(sales|purchases)$/;

  $self->parse_form;
  $self->add;
}

sub action_add {
  my ($self) = @_;

  check_has_valid_part_type($::form->{part_type});

  $self->action_add_part       if $::form->{part_type} eq 'part';
  $self->action_add_service    if $::form->{part_type} eq 'service';
  $self->action_add_assembly   if $::form->{part_type} eq 'assembly';
  $self->action_add_assortment if $::form->{part_type} eq 'assortment';
};

sub action_save {
  my ($self, %params) = @_;

  # checks that depend only on submitted $::form
  $self->check_form or return $self->js->render;

  my $is_new = !$self->part->id; # $ part gets loaded here

  # check that the part hasn't been modified
  unless ( $is_new ) {
    $self->check_part_not_modified or
      return $self->js->error(t8('The document has been changed by another user. Please reopen it in another window and copy the changes to the new window'))->render;
  }

  if (    $is_new
       && $::form->{part}{partnumber}
       && SL::DB::Manager::Part->find_by(partnumber => $::form->{part}{partnumber})
     ) {
    return $self->js->error(t8('The partnumber is already being used'))->render;
  }

  $self->parse_form;

  my @errors = $self->part->validate;
  return $self->js->error(@errors)->render if @errors;

  if ($is_new) {
    # Ensure CVars that should be enabled by default actually are when
    # creating new parts.
    my @default_valid_configs =
      grep { ! $_->{flag_defaults_to_invalid} }
      grep { $_->{module} eq 'IC' }
      @{ CVar->get_configs() };

    $::form->{"cvar_" . $_->{name} . "_valid"} = 1 for @default_valid_configs;
  } else {
    $self->{lastcost_modified} = $self->check_lastcost_modified;
  }

  # $self->part has been loaded, parsed and validated without errors and is ready to be saved
  $self->part->db->with_transaction(sub {

    $self->part->save(cascade => 1);
    $self->part->set_lastcost_assemblies_and_assortiments if $self->{lastcost_modified};

    SL::DB::History->new(
      trans_id    => $self->part->id,
      snumbers    => 'partnumber_' . $self->part->partnumber,
      employee_id => SL::DB::Manager::Employee->current->id,
      what_done   => 'part',
      addition    => 'SAVED',
    )->save();

    CVar->save_custom_variables(
      dbh           => $self->part->db->dbh,
      module        => 'IC',
      trans_id      => $self->part->id,
      variables     => $::form, # $::form->{cvar} would be nicer
      save_validity => 1,
    );

    1;
  }) or return $self->js->error(t8('The item couldn\'t be saved!') . " " . $self->part->db->error )->render;

  flash_later('info', $is_new ? t8('The item has been created.') . " " . $self->part->displayable_name : t8('The item has been saved.'));

  if ( $::form->{callback} ) {
    $self->redirect_to($::form->unescape($::form->{callback}) . '&new_parts_id=' . $self->part->id);

  } else {
    # default behaviour after save: reload item, this also resets last_modification!
    $self->redirect_to(controller => 'Part', action => 'edit', 'part.id' => $self->part->id);
  }
}

sub action_save_and_purchase_order {
  my ($self) = @_;

  my $session_value;
  if (1 == scalar @{$self->part->makemodels}) {
    my $prepared_form           = Form->new('');
    $prepared_form->{vendor_id} = $self->part->makemodels->[0]->make;
    $session_value              = $::auth->save_form_in_session(form => $prepared_form);
  }

  $::form->{callback} = $self->url_for(
    controller   => 'Order',
    action       => 'return_from_create_part',
    type         => 'purchase_order',
    previousform => $session_value,
  );

  $self->_run_action('save');
}

sub action_abort {
  my ($self) = @_;

  if ( $::form->{callback} ) {
    $self->redirect_to($::form->unescape($::form->{callback}));
  }
}

sub action_delete {
  my ($self) = @_;

  my $db = $self->part->db; # $self->part has a get_set_init on $::form

  my $partnumber = $self->part->partnumber; # remember for history log

  $db->do_transaction(
    sub {

      # delete part, together with relationships that don't already
      # have an ON DELETE CASCADE, e.g. makemodel and translation.
      $self->part->delete(cascade => 1);

      SL::DB::History->new(
        trans_id    => $self->part->id,
        snumbers    => 'partnumber_' . $partnumber,
        employee_id => SL::DB::Manager::Employee->current->id,
        what_done   => 'part',
        addition    => 'DELETED',
      )->save();
      1;
  }) or return $self->js->error(t8('The item couldn\'t be deleted!') . " " . $self->part->db->error)->render;

  flash_later('info', t8('The item has been deleted.'));
  if ( $::form->{callback} ) {
    $self->redirect_to($::form->unescape($::form->{callback}));
  } else {
    $self->redirect_to(controller => 'ic.pl', action => 'search', searchitems => 'article');
  }
}

sub action_use_as_new {
  my ($self, %params) = @_;

  my $oldpart = SL::DB::Manager::Part->find_by( id => $::form->{old_id}) or die "can't find old part";
  $::form->{oldpartnumber} = $oldpart->partnumber;

  $self->part($oldpart->clone_and_reset_deep);
  $self->parse_form(use_as_new => 1);
  $self->part->partnumber(undef);

  if (!$::auth->assert('part_service_assembly_edit_prices', 'may_fail')) {
    # No right to edit prices -> remove prices for new part.
    $self->part->$_(undef) for qw(sellprice lastcost listprice);
  }

  $self->render_form(use_as_new => 1);
}

sub action_edit {
  my ($self, %params) = @_;

  $self->render_form;
}

sub action_add_to_basket {
  my ( $self ) = @_;

  if ( !$self->_is_in_purchase_basket && scalar @{$self->part->makemodels}) {

    my $part = $self->part;

    my $needed_qty = $part->order_qty < ($part->rop - $part->onhandqty) ?
                     $part->rop - $part->onhandqty
                   : $part->order_qty;

    my $basket_part = SL::DB::PurchaseBasketItem->new(
      part_id     => $part->id,
      qty         => $needed_qty,
      orderer     => SL::DB::Manager::Employee->current,
    )->save;

    $self->js->flash('info', t8('Part added to purchasebasket'))->render;
  } else {
    $self->js->flash('error', t8('Part already in purchasebasket or has no vendor'))->render;
  }
  return 1;
}

sub render_form {
  my ($self, %params) = @_;

  $self->_set_javascript;
  $self->_setup_form_action_bar;

  my (%assortment_vars, %assembly_vars);
  %assortment_vars = %{ $self->prepare_assortment_render_vars } if $self->part->is_assortment;
  %assembly_vars   = %{ $self->prepare_assembly_render_vars   } if $self->part->is_assembly;

  $params{CUSTOM_VARIABLES}  = $params{use_as_new} && $::form->{old_id}
                            ?  CVar->get_custom_variables(module => 'IC', trans_id => $::form->{old_id})
                            :  CVar->get_custom_variables(module => 'IC', trans_id => $self->part->id);


  if (scalar @{ $params{CUSTOM_VARIABLES} }) {
    CVar->render_inputs('variables' => $params{CUSTOM_VARIABLES}, show_disabled_message => 1, partsgroup_id => $self->part->partsgroup_id);
    $params{CUSTOM_VARIABLES_FIRST_TAB}       = [];
    @{ $params{CUSTOM_VARIABLES_FIRST_TAB} }  = extract_by { $_->{first_tab} == 1 } @{ $params{CUSTOM_VARIABLES} };
  }

  my %title_hash = ( part       => t8('Edit Part'),
                     assembly   => t8('Edit Assembly'),
                     service    => t8('Edit Service'),
                     assortment => t8('Edit Assortment'),
                   );

  $self->part->prices([])       unless $self->part->prices;
  $self->part->translations([]) unless $self->part->translations;

  $self->render(
    'part/form',
    title             => $title_hash{$self->part->part_type},
    %assortment_vars,
    %assembly_vars,
    translations_map  => { map { ($_->language_id   => $_) } @{$self->part->translations} },
    prices_map        => { map { ($_->pricegroup_id => $_) } @{$self->part->prices      } },
    oldpartnumber     => $::form->{oldpartnumber},
    old_id            => $::form->{old_id},
    %params,
  );
}

sub action_history {
  my ($self) = @_;

  my $history_entries = SL::DB::Part->new(id => $::form->{part}{id})->history_entries;
  $_[0]->render('part/history', { layout => 0 },
                                  history_entries => $history_entries);
}

sub action_inventory {
  my ($self) = @_;

  $::auth->assert('warehouse_contents');

  $self->stock_amounts($self->part->get_simple_stock_sql);
  $self->journal($self->part->get_mini_journal);

  $_[0]->render('part/_inventory_data', { layout => 0 });
};

sub action_update_item_totals {
  my ($self) = @_;

  my $part_type = $::form->{part_type};
  die unless $part_type =~ /^(assortment|assembly)$/;

  my $sellprice_sum    = $self->recalc_item_totals(part_type => $part_type, price_type => 'sellcost');
  my $lastcost_sum     = $self->recalc_item_totals(part_type => $part_type, price_type => 'lastcost');
  my $items_weight_sum = $self->recalc_item_totals(part_type => $part_type, price_type => 'weight');

  my $sum_diff      = $sellprice_sum-$lastcost_sum;

  $self->js
    ->html('#items_sellprice_sum',       $::form->format_amount(\%::myconfig, $sellprice_sum, 2, 0))
    ->html('#items_lastcost_sum',        $::form->format_amount(\%::myconfig, $lastcost_sum,  2, 0))
    ->html('#items_sum_diff',            $::form->format_amount(\%::myconfig, $sum_diff,      2, 0))
    ->html('#items_sellprice_sum_basic', $::form->format_amount(\%::myconfig, $sellprice_sum, 2, 0))
    ->html('#items_lastcost_sum_basic',  $::form->format_amount(\%::myconfig, $lastcost_sum,  2, 0))
    ->html('#items_weight_sum_basic'   , $::form->format_amount(\%::myconfig, $items_weight_sum))
    ->no_flash_clear->render();
}

sub action_add_multi_assortment_items {
  my ($self) = @_;

  my $item_objects = $self->parse_add_items_to_objects(part_type => 'assortment');
  my $html         = $self->render_assortment_items_to_html($item_objects);

  $self->js->run('kivi.Part.close_picker_dialogs')
           ->append('#assortment_rows', $html)
           ->run('kivi.Part.renumber_positions')
           ->run('kivi.Part.assortment_recalc')
           ->render();
}

sub action_add_multi_assembly_items {
  my ($self) = @_;

  my $item_objects = $self->parse_add_items_to_objects(part_type => 'assembly');
  my @checked_objects;
  foreach my $item (@{$item_objects}) {
    my $errstr = validate_assembly($item->part,$self->part);
    $self->js->flash('error',$errstr) if     $errstr;
    push (@checked_objects,$item)     unless $errstr;
  }

  my $html = $self->render_assembly_items_to_html(\@checked_objects);

  $self->js->run('kivi.Part.close_picker_dialogs')
           ->append('#assembly_rows', $html)
           ->run('kivi.Part.renumber_positions')
           ->run('kivi.Part.assembly_recalc')
           ->render();
}

sub action_add_assortment_item {
  my ($self, %params) = @_;

  validate_add_items() or return $self->js->error(t8("No part was selected."))->render;

  carp('Too many objects passed to add_assortment_item') if @{$::form->{add_items}} > 1;

  my $add_item_id = $::form->{add_items}->[0]->{parts_id};
  if ( $add_item_id && grep { $add_item_id == $_->parts_id } @{ $self->assortment_items } ) {
    return $self->js->flash('error', t8("This part has already been added."))->render;
  };

  my $number_of_items = scalar @{$self->assortment_items};
  my $item_objects    = $self->parse_add_items_to_objects(part_type => 'assortment');
  my $html            = $self->render_assortment_items_to_html($item_objects, $number_of_items);

  push(@{$self->assortment_items}, @{$item_objects});
  my $part = SL::DB::Part->new(part_type => 'assortment');
  $part->assortment_items(@{$self->assortment_items});
  my $items_sellprice_sum = $part->items_sellprice_sum;
  my $items_lastcost_sum  = $part->items_lastcost_sum;
  my $items_sum_diff      = $items_sellprice_sum - $items_lastcost_sum;

  $self->js
    ->append('#assortment_rows'        , $html)  # append in tbody
    ->val('.add_assortment_item_input' , '')
    ->run('kivi.Part.focus_last_assortment_input')
    ->html("#items_sellprice_sum", $::form->format_amount(\%::myconfig, $items_sellprice_sum, 2, 0))
    ->html("#items_lastcost_sum",  $::form->format_amount(\%::myconfig, $items_lastcost_sum,  2, 0))
    ->html("#items_sum_diff",      $::form->format_amount(\%::myconfig, $items_sum_diff,      2, 0))
    ->html('#items_sellprice_sum_basic', $::form->format_amount(\%::myconfig, $items_sellprice_sum, 2, 0))
    ->html('#items_lastcost_sum_basic',  $::form->format_amount(\%::myconfig, $items_lastcost_sum,  2, 0))
    ->render;
}

sub action_add_assembly_item {
  my ($self) = @_;

  validate_add_items() or return $self->js->error(t8("No part was selected."))->render;

  carp('Too many objects passed to add_assembly_item') if @{$::form->{add_items}} > 1;

  my $add_item_id = $::form->{add_items}->[0]->{parts_id};

  my $duplicate_warning = 0; # duplicates are allowed, just warn
  if ( $add_item_id && grep { $add_item_id == $_->parts_id } @{ $self->assembly_items } ) {
    $duplicate_warning++;
  };

  my $number_of_items = scalar @{$self->assembly_items};
  my $item_objects    = $self->parse_add_items_to_objects(part_type => 'assembly');
  if ($add_item_id ) {
    foreach my $item (@{$item_objects}) {
      my $errstr = validate_assembly($item->part,$self->part);
      return $self->js->flash('error',$errstr)->render if $errstr;
    }
  }


  my $html            = $self->render_assembly_items_to_html($item_objects, $number_of_items);

  $self->js->flash('info', t8("This part has already been added.")) if $duplicate_warning;

  push(@{$self->assembly_items}, @{$item_objects});
  my $part = SL::DB::Part->new(part_type => 'assembly');
  $part->assemblies(@{$self->assembly_items});
  my $items_sellprice_sum = $part->items_sellprice_sum;
  my $items_lastcost_sum  = $part->items_lastcost_sum;
  my $items_sum_diff      = $items_sellprice_sum - $items_lastcost_sum;
  my $items_weight_sum    = $part->items_weight_sum;

  $self->js
    ->append('#assembly_rows', $html)  # append in tbody
    ->val('.add_assembly_item_input' , '')
    ->run('kivi.Part.focus_last_assembly_input')
    ->html('#items_sellprice_sum', $::form->format_amount(\%::myconfig, $items_sellprice_sum, 2, 0))
    ->html('#items_lastcost_sum' , $::form->format_amount(\%::myconfig, $items_lastcost_sum , 2, 0))
    ->html('#items_sum_diff',      $::form->format_amount(\%::myconfig, $items_sum_diff     , 2, 0))
    ->html('#items_sellprice_sum_basic', $::form->format_amount(\%::myconfig, $items_sellprice_sum, 2, 0))
    ->html('#items_lastcost_sum_basic' , $::form->format_amount(\%::myconfig, $items_lastcost_sum , 2, 0))
    ->html('#items_weight_sum_basic'   , $::form->format_amount(\%::myconfig, $items_weight_sum))
    ->render;
}

sub action_show_multi_items_dialog {
  my ($self) = @_;

  my $search_term = $self->models->filtered->laundered->{all_substr_multi__ilike};
  $search_term  ||= $self->models->filtered->laundered->{all_with_makemodel_substr_multi__ilike};
  $search_term  ||= $self->models->filtered->laundered->{all_with_customer_partnumber_substr_multi__ilike};

  $_[0]->render('part/_multi_items_dialog', { layout => 0 },
                all_partsgroups => SL::DB::Manager::PartsGroup->get_all,
                search_term     => $search_term
  );
}

sub action_multi_items_update_result {
  my $max_count = $::form->{limit};

  my $count = $_[0]->multi_items_models->count;

  if ($count == 0) {
    my $text = escape($::locale->text('No results.'));
    $_[0]->render($text, { layout => 0 });
  } elsif ($max_count && $count > $max_count) {
    my $text = escape($::locale->text('Too many results (#1 from #2).', $count, $max_count));
    $_[0]->render($text, { layout => 0 });
  } else {
    my $multi_items = $_[0]->multi_items_models->get;
    $_[0]->render('part/_multi_items_result', { layout => 0 },
                  multi_items => $multi_items);
  }
}

sub action_add_makemodel_row {
  my ($self) = @_;

  my $vendor_id = $::form->{add_makemodel};

  my $vendor = SL::DB::Manager::Vendor->find_by(id => $vendor_id) or
    return $self->js->error(t8("No vendor selected or found!"))->render;

  if ( grep { $vendor_id == $_->make } @{ $self->makemodels } ) {
    $self->js->flash('info', t8("This vendor has already been added."));
  };

  my $position = scalar @{$self->makemodels} + 1;

  my $mm = SL::DB::MakeModel->new(# parts_id           => $::form->{part}->{id},
                                  make                 => $vendor->id,
                                  model                => '',
                                  part_description     => '',
                                  part_longdescription => '',
                                  lastcost             => 0,
                                  sortorder            => $position,
                                 ) or die "Can't create MakeModel object";

  my $row_as_html = $self->p->render('part/_makemodel_row',
                                     makemodel => $mm,
                                     listrow   => $position % 2 ? 0 : 1,
  );

  # after selection focus on the model field in the row that was just added
  $self->js
    ->append('#makemodel_rows', $row_as_html)  # append in tbody
    ->val('.add_makemodel_input', '')
    ->run('kivi.Part.focus_last_makemodel_input')
    ->render;
}

sub action_add_businessmodel_row {
  my ($self) = @_;

  my $business_id = $::form->{add_businessmodel};

  my $business = SL::DB::Manager::Business->find_by(id => $business_id) or
    return $self->js->error(t8("No business selected or found!"))->render;

  if ( grep { $business_id == $_->business_id } @{ $self->businessmodels } ) {
    return $self->js
      ->scroll_into_view('#content')
      ->flash('error', (t8("This business has already been added.")))
      ->render;
  };

  my $position = scalar @{ $self->businessmodels } + 1;

  my $bm = SL::DB::BusinessModel->new(#parts_id             => $::form->{part}->{id},
                                      business             => $business,
                                      model                => '',
                                      part_description     => '',
                                      part_longdescription => '',
                                      position             => $position,
  ) or die "Can't create BusinessModel object";

  my $row_as_html = $self->p->render('part/_businessmodel_row',
                                     businessmodel => $bm);

  # after selection focus on the model field in the row that was just added
  $self->js
    ->append('#businessmodel_rows', $row_as_html)  # append in tbody
    ->val('#add_businessmodel', '')
    ->run('kivi.Part.focus_last_businessmodel_input')
    ->render;
}

sub action_add_customerprice_row {
  my ($self) = @_;

  my $customer_id = $::form->{add_customerprice};

  my $customer = SL::DB::Manager::Customer->find_by(id => $customer_id)
    or return $self->js->error(t8("No customer selected or found!"))->render;

  if (grep { $customer_id == $_->customer_id } @{ $self->customerprices }) {
    $self->js->flash('info', t8("This customer has already been added."));
  }

  my $position = scalar @{ $self->customerprices } + 1;

  my $cu = SL::DB::PartCustomerPrice->new(
                      customer_id          => $customer->id,
                      customer_partnumber  => '',
                      part_description     => '',
                      part_longdescription => '',
                      price                => 0,
                      sortorder            => $position,
  ) or die "Can't create Customerprice object";

  my $row_as_html = $self->p->render(
                                     'part/_customerprice_row',
                                      customerprice => $cu,
                                      listrow       => $position % 2 ? 0
                                                                     : 1,
  );

  $self->js->append('#customerprice_rows', $row_as_html)    # append in tbody
           ->val('.add_customerprice_input', '')
           ->run('kivi.Part.focus_last_customerprice_input')->render;
}

sub action_reorder_items {
  my ($self) = @_;

  my $part_type = $::form->{part_type};

  my %sort_keys = (
    partnumber  => sub { $_[0]->part->partnumber },
    description => sub { $_[0]->part->description },
    qty         => sub { $_[0]->qty },
    sellprice   => sub { $_[0]->part->sellprice },
    lastcost    => sub { $_[0]->part->lastcost },
    partsgroup  => sub { $_[0]->part->partsgroup_id ? $_[0]->part->partsgroup->partsgroup : '' },
  );

  my $method = $sort_keys{$::form->{order_by}};

  my @items;
  if ($part_type eq 'assortment') {
    @items = @{ $self->assortment_items };
  } else {
    @items = @{ $self->assembly_items };
  };

  my @to_sort = map { { old_pos => $_->position, order_by => $method->($_) } } @items;
  if ($::form->{order_by} =~ /^(qty|sellprice|lastcost)$/) {
    if ($::form->{sort_dir}) {
      @to_sort = sort { $a->{order_by} <=> $b->{order_by} } @to_sort;
    } else {
      @to_sort = sort { $b->{order_by} <=> $a->{order_by} } @to_sort;
    }
  } else {
    if ($::form->{sort_dir}) {
      @to_sort = sort { $a->{order_by} cmp $b->{order_by} } @to_sort;
    } else {
      @to_sort = sort { $b->{order_by} cmp $a->{order_by} } @to_sort;
    }
  };

  $self->js->run('kivi.Part.redisplay_items', \@to_sort)->render;
}

sub action_warehouse_changed {
  my ($self) = @_;

  if ($::form->{warehouse_id} ) {
    $self->warehouse(SL::DB::Manager::Warehouse->find_by_or_create(id => $::form->{warehouse_id}));
    die unless ref($self->warehouse) eq 'SL::DB::Warehouse';

    if ( $self->warehouse->id and @{$self->warehouse->bins} ) {
      $self->bin($self->warehouse->bins_sorted_naturally->[0]);
      $self->js
        ->html('#bin', $self->build_bin_select)
        ->focus('#part_bin_id');
      return $self->js->render;
    }
  }

  # no warehouse was selected, empty the bin field and reset the id
  $self->js
       ->val('#part_bin_id', undef)
       ->html('#bin', '');

  return $self->js->render;
}

sub action_ajax_autocomplete {
  my ($self, %params) = @_;

  # if someone types something, and hits enter, assume he entered the full name.
  # if something matches, treat that as sole match
  # since we need a second get models instance with different filters for that,
  # we only modify the original filter temporarily in place
  if ($::form->{prefer_exact}) {
    local $::form->{filter}{'all::ilike'}                          = delete local $::form->{filter}{'all:substr:multi::ilike'};
    local $::form->{filter}{'all_with_makemodel::ilike'}           = delete local $::form->{filter}{'all_with_makemodel:substr:multi::ilike'};
    local $::form->{filter}{'all_with_customer_partnumber::ilike'} = delete local $::form->{filter}{'all_with_customer_partnumber:substr:multi::ilike'};

    my $exact_models = SL::Controller::Helper::GetModels->new(
      controller   => $self,
      sorted       => 0,
      paginated    => { per_page => 2 },
      with_objects => [ qw(unit_obj classification) ],
    );
    my $exact_matches;
    if (1 == scalar @{ $exact_matches = $exact_models->get }) {
      $self->parts($exact_matches);
    }
  }

  my @hashes = map {
   +{
     value       => $_->displayable_name,
     label       => $_->displayable_name,
     id          => $_->id,
     partnumber  => $_->partnumber,
     description => $_->description,
     ean         => $_->ean,
     part_type   => $_->part_type,
     unit        => $_->unit,
     cvars       => { map { ($_->config->name => { value => $_->value_as_text, is_valid => $_->is_valid }) } @{ $_->cvars_by_config } },
    }
  } @{ $self->parts }; # neato: if exact match triggers we don't even need the init_parts

  $self->render(\ SL::JSON::to_json(\@hashes), { layout => 0, type => 'json', process => 0 });
}

sub action_test_page {
  $_[0]->render('part/test_page', pre_filled_part => SL::DB::Manager::Part->get_first);
}

sub action_part_picker_search {
  my ($self) = @_;

  my $search_term = $self->models->filtered->laundered->{all_substr_multi__ilike};
  $search_term  ||= $self->models->filtered->laundered->{all_with_makemodel_substr_multi__ilike};
  $search_term  ||= $self->models->filtered->laundered->{all_with_customer_partnumber_substr_multi__ilike};

  my $all_as_list = SL::Helper::UserPreferences::PartPickerSearch->new()->get_all_as_list_default;

  $_[0]->render('part/part_picker_search', { layout => 0 }, search_term => $search_term, all_as_list => $all_as_list);
}

sub action_part_picker_result {
  $_[0]->render('part/_part_picker_result', { layout => 0 }, parts => $_[0]->parts);
}

sub action_show {
  my ($self) = @_;

  if ($::request->type eq 'json') {
    my $part_hash;
    if (!$self->part) {
      # TODO error
    } else {
      $part_hash          = $self->part->as_tree;
      $part_hash->{cvars} = $self->part->cvar_as_hashref;
    }

    $self->render(\ SL::JSON::to_json($part_hash), { layout => 0, type => 'json', process => 0 });
  }
}

sub action_showdetails {
  my ($self, %params) = @_;

  my @bindata;
  my $bins = SL::DB::Manager::Bin->get_all(with_objects => ['warehouse' ]);
  my %bins_by_id = map { $_->id => $_ } @$bins;
  my $inventories = SL::DB::Manager::Inventory->get_all(where => [ parts_id => $self->part->id],
    with_objects => ['parts', 'trans_type' ], sort_by => 'bin_id ASC');
  foreach my $bin (@{ $bins }) {
    $bin->{qty} = 0;
  }

  foreach my $inv (@{ $inventories }) {
    my $bin = $bins_by_id{ $inv->bin_id };
    $bin->{qty}      += $inv->qty;
    $bin->{unit}     =  $inv->parts->unit;
  }
  my $sum = 0;
  for my $bin (@{ $bins }) {
    push @bindata , {
      'warehouse'    => $bin->warehouse->description,
      'description'  => $bin->description,
      'qty'          => $bin->{qty},
      'unit'         => $bin->{unit},
    } if $bin->{qty} != 0;

    $sum += $bin->{qty};
  }

  my $todate   = DateTime->now_local;
  my $fromdate = DateTime->now_local->add_duration(DateTime::Duration->new(years => -1));
  my $average  = 0;
  foreach my $inv (@{ $inventories }) {
    $average += abs($inv->qty) if $inv->shippingdate && $inv->trans_type->direction eq 'out' &&
    DateTime->compare($inv->shippingdate,$fromdate) != -1 &&
    DateTime->compare($inv->shippingdate,$todate)   == -1;
  }
  my $openitems = SL::DB::Manager::OrderItem->get_all(where => [ parts_id => $self->part->id, 'order.closed' => 0 ],
    with_objects => ['order'],);
  my ($not_delivered, $ordered) = 0;
  for my $openitem (@{ $openitems }) {
    if($openitem -> order -> type eq 'sales_order') {
      $not_delivered += $openitem->qty - $openitem->shipped_qty;
    } elsif ( $openitem->order->type eq 'purchase_order' ) {
      $ordered += $openitem->qty - $openitem->delivered_qty;
    }
  }

  my $stock_amounts = $self->part->get_simple_stock_sql;

  my $output = SL::Presenter->get->render('part/showdetails',
    part          => $self->part,
    stock_amounts => $stock_amounts,
    average       => $average/12,
    fromdate      => $fromdate,
    todate        => $todate,
    sum           => $sum,
    not_delivered => $not_delivered,
    ordered       => $ordered,
    print_options   => SL::Helper::PrintOptions->get_print_options(
      form => Form->new(
        type     => 'part',
        printers => SL::DB::Manager::Printer->get_all_sorted,
      ),
      options => {
        dialog_name_prefix     => 'print_options.',
        show_headers           => 1,
        no_queue               => 1,
        no_postscript          => 1,
        no_opendocument        => 1,
        hide_language_id_print => 1,
        no_html                => 1,
      },
    ),
  );
  $self->render(\$output, { layout => 0, process => 0 });
}

sub action_print_label {
  my ($self) = @_;
  # TODO: implement
  return $self->render('generic/error', { layout => 1 }, label_error => t8('Not implemented yet!'));
}

sub action_export_assembly_assortment_components {
  my ($self) = @_;

  my $bom_or_charge = $self->part->is_assembly ? 'bom' : 'charge';

  my @rows = ([
    $::locale->text('Partnumber'),
    $::locale->text('Description'),
    $::locale->text('Type'),
    $::locale->text('Classification'),
    $::locale->text('Qty'),
    $::locale->text('Unit'),
    $self->part->is_assembly ? $::locale->text('BOM') : $::locale->text('Charge'),
    $::locale->text('Line Total'),
    $::locale->text('Sellprice'),
    $::locale->text('Lastcost'),
    $::locale->text('Partsgroup'),
  ]);

  foreach my $item (@{ $self->part->items }) {
    my $part = $item->part;

    my @row = (
      $part->partnumber,
      $part->description,
      SL::Presenter::Part::type_abbreviation($part->part_type),
      SL::Presenter::Part::classification_abbreviation($part->classification_id),
      $item->qty_as_number,
      $part->unit,
      $item->$bom_or_charge ? $::locale->text('yes') : $::locale->text('no'),
      $::form->format_amount(\%::myconfig, $item->linetotal_sellprice, 3, 0),
      $part->sellprice_as_number,
      $part->lastcost_as_number,
      $part->partsgroup ? $part->partsgroup->partsgroup : '',
    );

    push @rows, \@row;
  }

  my $csv = Text::CSV_XS->new({
    sep_char => ';',
    eol      => "\n",
    binary   => 1,
  });

  my ($file_handle, $file_name) = File::Temp::tempfile;

  binmode $file_handle, ":encoding(utf8)";

  $csv->print($file_handle, $_) for @rows;

  $file_handle->close;

  my $type_prefix     = $self->part->is_assembly ? 'assembly' : 'assortment';
  my $part_number     = $self->part->partnumber;
  $part_number        =~ s{[^[:word:]]+}{_}g;
  my $timestamp       = strftime('_%Y-%m-%d_%H-%M-%S', localtime());
  my $attachment_name = sprintf('%s_components_%s_%s.csv', $type_prefix, $part_number, $timestamp);

  $self->send_file(
    $file_name,
    content_type => 'text/csv',
    name         => $attachment_name,
  );

}

# helper functions
sub validate_add_items {
  scalar @{$::form->{add_items}};
}

sub prepare_assortment_render_vars {
  my ($self) = @_;

  my %vars = ( items_sellprice_sum => $self->part->items_sellprice_sum,
               items_lastcost_sum  => $self->part->items_lastcost_sum,
               assortment_html     => $self->render_assortment_items_to_html( \@{$self->part->items} ),
             );
  $vars{items_sum_diff} = $vars{items_sellprice_sum} - $vars{items_lastcost_sum};

  return \%vars;
}

sub prepare_assembly_render_vars {
  my ($self) = @_;

  croak("Need assembly item(s) to create a 'save as new' assembly.") unless $self->part->items;

  my %vars = ( items_sellprice_sum => $self->part->items_sellprice_sum,
               items_lastcost_sum  => $self->part->items_lastcost_sum,
               assembly_html       => $self->render_assembly_items_to_html( \@{ $self->part->items } ),
             );
  $vars{items_sum_diff} = $vars{items_sellprice_sum} - $vars{items_lastcost_sum};

  return \%vars;
}

sub add {
  my ($self) = @_;

  check_has_valid_part_type($self->part->part_type);

  $self->_set_javascript;
  $self->_setup_form_action_bar;

  my %title_hash = ( part       => t8('Add Part'),
                     assembly   => t8('Add Assembly'),
                     service    => t8('Add Service'),
                     assortment => t8('Add Assortment'),
                   );

  $self->render(
    'part/form',
    title => $title_hash{$self->part->part_type},
  );
}


sub _set_javascript {
  my ($self) = @_;
  $::request->layout->use_javascript("${_}.js")  for qw(kivi.Part kivi.File kivi.PriceRule kivi.ShopPart kivi.Validator);
  $::request->layout->add_javascripts_inline("\$(function(){kivi.PriceRule.load_price_rules_for_part(@{[ $self->part->id ]})});") if $self->part->id;
}

sub recalc_item_totals {
  my ($self, %params) = @_;

  if ( $params{part_type} eq 'assortment' ) {
    return 0 unless scalar @{$self->assortment_items};
  } elsif ( $params{part_type} eq 'assembly' ) {
    return 0 unless scalar @{$self->assembly_items};
  } else {
    carp "can only calculate sum for assortments and assemblies";
  };

  my $part = SL::DB::Part->new(part_type => $params{part_type});
  if ( $part->is_assortment ) {
    $part->assortment_items( @{$self->assortment_items} );
    if ( $params{price_type} eq 'lastcost' ) {
      return $part->items_lastcost_sum;
    } else {
      if ( $params{pricegroup_id} ) {
        return $part->items_sellprice_sum(pricegroup_id => $params{pricegroup_id});
      } else {
        return $part->items_sellprice_sum;
      };
    }
  } elsif ( $part->is_assembly ) {
    $part->assemblies( @{$self->assembly_items} );
    if ( $params{price_type} eq 'weight' ) {
      return $part->items_weight_sum;
    } elsif ( $params{price_type} eq 'lastcost' ) {
      return $part->items_lastcost_sum;
    } else {
      return $part->items_sellprice_sum;
    }
  }
}

sub check_part_not_modified {
  my ($self) = @_;

  return !($::form->{last_modification} && ($self->part->last_modification ne $::form->{last_modification}));

}

sub check_lastcost_modified {
  my ($self) = @_;

  return    (abs($self->part->lastcost                                               - $self->part->last_price_update->lastcost)     >= 0.009)
         || (abs(($self->part->price_factor ? $self->part->price_factor->factor : 1) - $self->part->last_price_update->price_factor) >= 0.009);
}

sub parse_form {
  my ($self, %params) = @_;

  my $is_new = !$self->part->id;

  my $params = delete($::form->{part}) || { };

  if (!$::auth->assert('part_service_assembly_edit_prices', 'may_fail')) {
    # No right to set or change prices, so delete prices from params.
    delete $params->{$_} for qw(sellprice_as_number lastcost_as_number listprice_as_number);
  }

  delete $params->{id};
  $self->part->assign_attributes(%{ $params});
  $self->part->bin_id(undef) unless $self->part->warehouse_id;

  $self->normalize_text_blocks;

  # Only reset items ([]) and rewrite from form if $::form->{assortment_items} isn't empty. This
  # will be the case for used assortments when saving, or when a used assortment
  # is "used as new"
  if ( $self->part->is_assortment and $::form->{assortment_items} and scalar @{$::form->{assortment_items}}) {
    $self->part->assortment_items([]);
    $self->part->add_assortment_items(@{$self->assortment_items}); # assortment_items has a get_set_init
  };

  if ( $self->part->is_assembly and $::form->{assembly_items} and @{$::form->{assembly_items}} ) {
    $self->part->assemblies([]); # completely rewrite assortments each time
    $self->part->add_assemblies( @{ $self->assembly_items } );
  };

  # Update lastcost for assemblies
  if ($self->part->is_assembly) {
    my $lastcost_sum = $self->recalc_item_totals(part_type => $self->part->part_type, price_type => 'lastcost');
    $self->part->lastcost($lastcost_sum);
  }

  $self->part->translations([]) unless $params{use_as_new};
  $self->parse_form_translations;

  if ($::auth->assert('part_service_assembly_edit_prices', 'may_fail')) {
    $self->part->prices([]);
    $self->parse_form_prices;
  }

  $self->parse_form_customerprices;
  $self->parse_form_makemodels;
  $self->parse_form_businessmodels;
}

sub parse_form_prices {
  my ($self) = @_;
  # only save prices > 0
  my $prices = delete($::form->{prices}) || [];
  foreach my $price ( @{$prices} ) {
    my $sellprice = $::form->parse_amount(\%::myconfig, $price->{price});
    next unless $sellprice > 0; # skip negative prices as well
    my $p = SL::DB::Price->new(parts_id      => $self->part->id,
                               pricegroup_id => $price->{pricegroup_id},
                               price         => $sellprice,
                              );
    $self->part->add_prices($p);
  };
}

sub parse_form_translations {
  my ($self) = @_;
  # don't add empty translations
  my $translations = delete($::form->{translations}) || [];
  foreach my $translation ( @{$translations} ) {
    next unless $translation->{translation};
    my $t = SL::DB::Translation->new( %{$translation} ) or die "Can't create translation";
    $self->part->add_translations( $translation );
  };
}

sub parse_form_makemodels {
  my ($self) = @_;

  my $makemodels_map;
  if ( $self->part->makemodels ) { # check for new parts or parts without makemodels
    $makemodels_map = { map { $_->id => Rose::DB::Object::Helpers::clone($_) } @{$self->part->makemodels} };
  };

  $self->part->makemodels([]);

  my $position = 0;
  my $makemodels = delete($::form->{makemodels}) || [];
  foreach my $makemodel ( @{$makemodels} ) {
    next unless $makemodel->{make};
    $position++;
    my $vendor = SL::DB::Manager::Vendor->find_by(id => $makemodel->{make}) || die "Can't find vendor from make";

    my $id = $makemodels_map->{$makemodel->{id}} ? $makemodels_map->{$makemodel->{id}}->id : undef;
    my $mm = SL::DB::MakeModel->new( # parts_id           => $self->part->id, # will be assigned by row add_makemodels
                                     id                   => $id,
                                     make                 => $makemodel->{make},
                                     model                => $makemodel->{model} || '',
                                     part_description     => $makemodel->{part_description},
                                     part_longdescription => $makemodel->{part_longdescription},
                                     lastcost             => $::form->parse_amount(\%::myconfig, $makemodel->{lastcost_as_number}),
                                     sortorder            => $position,
                                   );

    if (!$::auth->assert('part_service_assembly_edit_prices', 'may_fail')) {
      # No right to edit prices -> restore old lastcost.
      $mm->lastcost($makemodels_map->{$id} ? $makemodels_map->{$id}->lastcost : undef);
    }

    if ($makemodels_map->{$mm->id} && !$makemodels_map->{$mm->id}->lastupdate && $makemodels_map->{$mm->id}->lastcost == 0 && $mm->lastcost == 0) {
      # lastupdate isn't set, original lastcost is 0 and new lastcost is 0
      # don't change lastupdate
    } elsif ( !$makemodels_map->{$mm->id} && $mm->lastcost == 0 ) {
      # new makemodel, no lastcost entered, leave lastupdate empty
    } elsif ($makemodels_map->{$mm->id} && $makemodels_map->{$mm->id}->lastcost == $mm->lastcost) {
      # lastcost hasn't changed, use original lastupdate
      $mm->lastupdate($makemodels_map->{$mm->id}->lastupdate);
    } else {
      $mm->lastupdate(DateTime->now);
    };
    $self->part->makemodel( scalar @{$self->part->makemodels} ? 1 : 0 ); # do we need this boolean anymore?
    $self->part->add_makemodels($mm);
  };
}

sub parse_form_businessmodels {
  my ($self) = @_;

  my $make_key = sub { return $_[0]->parts_id . '+' . $_[0]->business_id; };

  my $businessmodels_map;
  if ( $self->part->businessmodels ) { # check for new parts or parts without businessmodels
    $businessmodels_map = { map { $make_key->($_) => Rose::DB::Object::Helpers::clone($_) } @{$self->part->businessmodels} };
  };

  $self->part->businessmodels([]);

  my $position = 0;
  my $businessmodels = delete($::form->{businessmodels}) || [];
  foreach my $businessmodel ( @{$businessmodels} ) {
    next unless $businessmodel->{business_id};

    $position++;
    my $bm = SL::DB::BusinessModel->new( #parts_id            => $self->part->id,            # will be assigned by row add_businessmodels
                                         business_id          => $businessmodel->{business_id},
                                         model                => $businessmodel->{model} || '',
                                         part_description     => $businessmodel->{part_description} || '',
                                         part_longdescription => $businessmodel->{part_longdescription} || '',
                                         position             => $position,
    );

    $self->part->add_businessmodels($bm);
  };
}

sub parse_form_customerprices {
  my ($self) = @_;

  my $customerprices_map;
  if ( $self->part->customerprices ) { # check for new parts or parts without customerprices
    $customerprices_map = { map { $_->id => Rose::DB::Object::Helpers::clone($_) } @{$self->part->customerprices} };
  };

  $self->part->customerprices([]);

  my $position = 0;
  my $customerprices = delete($::form->{customerprices}) || [];
  foreach my $customerprice ( @{$customerprices} ) {
    next unless $customerprice->{customer_id};
    $position++;
    my $customer = SL::DB::Manager::Customer->find_by(id => $customerprice->{customer_id}) || die "Can't find customer from id";

    my $id = $customerprices_map->{$customerprice->{id}} ? $customerprices_map->{$customerprice->{id}}->id : undef;
    my $cu = SL::DB::PartCustomerPrice->new( # parts_id   => $self->part->id, # will be assigned by row add_customerprices
                                     id                   => $id,
                                     customer_id          => $customerprice->{customer_id},
                                     customer_partnumber  => $customerprice->{customer_partnumber} || '',
                                     part_description     => $customerprice->{part_description},
                                     part_longdescription => $customerprice->{part_longdescription},
                                     price                => $::form->parse_amount(\%::myconfig, $customerprice->{price_as_number}),
                                     sortorder            => $position,
                                   );

    if (!$::auth->assert('part_service_assembly_edit_prices', 'may_fail')) {
      # No right to edit prices -> restore old price.
      $cu->price($customerprices_map->{$id} ? $customerprices_map->{$id}->price : undef);
    }

    if ($customerprices_map->{$cu->id} && !$customerprices_map->{$cu->id}->lastupdate && $customerprices_map->{$cu->id}->price == 0 && $cu->price == 0) {
      # lastupdate isn't set, original price is 0 and new lastcost is 0
      # don't change lastupdate
    } elsif ( !$customerprices_map->{$cu->id} && $cu->price == 0 ) {
      # new customerprice, no lastcost entered, leave lastupdate empty
    } elsif ($customerprices_map->{$cu->id} && $customerprices_map->{$cu->id}->price == $cu->price) {
      # price hasn't changed, use original lastupdate
      $cu->lastupdate($customerprices_map->{$cu->id}->lastupdate);
    } else {
      $cu->lastupdate(DateTime->now);
    };
    $self->part->add_customerprices($cu);
  };
}

sub build_bin_select {
  select_tag('part.bin_id', [ @{ $_[0]->warehouse->bins_sorted_naturally } ],
    title_key => 'description',
    default   => $_[0]->bin->id,
  );
}


# get_set_inits for partpicker

sub init_parts {
  if ($::form->{no_paginate}) {
    $_[0]->models->disable_plugin('paginated');
  }

  $_[0]->models->get;
}

# get_set_inits for part controller
sub init_part {
  my ($self) = @_;

  # used by edit, save, delete and add

  if ( $::form->{part}{id} ) {
    return SL::DB::Part->new(id => $::form->{part}{id})->load(with => [ qw(makemodels businessmodels customerprices prices translations partsgroup shop_parts shop_parts.shop) ]);
  } elsif ( $::form->{id} ) {
    return SL::DB::Part->new(id => $::form->{id})->load; # used by inventory tab
  } else {
    die "part_type missing" unless $::form->{part}{part_type};
    return SL::DB::Part->new(part_type => $::form->{part}{part_type});
  };
}

sub init_orphaned {
  my ($self) = @_;
  return $self->part->orphaned;
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted => {
      _default  => {
        by => 'partnumber',
        dir  => 1,
      },
      partnumber  => t8('Partnumber'),
      description  => t8('Description'),
    },
    with_objects => [ qw(unit_obj classification) ],
  );
}

sub init_p {
  SL::Presenter->get;
}


sub init_assortment_items {
  # this init is used while saving and whenever assortments change dynamically
  my ($self) = @_;
  my $position = 0;
  my @array;
  my $assortment_items = delete($::form->{assortment_items}) || [];
  foreach my $assortment_item ( @{$assortment_items} ) {
    next unless $assortment_item->{parts_id};
    $position++;
    my $part = SL::DB::Manager::Part->find_by(id => $assortment_item->{parts_id}) || die "Can't determine item to be added";
    my $ai = SL::DB::AssortmentItem->new( parts_id      => $part->id,
                                          qty           => $::form->parse_amount(\%::myconfig, $assortment_item->{qty_as_number}),
                                          charge        => $assortment_item->{charge},
                                          unit          => $assortment_item->{unit} || $part->unit,
                                          position      => $position,
    );

    push(@array, $ai);
  };
  return \@array;
}

sub init_makemodels {
  my ($self) = @_;

  my $position = 0;
  my @makemodel_array = ();
  my $makemodels = delete($::form->{makemodels}) || [];

  foreach my $makemodel ( @{$makemodels} ) {
    next unless $makemodel->{make};
    $position++;
    my $mm = SL::DB::MakeModel->new( # parts_id   => $self->part->id, # will be assigned by row add_makemodels
                                    id                   => $makemodel->{id},
                                    make                 => $makemodel->{make},
                                    model                => $makemodel->{model} || '',
                                    part_description     => $makemodel->{part_description} || '',
                                    part_longdescription => $makemodel->{part_longdescription} || '',
                                    lastcost             => $::form->parse_amount(\%::myconfig, $makemodel->{lastcost_as_number} || 0),
                                    sortorder            => $position,
                                  ) or die "Can't create mm";
    # $mm->id($makemodel->{id}) if $makemodel->{id};
    push(@makemodel_array, $mm);
  };
  return \@makemodel_array;
}

sub init_businessmodels {
  my ($self) = @_;

  my @businessmodel_array = ();
  my $businessmodels = delete($::form->{businessmodels}) || [];

  foreach my $businessmodel ( @{$businessmodels} ) {
    next unless $businessmodel->{business_id};

    my $bm = SL::DB::BusinessModel->new(#parts_id            => $self->part->id,             # will be assigned by row add_businessmodels
                                        business_id          => $businessmodel->{business_id},
                                        model                => $businessmodel->{model} || '',
                                        part_description     => $businessmodel->{part_description} || '',
                                        part_longdescription => $businessmodel->{part_longdescription} || '',
                                  ) or die "Can't create bm";

    push(@businessmodel_array, $bm);
  };

  return \@businessmodel_array;
}

sub init_customerprices {
  my ($self) = @_;

  my $position = 0;
  my @customerprice_array = ();
  my $customerprices = delete($::form->{customerprices}) || [];

  foreach my $customerprice ( @{$customerprices} ) {
    next unless $customerprice->{customer_id};
    $position++;
    my $cu = SL::DB::PartCustomerPrice->new( # parts_id   => $self->part->id, # will be assigned by row add_customerprices
                                    id                   => $customerprice->{id},
                                    customer_partnumber  => $customerprice->{customer_partnumber},
                                    customer_id          => $customerprice->{customer_id} || '',
                                    part_description     => $customerprice->{part_description},
                                    part_longdescription => $customerprice->{part_longdescription},
                                    price                => $::form->parse_amount(\%::myconfig, $customerprice->{price_as_number} || 0),
                                    sortorder            => $position,
                                  ) or die "Can't create cu";
    # $cu->id($customerprice->{id}) if $customerprice->{id};
    push(@customerprice_array, $cu);
  };
  return \@customerprice_array;
}

sub init_assembly_items {
  my ($self) = @_;
  my $position = 0;
  my @array;
  my $assembly_items = delete($::form->{assembly_items}) || [];
  foreach my $assembly_item ( @{$assembly_items} ) {
    next unless $assembly_item->{parts_id};
    $position++;
    my $part = SL::DB::Manager::Part->find_by(id => $assembly_item->{parts_id}) || die "Can't determine item to be added";
    my $ai = SL::DB::Assembly->new(parts_id    => $part->id,
                                   bom         => $assembly_item->{bom},
                                   qty         => $::form->parse_amount(\%::myconfig, $assembly_item->{qty_as_number}),
                                   position    => $position,
                                  );
    push(@array, $ai);
  };
  return \@array;
}

sub init_all_warehouses {
  my ($self) = @_;
  SL::DB::Manager::Warehouse->get_all(query => [ or => [ invalid => 0, invalid => undef, id => $self->part->warehouse_id ] ]);
}

sub init_all_languages {
  SL::DB::Manager::Language->get_all_sorted;
}

sub init_all_partsgroups {
  my ($self) = @_;
  SL::DB::Manager::PartsGroup->get_all_sorted(query => [ or => [ id => $self->part->partsgroup_id, obsolete => 0 ] ]);
}

sub init_all_buchungsgruppen {
  my ($self) = @_;
  if (!$self->part->orphaned) {
    return SL::DB::Manager::Buchungsgruppe->get_all_sorted(where => [ id => $self->part->buchungsgruppen_id ]);
  }

  return SL::DB::Manager::Buchungsgruppe->get_all_sorted(
    where => [
      or => [
        id       => $self->part->buchungsgruppen_id,
        obsolete => 0,
      ],
    ]
  );
}

sub init_shops_not_assigned {
  my ($self) = @_;

  my @used_shop_ids = map { $_->shop->id } @{ $self->part->shop_parts };
  if ( @used_shop_ids ) {
    return SL::DB::Manager::Shop->get_all( query => [ obsolete => 0, '!id' => \@used_shop_ids ], sort_by => 'sortkey' );
  }
  else {
    return SL::DB::Manager::Shop->get_all( query => [ obsolete => 0 ], sort_by => 'sortkey' );
  }
}

sub init_all_units {
  my ($self) = @_;
  if ( $self->part->orphaned ) {
    return SL::DB::Manager::Unit->get_all_sorted;
  } else {
    return SL::DB::Manager::Unit->get_all(where => [ unit => $self->part->unit ]);
  }
}

sub init_all_payment_terms {
  my ($self) = @_;
  SL::DB::Manager::PaymentTerm->get_all_sorted(query => [ or => [ id => $self->part->payment_id, obsolete => 0 ] ]);
}

sub init_all_price_factors {
  SL::DB::Manager::PriceFactor->get_all_sorted;
}

sub init_all_pricegroups {
  SL::DB::Manager::Pricegroup->get_all_sorted(query => [ obsolete => 0 ]);
}

sub init_all_businesses {
  SL::DB::Manager::Business->get_all_sorted;
}

# model used to filter/display the parts in the multi-items dialog
sub init_multi_items_models {
  SL::Controller::Helper::GetModels->new(
    controller     => $_[0],
    model          => 'Part',
    with_objects   => [ qw(unit_obj partsgroup classification) ],
    disable_plugin => 'paginated',
    source         => $::form->{multi_items},
    sorted         => {
      _default    => {
        by  => 'partnumber',
        dir => 1,
      },
      partnumber  => t8('Partnumber'),
      description => t8('Description')}
  );
}

sub init_parts_classification_filter {
  return [] unless $::form->{parts_classification_type};

  return [ used_for_sale     => 't' ] if $::form->{parts_classification_type} eq 'sales';
  return [ used_for_purchase => 't' ] if $::form->{parts_classification_type} eq 'purchases';

  die "no query rules for parts_classification_type " . $::form->{parts_classification_type};
}

# simple checks to run on $::form before saving

sub form_check_part_description_exists {
  my ($self) = @_;

  return 1 if $::form->{part}{description};

  $self->js->flash('error', t8('Part Description missing!'))
           ->run('kivi.Part.set_tab_active_by_name', 'basic_data')
           ->focus('#part_description');
  return 0;
}

sub form_check_assortment_items_exist {
  my ($self) = @_;

  return 1 unless $::form->{part}{part_type} eq 'assortment';
  # skip item check for existing assortments that have been used
  return 1 if ($self->part->id and !$self->part->orphaned);

  # new or orphaned parts must have items in $::form->{assortment_items}
  unless ( $::form->{assortment_items} and scalar @{$::form->{assortment_items}} ) {
    $self->js->run('kivi.Part.set_tab_active_by_name', 'assortment_tab')
             ->focus('#add_assortment_item_name')
             ->flash('error', t8('The assortment doesn\'t have any items.'));
    return 0;
  };
  return 1;
}

sub form_check_assortment_items_unique {
  my ($self) = @_;

  return 1 unless $::form->{part}{part_type} eq 'assortment';

  my %duplicate_elements;
  my %count;
  for (map { $_->{parts_id} } @{$::form->{assortment_items}}) {
    $duplicate_elements{$_}++ if $count{$_}++;
  };

  if ( keys %duplicate_elements ) {
    $self->js->run('kivi.Part.set_tab_active_by_name', 'assortment_tab')
             ->flash('error', t8('There are duplicate assortment items'));
    return 0;
  };
  return 1;
}

sub form_check_assembly_items_exist {
  my ($self) = @_;

  return 1 unless $::form->{part}->{part_type} eq 'assembly';

  # skip item check for existing assembly that have been used
  return 1 if ($self->part->id and !$self->part->orphaned);

  unless ( $::form->{assembly_items} and scalar @{$::form->{assembly_items}} ) {
    $self->js->run('kivi.Part.set_tab_active_by_name', 'assembly_tab')
             ->focus('#add_assembly_item_name')
             ->flash('error', t8('The assembly doesn\'t have any items.'));
    return 0;
  };
  return 1;
}

sub form_check_partnumber_is_unique {
  my ($self) = @_;

  if ( !$::form->{part}{id} and $::form->{part}{partnumber} ) {
    my $count = SL::DB::Manager::Part->get_all_count(where => [ partnumber => $::form->{part}{partnumber} ]);
    if ( $count ) {
      $self->js->flash('error', t8('The partnumber already exists!'))
               ->focus('#part_description');
      return 0;
    };
  };
  return 1;
}

sub form_check_buchungsgruppe {
  my ($self) = @_;

  return 1 if $::form->{part}->{obsolete};

  my $buchungsgruppe = SL::DB::Buchungsgruppe->new(id => $::form->{part}->{buchungsgruppen_id})->load;

  return 1 if !$buchungsgruppe->obsolete;

  $self->js->flash('error', t8("The booking group '#1' is obsolete and cannot be used with active articles.", $buchungsgruppe->description))
    ->focus('#part_buchungsgruppen_id');

  return 0;
}

# general checking functions

sub check_part_id {
  die t8("Can't load item without a valid part.id") . "\n" unless $::form->{part}{id};
}

sub check_form {
  my ($self) = @_;

  $self->form_check_part_description_exists || return 0;
  $self->form_check_assortment_items_exist  || return 0;
  $self->form_check_assortment_items_unique || return 0;
  $self->form_check_assembly_items_exist    || return 0;
  $self->form_check_partnumber_is_unique    || return 0;
  $self->form_check_buchungsgruppe          || return 0;

  return 1;
}

sub check_has_valid_part_type {
  die "invalid part_type" unless $_[0] =~ /^(part|service|assembly|assortment)$/;
}


sub normalize_text_blocks {
  my ($self) = @_;

  # check if feature is enabled (select normalize_part_descriptions from defaults)
  return unless ($::instance_conf->get_normalize_part_descriptions);

  # text block
  foreach (qw(description)) {
    $self->part->{$_} =~ s/\s+$//s;
    $self->part->{$_} =~ s/^\s+//s;
    $self->part->{$_} =~ s/ {2,}/ /g;
  }
  # html block (caveat: can be circumvented by using bold or italics)
  $self->part->{notes} =~ s/^<p>(&nbsp;)+\s+/<p>/s;
  $self->part->{notes} =~ s/(&nbsp;)+<\/p>$/<\/p>/s;

}

sub render_assortment_items_to_html {
  my ($self, $assortment_items, $number_of_items) = @_;

  my $position = $number_of_items + 1;
  my $html;
  foreach my $ai (@$assortment_items) {
    $html .= $self->p->render('part/_assortment_row',
                              PART     => $self->part,
                              orphaned => $self->orphaned,
                              ITEM     => $ai,
                              listrow  => $position % 2 ? 1 : 0,
                              position => $position, # for legacy assemblies
                             );
    $position++;
  };
  return $html;
}

sub render_assembly_items_to_html {
  my ($self, $assembly_items, $number_of_items) = @_;

  my $position = $number_of_items + 1;
  my $html;
  foreach my $ai (@{$assembly_items}) {
    $html .= $self->p->render('part/_assembly_row',
                              PART     => $self->part,
                              orphaned => $self->orphaned,
                              ITEM     => $ai,
                              listrow  => $position % 2 ? 1 : 0,
                              position => $position, # for legacy assemblies
                             );
    $position++;
  };
  return $html;
}

sub parse_add_items_to_objects {
  my ($self, %params) = @_;
  my $part_type = $params{part_type};
  die unless $params{part_type} =~ /^(assortment|assembly)$/;
  my $position = $params{position} || 1;

  my @add_items = grep { $_->{qty_as_number} } @{ $::form->{add_items} };

  my @item_objects;
  foreach my $item ( @add_items ) {
    my $part = SL::DB::Manager::Part->find_by(id => $item->{parts_id}) || die "Can't load part";
    my $ai;
    if ( $part_type eq 'assortment' ) {
       $ai = SL::DB::AssortmentItem->new(part          => $part,
                                         qty           => $::form->parse_amount(\%::myconfig, $item->{qty_as_number}),
                                         unit          => $part->unit, # TODO: $item->{unit} || $part->unit
                                         position      => $position,
                                        ) or die "Can't create AssortmentItem from item";
    } elsif ( $part_type eq 'assembly' ) {
      $ai = SL::DB::Assembly->new(parts_id    => $part->id,
                                 # id          => $self->assembly->id, # will be set on save
                                 qty         => $::form->parse_amount(\%::myconfig, $item->{qty_as_number}),
                                 bom         => 0, # default when adding: no bom
                                 position    => $position,
                                );
    } else {
      die "part_type must be assortment or assembly";
    }
    push(@item_objects, $ai);
    $position++;
  };

  return \@item_objects;
}

sub _is_in_purchase_basket {
  my ( $self ) = @_;

  return SL::DB::Manager::PurchaseBasketItem->get_all_count( query => [ part_id => $self->part->id ] );
}

sub _is_ordered {
  my ( $self ) = @_;

  return $self->part->get_ordered_qty( $self->part->id );
}

sub _setup_form_action_bar {
  my ($self) = @_;

  my $may_edit           = $::auth->assert('part_service_assembly_edit', 'may fail');
  my $used_in_pricerules = !!SL::DB::Manager::PriceRuleItem->get_all_count(where => [type => 'part', value_int => $self->part->id]);

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          call      => [ 'kivi.Part.save' ],
          disabled  => !$may_edit ? t8('You do not have the permissions to access this function.') : undef,
          checks    => ['kivi.validate_form'],
        ],
        action => [
          t8('Use as new'),
          call     => [ 'kivi.Part.use_as_new' ],
          disabled => !$self->part->id ? t8('The object has not been saved yet.')
                    : !$may_edit       ? t8('You do not have the permissions to access this function.')
                    :                    undef,
        ],
      ], # end of combobox "Save"

      combobox => [
        action => [ t8('Workflow') ],
        action => [
          t8('Save and Purchase Order'),
          submit   => [ '#ic', { action => "Part/save_and_purchase_order" } ],
          checks   => ['kivi.validate_form'],
          disabled => !$self->part->id                                    ? t8('The object has not been saved yet.')
                    : !$may_edit                                          ? t8('You do not have the permissions to access this function.')
                    : !$::auth->assert('purchase_order_edit', 'may fail') ? t8('You do not have the permissions to access this function.')
                    : $self->part->order_locked                           ? t8('This part should not be ordered any more.')
                    :                                                       undef,
          only_if  => !$::form->{inline_create},
        ],
      ],

      combobox => [
        action => [
          t8('Export'),
          only_if => $self->part->is_assembly || $self->part->is_assortment,
        ],
        action => [
          $self->part->is_assembly ? t8('Assembly items') : t8('Assortment items'),
          submit   => [ '#ic', { action => "Part/export_assembly_assortment_components" } ],
          checks   => ['kivi.validate_form'],
          disabled => !$self->part->id                                    ? t8('The object has not been saved yet.')
                    : !$may_edit                                          ? t8('You do not have the permissions to access this function.')
                    : !$::auth->assert('purchase_order_edit', 'may fail') ? t8('You do not have the permissions to access this function.')
                    :                                                       undef,
          only_if  => $self->part->is_assembly || $self->part->is_assortment,
        ],
      ],

      action => [
        t8('Abort'),
        submit   => [ '#ic', { action => "Part/abort" } ],
        only_if  => !!$::form->{inline_create},
      ],

      action => [
        t8('Delete'),
        call     => [ 'kivi.Part.delete' ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => !$self->part->id       ? t8('This object has not been saved yet.')
                  : !$may_edit             ? t8('You do not have the permissions to access this function.')
                  : !$self->part->orphaned ? t8('This object has already been used.')
                  : $used_in_pricerules    ? t8('This object is used in price rules.')
                  :                          undef,
      ],

      action => [
        t8('Add to basket'),
        call     => [ 'kivi.Part.add_to_basket' ],
        disabled => !$self->part->id       ? t8('This object has not been saved yet.')
                  : $self->_is_in_purchase_basket ? t8('Part already in purchasebasket')
                  : $self->_is_ordered ? t8('Part already ordered')
                  : !scalar @{$self->part->makemodels} ? t8('No vendors to add to purchasebasket')
                  : undef,
      ],

      'separator',

      action => [
        t8('History'),
        call     => [ 'kivi.Part.open_history_popup' ],
        disabled => !$self->part->id ? t8('This object has not been saved yet.')
                  : !$may_edit       ? t8('You do not have the permissions to access this function.')
                  :                    undef,
      ],
    );
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Part - Part CRUD controller

=head1 DESCRIPTION

Controller for adding/editing/saving/deleting parts.

All the relations are loaded at once and saving the part, adding a history
entry and saving CVars happens inside one transaction.  When saving the old
relations are deleted and written as new to the database.

Relations for parts:

=over 2

=item makemodels

=item translations

=item assembly items

=item assortment items

=item prices

=back

=head1 PART_TYPES

There are 4 different part types:

=over 4

=item C<part>

The "default" part type.

inventory_accno_id is set.

=item C<service>

Services can't be stocked.

inventory_accno_id isn't set.

=item C<assembly>

Assemblies consist of other parts, services, assemblies or assortments. They
aren't meant to be bought, only sold. To add assemblies to stock you typically
have to make them, which reduces the stock by its respective components. Once
an assembly item has been created there is currently no way to "disassemble" it
again. An assembly item can appear several times in one assembly. An assmbly is
sold as one item with a defined sellprice and lastcost. If the component prices
change the assortment price remains the same. The assembly items may be printed
in a record if the item's "bom" is set.

=item C<assortment>

Similar to assembly, but each assortment item may only appear once per
assortment. When selling an assortment the assortment items are added to the
record together with the assortment, which is added with sellprice 0.

Technically an assortment doesn't have a sellprice, but rather the sellprice is
determined by the sum of the current assortment item prices when the assortment
is added to a record. This also means that price rules and customer discounts
will be applied to the assortment items.

Once the assortment items have been added they may be modified or deleted, just
as if they had been added manually, the individual assortment items aren't
linked to the assortment or the other assortment items in any way.

=back

=head1 URL ACTIONS

=over 4

=item C<action_add_part>

=item C<action_add_service>

=item C<action_add_assembly>

=item C<action_add_assortment>

=item C<action_add PART_TYPE>

An alternative to the action_add_$PART_TYPE actions, takes the mandatory
parameter part_type as an action. Example:

  controller.pl?action=Part/add&part_type=service

=item C<action_add_from_record>

When adding new items to records they can be created on the fly if the entered
partnumber or description doesn't exist yet. After being asked what part type
the new item should have the user is redirected to the correct edit page.

Depending on whether the item was added from a sales or a purchase record, only
the relevant part classifications should be selectable for new item, so this
parameter is passed on via a hidden parts_classification_type in the new_item
template.

=item C<action_save>

Saves the current part and then reloads the edit page for the part.

=item C<action_use_as_new>

Takes the information from the current part, plus any modifications made on the
page, and creates a new edit page that is ready to be saved. The partnumber is
set empty, so a new partnumber from the number range will be used if the user
doesn't enter one manually.

Unsaved changes to the original part aren't updated.

The part type cannot be changed in this way.

=item C<action_delete>

Deletes the current part and then redirects to the main page, there is no
callback.

The delete button only appears if the part is 'orphaned', according to
SL::DB::Part orphaned.

The part can't be deleted if it appears in invoices, orders, delivery orders,
the inventory, or is part of an assembly or assortment.

If the part is deleted its relations prices, makdemodel, assembly,
assortment_items and translation are are also deleted via DELETE ON CASCADE.

Before this controller items that appeared in inventory didn't count as
orphaned and could be deleted and the inventory entries were also deleted, this
"feature" hasn't been implemented.

=item C<action_edit part.id>

Load and display a part for editing.

  controller.pl?action=Part/edit&part.id=12345

Passing the part id is mandatory, and the parameter is "part.id", not "id".

=back

=head1 BUTTON ACTIONS

=over 4

=item C<history>

Opens a popup displaying all the history entries. Once a new history controller
is written the button could link there instead, with the part already selected.

=back

=head1 AJAX ACTIONS

=over 4

=item C<action_update_item_totals>

Is called whenever an element with the .recalc class loses focus, e.g. the qty
amount of an item changes. The sum of all sellprices and lastcosts is
calculated and the totals updated. Uses C<recalc_item_totals>.

=item C<action_add_assortment_item>

Adds a new assortment item from a part picker seleciton to the assortment item list

If the item already exists in the assortment the item isn't added and a Flash
error shown.

Rather than running kivi.Part.renumber_positions and kivi.Part.assembly_recalc
after adding each new item, add the new object to the item objects that were
already parsed, calculate totals via a dummy part then update the row and the
totals.

=item C<action_add_assembly_item>

Adds a new assembly item from a part picker seleciton to the assembly item list

If the item already exists in the assembly a flash info is generated, but the
item is added.

Rather than running kivi.Part.renumber_positions and kivi.Part.assembly_recalc
after adding each new item, add the new object to the item objects that were
already parsed, calculate totals via a dummy part then update the row and the
totals.

=item C<action_add_multi_assortment_items>

Parses the items to be added from the form generated by the multi input and
appends the html of the tr-rows to the assortment item table. Afterwards all
assortment items are renumbered and the sums recalculated via
kivi.Part.renumber_positions and kivi.Part.assortment_recalc.

=item C<action_add_multi_assembly_items>

Parses the items to be added from the form generated by the multi input and
appends the html of the tr-rows to the assembly item table. Afterwards all
assembly items are renumbered and the sums recalculated via
kivi.Part.renumber_positions and kivi.Part.assembly_recalc.

=item C<action_show_multi_items_dialog>

=item C<action_multi_items_update_result>

=item C<action_add_makemodel_row>

Add a new makemodel row with the vendor that was selected via the vendor
picker.

Checks the already existing makemodels and warns if a row with that vendor
already exists. Currently it is possible to have duplicate vendor rows.

=item C<action_reorder_items>

Sorts the item table for assembly or assortment items.

=item C<action_warehouse_changed>

=back

=head1 ACTIONS part picker

=over 4

=item C<action_ajax_autocomplete>

=item C<action_test_page>

=item C<action_part_picker_search>

=item C<action_part_picker_result>

=item C<action_show>

=back

=head1 FORM CHECKS

=over 2

=item C<check_form>

Calls some simple checks that test the submitted $::form for obvious errors.
Return 1 if all the tests were successfull, 0 as soon as one test fails.

Errors from the failed tests are stored as ClientJS actions in $self->js. In
some cases extra actions are taken, e.g. if the part description is missing the
basic data tab is selected and the description input field is focussed.

=back

=over 4

=item C<form_check_part_description_exists>

=item C<form_check_assortment_items_exist>

=item C<form_check_assortment_items_unique>

=item C<form_check_assembly_items_exist>

=item C<form_check_partnumber_is_unique>

=back

=head1 HELPER FUNCTIONS

=over 4

=item C<parse_form>

When submitting the form for saving, parses the transmitted form. Expects the
following data:

 $::form->{part}
 $::form->{makemodels}
 $::form->{translations}
 $::form->{prices}
 $::form->{assemblies}
 $::form->{assortments}

CVar data is currently stored directly in $::form, e.g. $::form->{cvar_size}.

=item C<recalc_item_totals %params>

Helper function for calculating the total lastcost and sellprice for assemblies
or assortments according to their items, which are parsed from the current
$::form.

Is called whenever the qty of an item is changed or items are deleted.

Takes two params:

* part_type : 'assortment' or 'assembly' (mandatory)

* price_type: 'lastcost' or 'sellprice', default is 'sellprice'

Depending on the price_type the lastcost sum or sellprice sum is returned.

Doesn't work for recursive items.

=back

=head1 GET SET INITS

There are get_set_inits for

* assembly items

* assortment items

* makemodels

which parse $::form and automatically create an array of objects.

These inits are used during saving and each time a new element is added.

=over 4

=item C<init_makemodels>

Parses $::form->{makemodels}, creates an array of makemodel objects and stores them in
$self->part->makemodels, ready to be saved.

Used for saving parts and adding new makemodel rows.

=item C<parse_add_items_to_objects PART_TYPE>

Parses the resulting form from either the part-picker submit or the multi-item
submit, and creates an arrayref of assortment_item or assembly objects, that
can be rendered via C<render_assortment_items_to_html> or
C<render_assembly_items_to_html>.

Mandatory param: part_type: assortment or assembly (the resulting html will differ)
Optional param: position (used for numbering and listrow class)

=item C<render_assortment_items_to_html ITEM_OBJECTS>

Takes an array_ref of assortment_items, and generates tables rows ready for
adding to the assortment table.  Is used when a part is loaded, or whenever new
assortment items are added.

=item C<parse_form_makemodels>

Makemodels can't just be overwritten, because of the field "lastupdate", that
remembers when the lastcost for that vendor changed the last time.

So the original values are cloned and remembered, so we can compare if lastcost
was changed in $::form, and keep or update lastupdate.

lastcost isn't updated until the first time it was saved with a value, until
then it is empty.

Also a boolean "makemodel" needs to be written in parts, depending on whether
makemodel entries exist or not.

We still need init_makemodels for when we open the part for editing.

=back

=head1 TODO

=over 4

=item *

It should be possible to jump to the edit page in a specific tab

=item *

Support callbacks, e.g. creating a new part from within an order, and jumping
back to the order again afterwards.

=item *

Support units when adding assembly items or assortment items. Currently the
default unit of the item is always used.

=item *

Calculate sellprice and lastcost totals recursively, in case e.g. an assembly
consists of other assemblies.

=back

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
