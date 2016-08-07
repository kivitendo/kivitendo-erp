package SL::Controller::Part;

use strict;
use parent qw(SL::Controller::Base);

use Clone qw(clone);
use SL::DB::Part;
use SL::Controller::Helper::GetModels;
use SL::Locale::String qw(t8);
use SL::JSON;
use List::Util qw(sum);
use SL::Helper::Flash;
use Data::Dumper;
use DateTime;
use SL::DB::History;
use SL::CVar;
use Carp;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(parts models part p assortment_items assortment assembly makemodels prices translations warehouses assembly_items) ],
  'scalar'                => [ qw(warehouse bin) ],
);

# safety
__PACKAGE__->run_before(sub { $::auth->assert('part_service_assembly_edit') },
                        except => [ qw(ajax_autocomplete part_picker_search part_picker_result) ]);

# actions for editing parts

sub action_add_assortment {
  my ($self, %params) = @_;

  $self->part( SL::DB::Part->new_assortment );
  $self->add;
};

sub action_add_part {
  my ($self, %params) = @_;

  $self->part( SL::DB::Part->new_part );
  $self->add;
};

sub action_add_assembly {
  my ($self, %params) = @_;

  $self->part( SL::DB::Part->new_assembly );
  $self->add;
};

sub action_add_service {
  my ($self, %params) = @_;

  $self->part( SL::DB::Part->new_service );
  $self->add;
};

sub add {
  my ($self) = @_;

  die unless $self->part->part_type =~ /^(part|service|assembly|assortment)$/;

  # from now on we can always check for part_type via $self->part->part_type

  $self->_pre_render; # set js and all the Dropdowns (UNITS, PARTSGROUPS, ...)

  $self->render(
    'part/form',
    title             => t8('Add ' . ucfirst($self->part->part_type)),
    show_edit_buttons => $::auth->assert('part_service_assembly_edit'),
  );
};

sub action_save_as_new {
  my ($self) = @_;
  # the part must already exist, and some values may have been changed in form
  # do everything that action_save would, but at the end do a clone_and_reset
  # and save as new part, ignoring any changes to the original part
  $self->action_save(save_as_new=>1);
}

sub action_save {
  my ($self, %params) = @_;

  my $is_new = !$self->part->id; # self->part has an init that loads from form or creates a new object

  $main::lxdebug->dump(0, "form", $::form->{part} );

  # check for db constraints which will definitely cause a save to fail
  # simple checks that rely on data in $::form and are reported via flash
  # not null constraints in DB:
  #   partnumber     - Transnumber-Generator and unique
  #   description    - mustn't be empty
  #   unit           - unit dropdown has with_empty=0
  #   part_type      - a hidden is set while adding
  #   buchungsgruppe - dropdown has with_empty=0

  if ( $is_new and $::form->{part}->{partnumber} ) {

    $self->part->partnumber($::form->{part}->{partnumber});
    my $count = SL::DB::Manager::Part->get_all_count(where => [ partnumber => $self->part->partnumber ]);
    return $self->js->flash('error', t8('The partnumber already exists!'))
                    ->focus('#part_description')->render if $count;
  };

  unless ($::form->{part}->{description}) {
    return $self->js->run('kivi.Part.set_tab_active_by_name', 'basic_data')
                    ->focus('#part_description')
                    ->flash('error', t8('Part Description missing!'))
                    ->render;
  };

  if ( $::form->{part}->{part_type} eq 'assortment' ) {
    unless ( $::form->{assortment_items} ) {
      return $self->js->run('kivi.Part.set_tab_active_by_name', 'assortment_tab')
                      ->focus('#add_assortment_item_name')
                      ->flash('error', t8('The assortment doesn\'t have any items.'))
                      ->render;
    };
  };

  if ( $::form->{part}->{part_type} eq 'assembly' ) {
    unless ( $::form->{assembly_items} ) {
      return $self->js->run('kivi.Part.set_tab_active_by_name', 'assembly_tab')
                      ->focus('#add_assembly_item_name')
                      ->flash('error', t8('The assembly doesn\'t have any items.'))
                      ->render;
    };
  };

  $self->_instantiate_args; # deletes $::form->{part}

  # from now on we can access values via $self->part
  # make sure $self->part contains either a new part object or the correct loaded one

  $self->part->db->with_transaction(sub {

    # inside the transaction, don't return any js, simply die and collect the
    # errors for js flash at the end

    my $trans_number;
    if ( $is_new ) {

      # if partnumber was entered above, $self->part->partnumber was already set during initial check
      unless ( $self->part->partnumber ) {
        # is this necessary? SL::DB::Part->save has a before_save hook for this
        # but at least this way we can catch it and display the information to
        # the user with a description of our choice
        $self->part->partnumber($self->part->get_next_trans_number(update_defaults=>1));
        # check if the newly generated transnumber already exists
        my $count = SL::DB::Manager::Part->get_all_count(where => [ partnumber => $self->part->partnumber ]);
        die $::locale->text('The partnumber already exists.') . $self->part->partnumber . "\n" if $count;
      };
    };

    if ( $self->part->is_assortment ) {
      die t8('The assortment doesn\'t have any items.') unless scalar @{ $self->assortment_items };

      $self->part->assortment_items([]); # completely rewrite assortments each time
      foreach my $ai ( @{ $self->assortment_items } ) {
        $self->part->add_assortment_items( $ai );
      };
    };

    if ( $self->part->is_assembly ) {
      die t8('The assembly doesn\'t have any items.') unless scalar @{ $self->assembly_items };

      $self->part->assemblies([]); # completely rewrite assortments each time

      foreach my $ai ( @{ $self->assembly_items } ) {
        $self->part->add_assemblies( $ai );
      };
    };

    $self->part->prices([]);
    foreach my $price ( @{ $self->prices } ) { # parse $::form->{prices} and only add prices that aren't 0
      $self->part->add_prices( $price );
    };

    $self->part->translations([]);
    foreach my $translation ( @{ $self->translations } ) {
      next unless $translation->{translation}; # remove translations where description is empty
      $self->part->add_translations( $translation );
    };

    # remember old prices for lastupdate, assumes there is only one lastcost per vendor
    # if we worked with the id rather than rewriting everything we would compare via id or even use a trigger
    my (%old_mm_prices, %old_mm_lastupdates);
    unless ( $is_new ) {
      if ( scalar @{$self->part->makemodels } ) {
        %old_mm_prices      = map { $_->make => $_->lastcost   } @{$self->part->makemodels};
        %old_mm_lastupdates = map { $_->make => $_->lastupdate } @{$self->part->makemodels};
      }
    };
    $self->part->makemodels([]);
    foreach my $makemodel ( @{ $self->makemodels } ) {
      # if a makemodel lastcost exists and lastcost hasn't changed, keep it
      # otherwise set date to today
      if ( $old_mm_prices{$makemodel->make} && $old_mm_prices{$makemodel->make} == $makemodel->lastcost ) {
        $makemodel->lastupdate($old_mm_lastupdates{$makemodel->make});
      } else {
        $makemodel->lastupdate(DateTime->now);
      };
      $self->part->add_makemodels($makemodel);
    };
    $self->part->makemodel( scalar @{$self->part->makemodels} ? 1 : 0 ); # do we need this boolean anymore?

    # partnumber cases:
    # existing part: always use the original partnumber
    # new part:
    #  a) partnumber was entered, use that, but check for uniqueness
    #  b) no partnumber was entered, get one from TransNumberGenerator, but still check if for uniqueness
    # save as new: always uses a number from the "range of numbers"

    my @errors = $self->part->validate;
    if ( @errors ) {
      die "@errors\n";
    };

    if ( $params{save_as_new} ) {
      # the current form state of the (possibly modified but unsaved) part is used
      # no changes are made to the original part
      $self->part( $self->part->clone_and_reset_deep );
      $self->part->partnumber($self->part->get_next_trans_number(update_defaults=>1));
    };

    # finally save the part
    $self->part->save(cascade => 1);

    SL::DB::History->new(
      trans_id    => $self->part->id,
      snumbers    => 'partnumber_' . $self->part->partnumber,
      employee_id => SL::DB::Manager::Employee->current->id,
      what_done   => 'part',
      addition    => $params{save_as_new} ? 'SAVED AS NEW' : 'SAVED',
    )->save();

    CVar->save_custom_variables(
        dbh          => $self->part->db->dbh,
        module       => 'IC',
        trans_id     => $self->part->id,
        variables    => $::form,
        always_valid => 1,
    );

    1;
  }) or return $self->js->flash('error', t8('The item couldn\'t be saved!'))
                    ->flash('error', $self->part->db->error)
                    ->render;

  flash_later('info', $is_new ? $::locale->text('The item has been created.') : $::locale->text('The item has been saved.'));

  # reload item, this also resets last_modification!
  $self->redirect_to(controller => 'Part', action => 'edit', id => $self->part->id);
};

sub action_delete {
  my ($self) = @_;

  my $db = $self->part->db; # $self->part has a get_set_init on $::form

  $db->do_transaction(
    sub {

      # delete relations that don't have a "ON CASCADE DELETE"
      SL::DB::Manager::Translation->delete_all( where => [ parts_id => $self->part->id ] );

      # delete part
      $self->part->delete;

      SL::DB::History->new(
        trans_id    => $self->part->id,
        snumbers    => 'partnumber_' . $self->part->partnumber,
        employee_id => SL::DB::Manager::Employee->current->id,
        what_done   => 'part',
        addition    => 'DELETED',
      )->save();
      1;
  }) or return $self->js->flash('error', 'The item wasn\'t deleted!' . $self->part->db->error)->render;

  flash_later('info', $::locale->text('The item has been deleted.'));
  my @redirect_params = (
    controller => 'controller.pl',
    action => 'LoginScreen/user_login'
  );
  $self->redirect_to(@redirect_params);
}

sub load_part {
  my ($self) = @_;

  my $part = SL::DB::Part->new(id => $::form->{id})->load(with => [ qw(makemodels prices translations partsgroup) ]) or die "Can't load part";
  $self->part( $part );

}

sub action_edit {
  my ($self, %params) = @_;

  $self->load_part;

  $self->_pre_render; # set js and all the Dropdowns (UNITS, PARTSGROUPS, ...)

  my ($assortment_html , $assortment_sum , $assortment_sum_lastcost , $assortment_sum_diff);
  my ($assembly_html   , $assembly_sum   , $assembly_sum_lastcost   , $assembly_sum_diff);

  if ( $self->part->is_assortment ) {

    $assortment_sum          = sum map { $_->linetotal          } @{$self->part->assortment_items};
    $assortment_sum_lastcost = sum map { $_->linetotal_lastcost } @{$self->part->assortment_items};
    $assortment_sum_diff     = $assortment_sum-$assortment_sum_lastcost;

    my $listrow = 0;
    foreach my $assortment_item( @{$self->part->assortment_items} ) {
      $listrow++;
      $assortment_html .= $self->p->render('part/_assortment_row',
                                           ASSORTMENT_ITEM     => $assortment_item,
                                           listrow => $listrow % 2 ? 0 : 1,
                                          );
    };
  };
  if ( $self->part->is_assembly ) {

    $assembly_sum          = sum map { $_->linetotal          } @{$self->part->assemblies};
    $assembly_sum_lastcost = sum map { $_->linetotal_lastcost } @{$self->part->assemblies};
    $assembly_sum_diff     = $assembly_sum-$assembly_sum_lastcost;

    $main::lxdebug->message(0, "loaded assembly with items:" . scalar @{$self->part->assemblies} . " sum = $assembly_sum" );
    my $listrow = 0;
    foreach my $assembly_item( @{$self->part->assemblies} ) {
      $listrow++;
      $assembly_html .= $self->p->render('part/_assembly_row',
                                         ASSEMBLY_ITEM => $assembly_item,
                                         listrow       => $listrow % 2 ? 0 : 1,
                                        );
    };
  };

  $params{CUSTOM_VARIABLES}  = CVar->get_custom_variables(module => 'IC', trans_id => $self->part->id);

  # TODO: how does keep_cvars work?
  # if ($params{keep_cvars}) {
  #   for my $cvar (@{ $params{CUSTOM_VARIABLES} }) {
  #     $cvar->{value} = $::form->{"cvar_$cvar->{name}"} if $::form->{"cvar_$cvar->{name}"};
  #   }
  # }

  CVar->render_inputs(variables => $params{CUSTOM_VARIABLES}) if @{ $params{CUSTOM_VARIABLES} };

  $self->render(
    'part/form',
    title                   => t8('Edit ' . ucfirst($self->part->part_type)),
    show_edit_buttons       => $::auth->assert('part_service_assembly_edit'),
    assortment_html         => $assortment_html,
    assembly_html           => $assembly_html,
    assembly_sum            => $assembly_sum,
    assembly_sum_lastcost   => $assembly_sum_lastcost,
    assembly_sum_diff       => $assembly_sum_diff,
    assortment_sum          => $assortment_sum,
    assortment_sum_lastcost => $assortment_sum_lastcost,
    assortment_sum_diff     => $assortment_sum_diff,
    translations_map        => { map { ($_->language_id => $_) } @{$self->part->translations} },
# TODO: prices_map
    %params,
  );
}

sub action_assortment_update {
  my ($self) = @_;

  # if we pass part_type here we don't need to pass value of part_type to form
  my $assortment_sum          = $self->_recalc_total_sum(part_type => 'assortment');
  my $assortment_sum_lastcost = $self->_recalc_total_sum(part_type => 'assortment', price_type => 'lastcost');
  my $assortment_sum_diff     = $assortment_sum-$assortment_sum_lastcost;

  $self->js
    ->html('#assortment_sum',          $::form->format_amount(\%::myconfig, $assortment_sum,          2, 0))
    ->html('#assortment_sum_lastcost', $::form->format_amount(\%::myconfig, $assortment_sum_lastcost, 2, 0))
    ->html('#assortment_sum_diff',     $::form->format_amount(\%::myconfig, $assortment_sum_diff,     2, 0))
    ->render();

};

sub action_assembly_update {
  my ($self) = @_;

  # assembly_update only has access to the data in form, which consists of all
  # the inputs in #assemblies

  my $assembly_sum          = $self->_recalc_total_sum(part_type => 'assembly');
  my $assembly_sum_lastcost = $self->_recalc_total_sum(part_type => 'assembly', price_type => 'lastcost');
  my $assembly_sum_diff     = $assembly_sum - $assembly_sum_lastcost;

  $self->js
    ->html('#assembly_sum',          $::form->format_amount(\%::myconfig, $assembly_sum,          2, 0))
    ->html('#assembly_sum_lastcost', $::form->format_amount(\%::myconfig, $assembly_sum_lastcost, 2, 0))
    ->html('#assembly_sum_diff',     $::form->format_amount(\%::myconfig, $assembly_sum_diff,     2, 0))
    ->render;
};

# add an item row for a new item entered in the input row
sub action_add_assortment_item {
  my ($self) = @_;
  # pass everything via form, including all assortment_items in form

  unless ( $::form->{add_assortment_item} > 0 ) {
    return $self->js->flash('error', t8("No part was selected."))->render;
  };

  if ( $::form->{add_assortment_item} && grep { $::form->{add_assortment_item} == $_->parts_id } @{ $self->assortment_items } ) {
    return $self->js->flash('error', t8("This part has already been added."))->render;
  };
  # assortment_items have been deleted from form and are now in $self->assortment_items

  my $part = SL::DB::Manager::Part->find_by(id => $::form->{add_assortment_item}) || die "Can't load part";

  my $position = scalar @{$self->assortment_items} + 1;

  my $ai = SL::DB::AssortmentItem->new(part          => $part,
                                       # assortment_id => $self->assortment->id, # will be set on save
                                       qty           => $::form->parse_amount(\%::myconfig, $::form->{add_assortment_item_qty}) || 1,
                                       unit          => $::form->{add_assortment_item_unit} || $part->unit,
                                       position      => $position,
                                      );
  carp unless $ai;

  my $rows = scalar @{ $self->assortment_items };
  my $row_as_html = $self->p->render('part/_assortment_row',
                                     ASSORTMENT_ITEM => $ai,
                                     listrow         => $rows % 2 ? 1 : 0,
  );

  # we have already fetched all existing assortment items from form, so we
  # might as well calculate new sum now and update it directly
  my $assortment_sum          = $self->_recalc_total_sum(part_type => 'assortment') + $ai->linetotal;
  my $assortment_sum_lastcost = $self->_recalc_total_sum(part_type => 'assortment', price_type => 'lastcost') + $ai->linetotal_lastcost;
  my $assortment_sum_diff     = $assortment_sum-$assortment_sum_lastcost;

  $self->js
    ->append('#assortment_rows'        , $row_as_html)  # append in tbody
    ->html('#assortment_sum'           , $::form->format_amount(\%::myconfig , $assortment_sum          , 2 , 0))
    ->html('#assortment_sum_lastcost'  , $::form->format_amount(\%::myconfig , $assortment_sum_lastcost , 2 , 0))
    ->html('#assortment_sum_diff'      , $::form->format_amount(\%::myconfig , $assortment_sum_diff     , 2 , 0))
    ->val('.add_assortment_item_input' , '')
    ->run('kivi.Part.focus_last_assortment_input')
    ->render;
}

sub action_add_assembly_item {
  my ($self) = @_;
  # pass everything via form, including all assembly_items in form

  unless ( $::form->{add_assembly_item} > 0 ) {
    return $self->js->flash('error', t8("No part was selected."))->render;
  };

  my $duplicate_warning = 0; # duplicates are allowed, just warn
  if ( $::form->{add_assembly_item} && grep { $::form->{add_assembly_item} == $_->parts_id } @{ $self->assembly_items } ) {
    $duplicate_warning++;
  };

  my $part = SL::DB::Manager::Part->find_by(id => $::form->{add_assembly_item}) || die "Can't load part";

  my $position = scalar @{$self->assortment_items} + 1;

  my $ai = SL::DB::Assembly->new(parts_id    => $part->id,
                                 # id          => $self->assembly->id, # will be set on save
                                 qty         => $::form->parse_amount(\%::myconfig, $::form->{add_assembly_item_qty}) || 1,
                                 bom         => 0, # default when adding: no bom
                                 position    => $position,
                                );
  carp unless $ai;

  my $rows = scalar @{ $self->assembly_items };
  my $row_as_html = $self->p->render('part/_assembly_row',
                                     ASSEMBLY_ITEM => $ai,
                                     listrow       => $rows % 2 ? 1 : 0,
  );
  $main::lxdebug->message(0, "$row_as_html");


  my $assembly_sum          = $self->_recalc_total_sum(part_type => 'assembly') + $ai->linetotal;
  my $assembly_sum_lastcost = $self->_recalc_total_sum(part_type => 'assembly', price_type => 'lastcost') + $ai->linetotal_lastcost;
  my $assembly_sum_diff     = $assembly_sum-$assembly_sum_lastcost;

  $self->js->flash('info', t8("This part has already been added.")) if $duplicate_warning;

  $main::lxdebug->message(0, "returning");

  $self->js
    ->append('#assembly_rows', $row_as_html)  # append in tbody
    ->run('kivi.Part.focus_last_assembly_input')
    ->html('#assembly_sum', $::form->format_amount(\%::myconfig, $assembly_sum, 2, 0))
    ->html('#assembly_sum_lastcost', $::form->format_amount(\%::myconfig, $assembly_sum_lastcost, 2, 0))
    ->html('#assembly_sum_diff', $::form->format_amount(\%::myconfig, $assembly_sum_diff, 2, 0))
    ->val('.add_assembly_item_input', '')
    ->render;
}

sub action_add_makemodel_row {
  my ($self) = @_;

  unless ( $::form->{add_makemodel} > 0 ) {
    return $self->js->flash('error', t8("No vendor selected!"))->render;
  };

  my $vendor = SL::DB::Manager::Vendor->find_by(id => $::form->{add_makemodel}) || die "Can't load vendor";
  $main::lxdebug->message(0, "found vendor : " . $vendor->displayable_name);


  my $position = scalar @{$self->makemodels} + 1;

  my $mm = SL::DB::MakeModel->new(parts_id    => $::form->{part}->{id},
                                  make        => $vendor->id,
                                  model       => '',
                                  lastcost    => 0,
                                  sortorder    => $position,
                                 );

  die unless $mm;
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

sub action_reorder_assortment_items {
  my ($self) = @_;

  my %sort_keys = (
    partnumber  => sub { $_[0]->part->partnumber },
    description => sub { $_[0]->part->description },
    qty         => sub { $_[0]->qty },
    sellprice   => sub { $_[0]->part->sellprice },
    lastcost    => sub { $_[0]->part->lastcost },
    partsgroup  => sub { $_[0]->part->partsgroup_id ? $_[0]->part->partsgroup->partsgroup : '' },
  );

  my $method = $sort_keys{$::form->{order_by}};
  my @to_sort = map { { old_pos => $_->position, order_by => $method->($_) } } @{ $self->assortment_items };
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
  $self->js
    ->run('kivi.Part.redisplay_assortment_items', \@to_sort)
    ->render;
}

sub action_reorder_assembly_items {
  my ($self) = @_;

  my %sort_keys = (
    partnumber  => sub { $_[0]->part->partnumber },
    description => sub { $_[0]->part->description },
    qty         => sub { $_[0]->qty },
    sellprice   => sub { $_[0]->part->sellprice },
    lastcost    => sub { $_[0]->part->lastcost },
    partsgroup  => sub { $_[0]->part->partsgroup_id ? $_[0]->part->partsgroup->partsgroup : '' },
  );

  my $method = $sort_keys{$::form->{order_by}};
  my @to_sort = map { { old_pos => $_->position, order_by => $method->($_) } } @{ $self->assembly_items };
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
  $self->js
    ->run('kivi.Part.redisplay_assembly_items', \@to_sort)
    ->render;
}

sub action_warehouse_changed {
  my ($self) = @_;

  $self->warehouse(SL::DB::Manager::Warehouse->find_by_or_create(id => $::form->{warehouse_id}));
  die unless ref($self->warehouse) eq 'SL::DB::Warehouse';

  if ( $self->warehouse->id and @{$self->warehouse->bins} ) {
    $self->bin($self->warehouse->bins->[0]);
    $self->js
      ->html('#bin', $self->build_bin_select)
      ->focus('#part_bin_id');
  } else {
    $main::lxdebug->message(0, "setting bin empty");
    # no warehouse was selected, empty the bin field and reset the id
    $self->js
        ->val('#part_bin_id', undef)
        ->html('#bin', '');
  };

  return $self->js->render;
}

sub action_ajax_autocomplete {
  my ($self, %params) = @_;

  # if someone types something, and hits enter, assume he entered the full name.
  # if something matches, treat that as sole match
  # unfortunately get_models can't do more than one per package atm, so we d it
  # the oldfashioned way.
  if ($::form->{prefer_exact}) {
    my $exact_matches;
    if (1 == scalar @{ $exact_matches = SL::DB::Manager::Part->get_all(
      query => [
        obsolete => 0,
        SL::DB::Manager::Part->type_filter($::form->{filter}{part_type}),
        or => [
          description => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
          partnumber  => { ilike => $::form->{filter}{'all:substr:multi::ilike'} },
        ]
      ],
      limit => 2,
    ) }) {
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
  $_[0]->render('part/part_picker_search', { layout => 0 }, parts => $_[0]->parts);
}

sub action_part_picker_result {
  $_[0]->render('part/_part_picker_result', { layout => 0 });
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

# helper functions

sub _pre_render {
  my ($self) = @_;
  $self->{LANGUAGES}       = SL::DB::Manager::Language->get_all_sorted;
  $self->{PARTSGROUPS}     = SL::DB::Manager::PartsGroup->get_all_sorted;
  $self->{BUCHUNGSGRUPPEN} = SL::DB::Manager::Buchungsgruppe->get_all_sorted;
  $self->{UNITS}           = SL::DB::Manager::Unit->get_all_sorted;
  $self->{PAYMENT_TERMS}   = SL::DB::Manager::PaymentTerm->get_all_sorted;
  $self->{PRICE_FACTORS}   = SL::DB::Manager::PriceFactor->get_all_sorted;
  $self->{WAREHOUSES}      = $self->warehouses;

  $self->{PRICEGROUPS}     = SL::DB::Manager::Pricegroup->get_all_sorted;
  # pricegroups are different, because prices are only stored for parts that have a non-zero price
  # in the old code there was a coalesce 0 for prices that were missing
  # translations uses a map for this
  foreach my $pg ( @{$self->{PRICEGROUPS}} ) {
    # fake the coalesce 0 by adding price to pricegroup array
    # and iterating over Pricegroup rather than Price in template pricegroup_prices.html
    my ($price) = grep { $pg->id == $_->pricegroup_id } $self->part->prices;
    if ( $price ) {
      $pg->{price}    = $::form->format_amount(\%::myconfig, $price->price, 2, 0);
      $pg->{price_id} = $price->id;
    } else {
      $pg->{price}    = $::form->format_amount(\%::myconfig, 0, 2, 0);
0;
    };
  };

  $::request->layout->use_javascript("${_}.js")  for qw(kivi.Part kivi.PriceRule ckeditor/ckeditor ckeditor/adapters/jquery);
  # $::request->layout->add_javascripts_inline("\$(function(){kivi.PriceRule.load_price_rules_for_part(@{[ $self->part->id ]})});") if $self->part->id;
};


sub _recalc_total_sum {
  my ($self, %params) = @_;

  # params:
  # part_type : 'assortment' or 'assembly'
  # price_type: 'lastcost', default is 'sellprice'

  # parse form and calculate sum of all sellprices
  # when calling _recalc_total_sum directly via assembly_recalc, only #assembly is serialized
  # use params so we can also use this function when data comes from form

  carp "can only calculate sum for assortments and assemblies" unless $params{type} =~ /^(assortment|assembly)$/;

  $main::lxdebug->message(0, "calc");

  if ( $params{part_type} eq 'assortment' ) {
    if ( $params{price_type} eq 'lastcost' ) {
      return sum map { $_->linetotal_lastcost } @{$self->assortment_items};
    } else {
      return sum map { $_->linetotal } @{$self->assortment_items};
    };
  } elsif ( $params{part_type} eq 'assembly' ) {
    if ( $params{price_type} eq 'lastcost' ) {
      return sum map { $_->linetotal_lastcost } @{$self->assembly_items};
    } else {
      return sum map { $_->linetotal } @{$self->assembly_items};
    };
  };
};

sub _instantiate_args {
  my ($self) = @_;

  if ( $::form->{part}->{id} ) {
    $self->part(SL::DB::Part->new(id => $::form->{id})->load(with => [ qw(makemodels prices translations partsgroup) ])); # or die "Can't load part";
  } else {
    my $params = { part_type        => $::form->{part_type},
                   makemodels       => [],
                   assemblies       => [],
                   assortment_items => [],
                   translations     => [],
                 };  # is only set via get for new parts

    $self->part(SL::DB::Part->new->assign_attributes( %{ $params }));
  };

  if ( $::form->{last_modification} ) {
    unless ($self->part->last_modification eq  $::form->{last_modification} ) {
      # $main::lxdebug->message(0, "mtimes don't match: part = " .  $self->part->last_modification . "   form = " . $::form->{last_modification});
      die t8("The document has been changed by another user. Please reopen it in another window and copy the changes to the new window");
    };
  };

  # do any other params need to filtered here? e.g. mtime, itime
  # anything that shouldn't be overwritten shouldn't appear as an input in form

  my $params = delete($::form->{part}) || { };

  delete $params->{id};
  delete $params->{partnumber} if $self->part->partnumber; # never overwrite existing partnumber
  $self->part->assign_attributes(%{ $params});
  $self->part->bin_id(undef) unless $self->part->warehouse_id;
};

sub build_bin_select {
  $_[0]->p->select_tag('part.bin_id', [ $_[0]->warehouse->bins ],
    title_key => 'description',
    default   => $_[0]->bin->id,
  );
}

# get_set_inits

sub init_parts {
  if ($::form->{no_paginate}) {
    $_[0]->models->disable_plugin('paginated');
  }

  $_[0]->models->get;
}

sub init_part {
  # edit: part id comes from $::form->{id}
  # save: part id comes from $::form->{part}{id}
  SL::DB::Manager::Part->find_by_or_create(id => $::form->{id} || $::form->{part}->{id} );
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
    with_objects => [ qw(unit_obj) ],
  );
}

sub init_p {
  SL::Presenter->get;
}

sub init_prices {
  # parse prices in $::form when saving part

  my ($self) = @_;
  my @array;

  my $prices = delete($::form->{prices}) || [];

  foreach my $price ( @{$prices} ) {
    my $sellprice = $::form->parse_amount(\%::myconfig, $price->{price});
    next unless $sellprice > 0; # skip negative prices as well
    my $p = SL::DB::Price->new(parts_id      => $self->part->id,
                               pricegroup_id => $price->{pricegroup_id},
                               price         => $sellprice,
                              );
    push(@array, $p);
  };
  return \@array;
};

sub init_makemodels {
  # parse makemodels in $::form when saving part

  my ($self) = @_;
  my $position = 0;
  my @makemodel_array = ();
  my $makemodels = delete($::form->{makemodels}) || [];

  foreach my $makemodel ( @{$makemodels} ) {
    next unless $makemodel->{make};
    $position++;
    my $vendor = SL::DB::Manager::Vendor->find_by(id => $makemodel->{make}) || die "Can't find vendor from make";

    my $mm = SL::DB::MakeModel->new( # parts_id   => $self->part->id, # will be assigned by row add_makemodels
                                     make       => $vendor->id, # $makemodel->make
                                     model      => $makemodel->{model} || '',
                                     lastcost   => $::form->parse_amount(\%::myconfig, $makemodel->{lastcost_as_number}),
                                     sortorder  => $position,
                                   );
    push(@makemodel_array, $mm);
  };
  return \@makemodel_array;
};

sub init_translations {
  my ($self) = @_;
  my $position = 0;
  my @translation_array;
  my $translations = delete($::form->{translations}) || [];
  foreach my $translation ( @{$translations} ) {
    $position++;
    my $t = SL::DB::Translation->new( %{$translation} );
    carp "can't create translation" unless $t;
    push(@translation_array, $t);
  };
  return \@translation_array;
};

sub init_assortment_items {
  my ($self) = @_;
  my $position = 0;
  my @array;
  # my $assortment = $self->part;
  my $assortment_items = delete($::form->{assortment_items}) || [];
  foreach my $assortment_item ( @{$assortment_items} ) {
    next unless $assortment_item->{parts_id};
    $position++;
    my $part = SL::DB::Manager::Part->find_by(id => $assortment_item->{parts_id}) || die "Can't determine item to be added";
    my $ai = SL::DB::AssortmentItem->new( parts_id      => $part->id,
                                          # assortment_id => $assortment->id, # not needed when we use add_assortment_items
                                          qty           => $::form->parse_amount(\%::myconfig, $assortment_item->{qty_as_number}),
                                          unit          => $assortment_item->{unit} || $part->unit,
                                          position      => $position,
    );

    push(@array, $ai);
  };
  return \@array;
};


sub init_assembly_items {
  my ($self) = @_;
  my $position = 0;
  my @array;
  my $assembly = $self->part;
  my $assembly_items = delete($::form->{assembly_items}) || [];
  foreach my $assembly_item ( @{$assembly_items} ) {
    next unless $assembly_item->{parts_id};
    $position++;
    my $part = SL::DB::Manager::Part->find_by(id => $assembly_item->{parts_id}) || die "Can't determine item to be added";
    my $ai = SL::DB::Assembly->new(parts_id    => $part->id,
                                   bom         => $assembly_item->{bom},
                                   id          => $assembly->id,  # grrrr, assembly_id is the serial primary key, not id
                                   qty         => $::form->parse_amount(\%::myconfig, $assembly_item->{qty_as_number}),
                                   position    => $position,
                                  );
    push(@array, $ai);
  };
  return \@array;
};

sub init_warehouses {
  my ($self) = @_;

  SL::DB::Manager::Warehouse->get_all(query => [ or => [ invalid => 0, invalid => undef ]]);
}

1;
