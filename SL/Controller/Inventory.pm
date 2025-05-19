package SL::Controller::Inventory;

use strict;
use warnings;
use POSIX qw(strftime);

use parent qw(SL::Controller::Base);

use SL::DB::Inventory;
use SL::DB::Stocktaking;
use SL::DB::Part;
use SL::DB::Warehouse;
use SL::DB::Unit;
use SL::DB::Default;
use SL::WH;
use SL::ReportGenerator;
use SL::Locale::String qw(t8);
use SL::Presenter::Tag qw(select_tag);
use SL::DBUtils;
use SL::Helper::Flash;
use SL::Controller::Helper::ReportGenerator;
use SL::Controller::Helper::GetModels;
use List::MoreUtils qw(uniq);

use English qw(-no_match_vars);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(warehouses units is_stocktaking stocktaking_models stocktaking_cutoff_date) ],
  'scalar'                => [ qw(warehouse bin unit part) ],
);

__PACKAGE__->run_before('_check_auth');
__PACKAGE__->run_before('_check_warehouses');
__PACKAGE__->run_before('load_part_from_form',   only => [ qw(stock_in part_changed mini_stock stock stocktaking_part_changed stocktaking_get_warn_qty_threshold save_stocktaking) ]);
__PACKAGE__->run_before('load_unit_from_form',   only => [ qw(stock_in part_changed mini_stock stock stocktaking_part_changed stocktaking_get_warn_qty_threshold save_stocktaking) ]);
__PACKAGE__->run_before('load_wh_from_form',     only => [ qw(stock_in warehouse_changed stock stocktaking stocktaking_get_warn_qty_threshold save_stocktaking) ]);
__PACKAGE__->run_before('load_bin_from_form',    only => [ qw(stock_in stock stocktaking stocktaking_get_warn_qty_threshold save_stocktaking) ]);
__PACKAGE__->run_before('set_target_from_part',  only => [ qw(part_changed) ]);
__PACKAGE__->run_before('mini_stock',            only => [ qw(stock_in mini_stock) ]);
__PACKAGE__->run_before('sanitize_target',       only => [ qw(stock_usage stock_in warehouse_changed part_changed stocktaking stocktaking_part_changed stocktaking_get_warn_qty_threshold save_stocktaking) ]);
__PACKAGE__->run_before('set_layout');

sub action_stock_in {
  my ($self) = @_;

  $::form->{title}   = t8('Stock');

  # Sometimes we want to open stock_in with a part already selected, but only
  # the parts_id is passed in the url (and not also warehouse, bin and unit).
  # Setting select_default_bin in the form will make sure the default warehouse
  # and bin of that part will already be preselected, as normally
  # set_target_from_part is only called when a part is changed.
  $self->set_target_from_part if $::form->{select_default_bin};
  $::request->layout->focus('#part_id_name');
  my $transfer_types = WH->retrieve_transfer_types('in');
  map { $_->{description} = $main::locale->text($_->{description}) } @{ $transfer_types };
  $self->setup_stock_in_action_bar;
  $self->render('inventory/warehouse_selection_stock', title => $::form->{title}, TRANSFER_TYPES => $transfer_types );
}

sub action_stock_usage {
  my ($self) = @_;

  $::form->{title}   = t8('UsageE');

  $::form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                       'bins'   => 'BINS', });

  $self->setup_stock_usage_action_bar;
  $self->render('inventory/warehouse_usage',
                title => $::form->{title},
                year => DateTime->today->year,
                WAREHOUSES => $::form->{WAREHOUSES},
                WAREHOUSE_FILTER => 1,
                warehouse_id => 0,
                bin_id => 0
      );

}

sub getnumcolumns {
  my ($self) = @_;
  return qw(stock incorrection found insum back outcorrection disposed
                     missing shipped used outsum consumed averconsumed);
}

sub action_usage {
  my ($self) = @_;

  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{title}   = t8('UsageE');
  $form->{report_generator_output_format} = 'HTML' if !$form->{report_generator_output_format};

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @columns = qw(partnumber partdescription);

  push @columns , qw(ptype unit) if $form->{report_generator_output_format} eq 'HTML';

  my @numcolumns = qw(stock incorrection found insum back outcorrection disposed
                     missing shipped used outsum consumed averconsumed);

  push @columns , $self->getnumcolumns();

  my @hidden_variables = qw(reporttype year duetyp fromdate todate
                            warehouse_id bin_id partnumber description bestbefore chargenumber partstypes_id);
  my %column_defs = (
    'partnumber'      => { 'text' => $locale->text('Part Number'), },
    'partdescription' => { 'text' => $locale->text('Part_br_Description'), },
    'unit'            => { 'text' => $locale->text('Unit'), },
    'stock'           => { 'text' => $locale->text('stock_br'), },
    'incorrection'    => { 'text' => $locale->text('correction_br'), },
    'found'           => { 'text' => $locale->text('found_br'), },
    'insum'           => { 'text' => $locale->text('sum'), },
    'back'            => { 'text' => $locale->text('back_br'), },
    'outcorrection'   => { 'text' => $locale->text('correction_br'), },
    'disposed'        => { 'text' => $locale->text('disposed_br'), },
    'missing'         => { 'text' => $locale->text('missing_br'), },
    'shipped'         => { 'text' => $locale->text('shipped_br'), },
    'used'            => { 'text' => $locale->text('used_br'), },
    'outsum'          => { 'text' => $locale->text('sum'), },
    'consumed'        => { 'text' => $locale->text('consumed'), },
    'averconsumed'    => { 'text' => $locale->text('averconsumed_br'), },
  );


  map { $column_defs{$_}->{visible} = 1 } @columns;
  #map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;
  map { $column_defs{$_}->{align} = 'right' } @numcolumns;

  my @custom_headers = ();
  # Zeile 1:
  push @custom_headers, [
      { 'text' => $locale->text('Part'),
        'colspan' => ($form->{report_generator_output_format} eq 'HTML'?4:2), 'align' => 'center'},
      { 'text' => $locale->text('Into bin'), 'colspan' => 4, 'align' => 'center'},
      { 'text' => $locale->text('From bin'), 'colspan' => 7, 'align' => 'center'},
      { 'text' => $locale->text('UsageWithout'),    'colspan' => 2, 'align' => 'center'},
  ];

  # Zeile 2:
  my @line_2 = ();
  map { push @line_2 , $column_defs{$_} } @columns;
  push @custom_headers, [ @line_2 ];

  $report->set_custom_headers(@custom_headers);
  $report->set_columns( %column_defs );
  $report->set_column_order(@columns);

  $report->set_export_options('usage', @hidden_variables );

  $report->set_sort_indicator($form->{sort}, $form->{order});
  $report->set_options('output_format'        => 'HTML',
                       'controller_class'     => 'Inventory',
                       'title'                => $form->{title},
#                      'html_template'        => 'inventory/usage_report',
                       'attachment_basename'  => strftime($locale->text('warehouse_usage_list') . '_%Y%m%d', localtime time));
  $report->set_options_from_form;

  my %searchparams ;
# form vars
#   reporttype = custom
#   year = 2014
#   duetyp = 7

  my $start       = DateTime->now_local;
  my $end         = DateTime->now_local;
  my $actualepoch = $end->epoch();
  my $days = 365;
  my $mdays=30;
  $searchparams{reporttype} = $form->{reporttype};
  if ($form->{reporttype} eq "custom") {
    my $smon = 1;
    my $emon = 12;
    my $sday = 1;
    my $eday = 31;
    #forgotten the year --> thisyear
    if ($form->{year} !~ m/^\d\d\d\d$/) {
      $locale->date(\%myconfig, $form->current_date(\%myconfig), 0) =~
        /(\d\d\d\d)/;
      $form->{year} = $1;
    }
    my $leapday = ($form->{year} % 4 == 0) ? 1:0;
    #yearly report
    if ($form->{duetyp} eq "13") {
        $days += $leapday;
    }

    #Quater reports
    if ($form->{duetyp} eq "A") {
      $emon = 3;
      $days = 90 + $leapday;
    }
    if ($form->{duetyp} eq "B") {
      $smon = 4;
      $emon = 6;
      $eday = 30;
      $days = 91;
    }
    if ($form->{duetyp} eq "C") {
      $smon = 7;
      $emon = 9;
      $eday = 30;
      $days = 92;
    }
    if ($form->{duetyp} eq "D") {
      $smon = 10;
      $days = 92;
    }
    #Monthly reports
    if ($form->{duetyp} eq "1" || $form->{duetyp} eq "3" || $form->{duetyp} eq "5" ||
        $form->{duetyp} eq "7" || $form->{duetyp} eq "8" || $form->{duetyp} eq "10" ||
        $form->{duetyp} eq "12") {
        $smon = $emon = $form->{duetyp}*1;
        $mdays=$days = 31;
    }
    if ($form->{duetyp} eq "2" || $form->{duetyp} eq "4" || $form->{duetyp} eq "6" ||
        $form->{duetyp} eq "9" || $form->{duetyp} eq "11" ) {
        $smon = $emon = $form->{duetyp}*1;
        $eday = 30;
        if ($form->{duetyp} eq "2" ) {
            #this works from 1901 to 2099, 1900 and 2100 fail.
            $eday = ($form->{year} % 4 == 0) ? 29 : 28;
        }
        $mdays=$days = $eday;
    }
    $searchparams{year} = $form->{year};
    $searchparams{duetyp} = $form->{duetyp};
    $start->set_month($smon);
    $start->set_day($sday);
    $start->set_year($form->{year}*1);
    $end->set_month($emon);
    $end->set_day($eday);
    $end->set_year($form->{year}*1);
  }  else {
    $searchparams{fromdate} = $form->{fromdate};
    $searchparams{todate} = $form->{todate};
#   reporttype = free
#   fromdate = 01.01.2014
#   todate = 31.05.2014
    my ($yy, $mm, $dd) = $locale->parse_date(\%myconfig,$form->{fromdate});
    $start->set_year($yy);
    $start->set_month($mm);
    $start->set_day($dd);
    ($yy, $mm, $dd) = $locale->parse_date(\%myconfig,$form->{todate});
    $end->set_year($yy);
    $end->set_month($mm);
    $end->set_day($dd);
    my $dur = $start->delta_md($end);
    $days = $dur->delta_months()*30 + $dur->delta_days() ;
  }
  $start->set_second(0);
  $start->set_minute(0);
  $start->set_hour(0);
  $end->set_second(59);
  $end->set_minute(59);
  $end->set_hour(23);
  if ( $end->epoch() > $actualepoch ) {
      $end = DateTime->now_local;
      my $dur = $start->delta_md($end);
      $days = $dur->delta_months()*30 + $dur->delta_days() ;
  }
  if ( $start->epoch() > $end->epoch() ) { $start = $end;$days = 1;}
  $days = $mdays if $days < $mdays;
  #$main::lxdebug->message(LXDebug->DEBUG2(), "start=".$start->epoch());
  #$main::lxdebug->message(LXDebug->DEBUG2(), "  end=".$end->epoch());
  #$main::lxdebug->message(LXDebug->DEBUG2(), " days=".$days);
  my @andfilter = (shippingdate => { ge => $start }, shippingdate => { le => $end } );
  if ( $form->{warehouse_id} ) {
      push @andfilter , ( warehouse_id => $form->{warehouse_id});
      $searchparams{warehouse_id} = $form->{warehouse_id};
      if ( $form->{bin_id} ) {
          push @andfilter , ( bin_id => $form->{bin_id});
          $searchparams{bin_id} = $form->{bin_id};
      }
  }
  # alias class t2 entspricht parts
  if ( $form->{partnumber} ) {
      push @andfilter , ( 't2.partnumber' => { ilike => '%'. $form->{partnumber} .'%' });
      $searchparams{partnumber} = $form->{partnumber};
  }
  if ( $form->{description} ) {
      push @andfilter , ( 't2.description' => { ilike => '%'. $form->{description} .'%'  });
      $searchparams{description} = $form->{description};
  }
  if ( $form->{bestbefore} ) {
    push @andfilter , ( bestbefore => { eq => $form->{bestbefore} });
      $searchparams{bestbefore} = $form->{bestbefore};
  }
  if ( $form->{chargenumber} ) {
      push @andfilter , ( chargenumber => { ilike => '%'.$form->{chargenumber}.'%' });
      $searchparams{chargenumber} = $form->{chargenumber};
  }
  if ( $form->{partstypes_id} ) {
      push @andfilter , ( 't2.partstypes_id' => $form->{partstypes_id} );
      $searchparams{partstypes_id} = $form->{partstypes_id};
  }

  my @filter = (and => [ @andfilter ] );

  my $objs = SL::DB::Manager::Inventory->get_all(with_objects => ['parts'], where => [ @filter ] , sort_by => 'parts.partnumber ASC');
  #my $objs = SL::DB::Inventory->_get_manager_class->get_all(...);

  # manual paginating, yuck
  my $page = $::form->{page} || 1;
  my $pages = {};
  $pages->{per_page}        = $::form->{per_page} || 20;
  my $first_nr = ($page - 1) * $pages->{per_page};
  my $last_nr  = $first_nr + $pages->{per_page};

  my $last_partid = 0;
  my $last_row = { };
  my $row_ind = 0;
  my $allrows = 0;
  $allrows = 1 if $form->{report_generator_output_format} ne 'HTML' ;
  #$main::lxdebug->message(LXDebug->DEBUG2(), "first_nr=".$first_nr." last_nr=".$last_nr);
  foreach my $entry (@{ $objs } ) {
      if ( $entry->parts_id != $last_partid ) {
          if ( $last_partid > 0 ) {
              if ( $allrows || ($row_ind >= $first_nr && $row_ind < $last_nr )) {
                  $self->make_row_result($last_row,$days,$last_partid);
                  $report->add_data($last_row);
              }
              $row_ind++ ;
          }
          $last_partid = $entry->parts_id;
          $last_row = { };
          $last_row->{partnumber}->{data} = $entry->part->partnumber;
          $last_row->{partdescription}->{data} = $entry->part->description;
          $last_row->{unit}->{data} = $entry->part->unit;
          $last_row->{stock}->{data} = 0;
          $last_row->{incorrection}->{data} = 0;
          $last_row->{found}->{data} = 0;
          $last_row->{back}->{data} = 0;
          $last_row->{outcorrection}->{data} = 0;
          $last_row->{disposed}->{data} = 0;
          $last_row->{missing}->{data} = 0;
          $last_row->{shipped}->{data} = 0;
          $last_row->{used}->{data} = 0;
          $last_row->{insum}->{data} = 0;
          $last_row->{outsum}->{data} = 0;
          $last_row->{consumed}->{data} = 0;
          $last_row->{averconsumed}->{data} = 0;
      }
      if ( !$allrows && $row_ind >= $last_nr ) {
          next;
      }
      my $prefix='';
      if ( $entry->trans_type->description eq 'correction' ) {
          $prefix = $entry->trans_type->direction;
      }
      $last_row->{$prefix.$entry->trans_type->description}->{data} +=
          ( $entry->trans_type->direction eq 'out' ? -$entry->qty : $entry->qty );
  }
  if ( $last_partid > 0 && ( $allrows || ($row_ind >= $first_nr && $row_ind < $last_nr ))) {
      $self->make_row_result($last_row,$days,$last_partid);
      $report->add_data($last_row);
      $row_ind++ ;
  }
  my $num_rows = @{ $report->{data} } ;
  #$main::lxdebug->message(LXDebug->DEBUG2(), "count=".$row_ind." rows=".$num_rows);

  if ( ! $allrows ) {
      $pages->{max}  = SL::DB::Helper::Paginated::ceil($row_ind, $pages->{per_page}) || 1;
      $pages->{page} = $page < 1 ? 1: $page > $pages->{max} ? $pages->{max}: $page;
      $pages->{common} = [ grep { $_->{visible} } @{ SL::DB::Helper::Paginated::make_common_pages($pages->{page}, $pages->{max}) } ];
      $self->{pages} = $pages;
      $searchparams{action} = "usage";
      $self->{base_url} = $self->url_for(\%searchparams );
      #$main::lxdebug->message(LXDebug->DEBUG2(), "page=".$pages->{page}." url=".$self->{base_url});

      $report->set_options('raw_bottom_info_text' => $self->render('inventory/report_bottom', { output => 0 }) );
  }
  $report->generate_with_headers();

  $main::lxdebug->leave_sub();

}

sub make_row_result {
  my ($self,$row,$days,$partid) = @_;
  my $form     = $main::form;
  my $myconfig = \%main::myconfig;

  $row->{insum}->{data}  = $row->{stock}->{data} + $row->{incorrection}->{data} + $row->{found}->{data};
  $row->{outsum}->{data} = $row->{back}->{data} + $row->{outcorrection}->{data} + $row->{disposed}->{data} +
       $row->{missing}->{data} + $row->{shipped}->{data} + $row->{used}->{data};
  $row->{consumed}->{data} = $row->{outsum}->{data} -
       $row->{outcorrection}->{data} - $row->{incorrection}->{data};
  $row->{averconsumed}->{data} = $row->{consumed}->{data}*30/$days ;
  map { $row->{$_}->{data} = $form->format_amount($myconfig,$row->{$_}->{data},2); } $self->getnumcolumns();
  $row->{partnumber}->{link} = 'controller.pl?action=Part/edit&part.id=' . $partid;
}

sub action_stock {
  my ($self) = @_;

  my $transfer_error;
  my $qty = $::form->parse_amount(\%::myconfig, $::form->{qty});
  if (!$qty) {
    $transfer_error = t8('Cannot stock without amount');
  } elsif ($qty < 0) {
    $transfer_error = t8('Cannot stock negative amounts');
  } else {
    # do stock
    $::form->throw_on_error(sub {
      eval {
        WH->transfer({
          parts         => $self->part,
          dst_bin       => $self->bin,
          dst_wh        => $self->warehouse,
          qty           => $qty,
          unit          => $self->unit,
          transfer_type => 'stock',
          transfer_type_id => $::form->{transfer_type_id},
          chargenumber  => $::form->{chargenumber},
          bestbefore    => $::form->{bestbefore},
          comment       => $::form->{comment},
        });
        1;
      } or do { $transfer_error = $EVAL_ERROR->error; }
    });

    if (!$transfer_error) {
      if ($::form->{write_default_bin}) {
        $self->part->load;   # onhand is calculated in between. don't mess that up
        $self->part->bin($self->bin);
        $self->part->warehouse($self->warehouse);
        $self->part->save;
      }

      flash_later('info', t8('Transfer successful'));
    }
  }

  my %additional_redirect_params = ();
  if ($transfer_error) {
    flash_later('error', $transfer_error);
    $additional_redirect_params{$_}  = $::form->{$_} for qw(qty chargenumber bestbefore ean comment);
    $additional_redirect_params{qty} = $qty;
  }

  # redirect
  $self->redirect_to(
    action       => 'stock_in',
    part_id      => $self->part->id,
    bin_id       => $self->bin->id,
    warehouse_id => $self->warehouse->id,
    unit_id      => $self->unit->id,
    %additional_redirect_params,
  );
}

sub action_part_changed {
  my ($self) = @_;

  # no standard? ask user if he wants to write it
  if ($self->part->id && !$self->part->bin_id && !$self->part->warehouse_id) {
    $self->js->show('#write_default_bin_span');
  } else {
    $self->js->hide('#write_default_bin_span')
             ->removeAttr('#write_default_bin', 'checked');
  }

  $self->js
    ->replaceWith('#warehouse_id', $self->build_warehouse_select)
    ->replaceWith('#bin_id', $self->build_bin_select)
    ->replaceWith('#unit_id', $self->build_unit_select)
    ->focus('#warehouse_id')
    ->render;
}

sub action_warehouse_changed {
  my ($self) = @_;

  $self->js
    ->replaceWith('#bin_id', $self->build_bin_select)
    ->focus('#bin_id')
    ->render;
}

sub action_mini_stock {
  my ($self) = @_;

  $self->js
    ->html('#stock', $self->render('inventory/_stock', { output => 0 }))
    ->render;
}

sub action_stocktaking {
  my ($self) = @_;

  $::request->{layout}->use_javascript("${_}.js") for qw(kivi.Inventory);
  $::request->layout->focus('#part_id_name');
  $self->setup_stock_stocktaking_action_bar;
  $self->render('inventory/stocktaking/form', title => t8('Stocktaking'));
}

sub action_save_stocktaking {
  my ($self) = @_;

  return $self->js->flash('error', t8('Please choose a part.'))->render()
    if !$::form->{part_id};

  return $self->js->flash('error', t8('A target quantitiy has to be given'))->render()
    if $::form->{target_qty} eq '';

  my $target_qty = $::form->parse_amount(\%::myconfig, $::form->{target_qty});

  return $self->js->flash('error', t8('Error: A negative target quantity is not allowed.'))->render()
    if $target_qty < 0;

  my $stocked_qty  = _get_stocked_qty($self->part,
                                      warehouse_id => $self->warehouse->id,
                                      bin_id       => $self->bin->id,
                                      chargenumber => $::form->{chargenumber},
                                      bestbefore   => $::form->{bestbefore},);

  my $stocked_qty_in_form_units = $self->part->unit_obj->convert_to($stocked_qty, $self->unit);

  if (!$::form->{dont_check_already_counted}) {
    my $already_counted = _already_counted($self->part,
                                           warehouse_id => $self->warehouse->id,
                                           bin_id       => $self->bin->id,
                                           cutoff_date  => $::form->{cutoff_date_as_date},
                                           chargenumber => $::form->{chargenumber},
                                           bestbefore   => $::form->{bestbefore});
    if (scalar @$already_counted) {
      my $reply = $self->js->dialog->open({
        html   => $self->render('inventory/stocktaking/_already_counted_dialog',
                                { output => 0 },
                                already_counted           => $already_counted,
                                stocked_qty               => $stocked_qty,
                                stocked_qty_in_form_units => $stocked_qty_in_form_units),
        id     => 'already_counted_dialog',
        dialog => {
          title => t8('Already counted'),
        },
      })->render;

      return $reply;
    }
  }

  # - target_qty is in units given in form ($self->unit)
  # - WH->transfer expects qtys in given unit (here: unit from form (unit -> $self->unit))
  # Therefore use stocked_qty in form units for calculation.
  my $qty        = $target_qty - $stocked_qty_in_form_units;
  my $src_or_dst = $qty < 0? 'src' : 'dst';
  $qty           = abs($qty);

  my $transfer_error;
  # do stock
  $::form->throw_on_error(sub {
    eval {
      WH->transfer({
        parts                   => $self->part,
        $src_or_dst.'_bin'      => $self->bin,
        $src_or_dst.'_wh'       => $self->warehouse,
        qty                     => $qty,
        unit                    => $self->unit,
        transfer_type           => 'stocktaking',
        chargenumber            => $::form->{chargenumber},
        bestbefore              => $::form->{bestbefore},
        ean                     => $::form->{ean},
        comment                 => $::form->{comment},
        record_stocktaking      => 1,
        stocktaking_qty         => $target_qty,
        stocktaking_cutoff_date => $::form->{cutoff_date_as_date},
      });
      1;
    } or do { $transfer_error = ref($EVAL_ERROR) eq 'SL::X::FormError' ? $EVAL_ERROR->error : $EVAL_ERROR; }
  });

  return $self->js->flash('error', $transfer_error)->render()
    if $transfer_error;

  flash_later('info', $::locale->text('Part successful counted'));
  $self->redirect_to(action              => 'stocktaking',
                     warehouse_id        => $self->warehouse->id,
                     bin_id              => $self->bin->id,
                     cutoff_date_as_date => $self->stocktaking_cutoff_date->to_kivitendo);
}

sub action_reload_stocktaking_history {
  my ($self) = @_;

  $::form->{filter}{'cutoff_date:date'} = $self->stocktaking_cutoff_date->to_kivitendo;
  $::form->{filter}{'employee_id'}      = SL::DB::Manager::Employee->current->id;

  $self->prepare_stocktaking_report;
  $self->report_generator_list_objects(report => $self->{report}, objects => $self->stocktaking_models->get, layout => 0, header => 0);
}

sub action_stocktaking_part_changed {
  my ($self) = @_;

  $self->js
    ->replaceWith('#unit_id', $self->build_unit_select)
    ->focus('#target_qty')
    ->render;
}

sub action_stocktaking_journal {
  my ($self) = @_;

  $self->prepare_stocktaking_report(full => 1);
  $self->report_generator_list_objects(report => $self->{report}, objects => $self->stocktaking_models->get);
}

sub action_stocktaking_get_warn_qty_threshold {
  my ($self) = @_;

  return $_[0]->render(\ !!0, { type => 'text' }) if !$::form->{part_id};
  return $_[0]->render(\ !!0, { type => 'text' }) if $::form->{target_qty} eq '';
  return $_[0]->render(\ !!0, { type => 'text' }) if 0 == $::instance_conf->get_stocktaking_qty_threshold;

  my $target_qty  = $::form->parse_amount(\%::myconfig, $::form->{target_qty});
  my $stocked_qty = _get_stocked_qty($self->part,
                                     warehouse_id => $self->warehouse->id,
                                     bin_id       => $self->bin->id,
                                     chargenumber => $::form->{chargenumber},
                                     bestbefore   => $::form->{bestbefore},);
  my $stocked_qty_in_form_units = $self->part->unit_obj->convert_to($stocked_qty, $self->unit);
  my $qty        = $target_qty - $stocked_qty_in_form_units;
  $qty           = abs($qty);

  my $warn;
  if ($qty > $::instance_conf->get_stocktaking_qty_threshold) {
    $warn  = t8('The target quantity of #1 differs more than the threshold quantity of #2.',
                $::form->{target_qty} . " " . $self->unit->name,
                $::form->format_amount(\%::myconfig, $::instance_conf->get_stocktaking_qty_threshold, 2));
    $warn .= "\n";
    $warn .= t8('Choose "continue" if you want to use this value. Choose "cancel" otherwise.');
  }
  return $_[0]->render(\ $warn, { type => 'text' });
}

#================================================================

sub _check_auth {
  $main::auth->assert('warehouse_management');
}

sub _check_warehouses {
  $_[0]->show_no_warehouses_error if !@{ $_[0]->warehouses };
}

sub init_warehouses {
  SL::DB::Manager::Warehouse->get_all(query => [ or => [ invalid => 0, invalid => undef ]]);
}

#sub init_bins {
#  SL::DB::Manager::Bin->get_all();
#}

sub init_units {
  SL::DB::Manager::Unit->get_all;
}

sub init_is_stocktaking {
  return $_[0]->action_name =~ m{stocktaking};
}

sub init_stocktaking_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller   => $self,
    model        => 'Stocktaking',
    sorted       => {
      _default => {
        by    => 'itime',
        dir   => 0,
      },
      itime        => t8('Insert Date'),
      qty          => t8('Target Qty'),
      chargenumber => t8('Charge Number'),
      comment      => t8('Comment'),
      employee     => t8('Employee'),
      ean          => t8('EAN'),
      partnumber   => t8('Part Number'),
      part         => t8('Part Description'),
      bin          => t8('Bin'),
      cutoff_date  => t8('Cutoff Date'),
    },
    with_objects => ['employee', 'parts', 'warehouse', 'bin'],
  );
}

sub init_stocktaking_cutoff_date {
  my ($self) = @_;

  return DateTime->from_kivitendo($::form->{cutoff_date_as_date}) if $::form->{cutoff_date_as_date};
  return SL::DB::Default->get->stocktaking_cutoff_date if SL::DB::Default->get->stocktaking_cutoff_date;

  # Default cutoff date is last day of current year, but if current month
  # is janurary, it is the last day of the last year.
  my $now    = DateTime->now_local;
  my $cutoff = DateTime->new(year => $now->year, month => 12, day => 31);
  if ($now->month < 1) {
    $cutoff->subtract(years => 1);
  }
  return $cutoff;
}

sub set_target_from_part {
  my ($self) = @_;

  return if !$self->part;

  $self->warehouse($self->part->warehouse) if $self->part->warehouse;
  $self->bin(      $self->part->bin)       if $self->part->bin;
}

sub sanitize_target {
  my ($self) = @_;

  $self->warehouse($self->warehouses->[0])       if !$self->warehouse || !$self->warehouse->id;
  $self->bin      ($self->warehouse->bins_sorted_naturally->[0])  if !$self->bin       || !$self->bin->id;
#  foreach my $warehouse ( $self->warehouses ) {
#      $warehouse->{BINS} = [];
#      foreach my $bin ( $self->bins ) {
#         if ( $bin->warehouse_id == $warehouse->id ) {
#             push @{ $warehouse->{BINS} }, $bin;
#         }
#      }
#  }
}

sub load_part_from_form {
  $_[0]->part(SL::DB::Manager::Part->find_by_or_create(id => $::form->{part_id}||undef));
}

sub load_unit_from_form {
  $_[0]->unit(SL::DB::Manager::Unit->find_by_or_create(id => $::form->{unit_id}));
}

sub load_wh_from_form {
  my $preselected;
  $preselected = SL::DB::Default->get->stocktaking_warehouse_id if $_[0]->is_stocktaking;

  $_[0]->warehouse(SL::DB::Manager::Warehouse->find_by_or_create(id => ($::form->{warehouse_id} || $preselected)));
}

sub load_bin_from_form {
  my $preselected;
  $preselected = SL::DB::Default->get->stocktaking_bin_id if $_[0]->is_stocktaking;

  $_[0]->bin(SL::DB::Manager::Bin->find_by_or_create(id => ($::form->{bin_id} || $preselected)));
}

sub set_layout {
  $::request->layout->add_javascripts('client_js.js');
}

sub build_warehouse_select {
  select_tag('warehouse_id', $_[0]->warehouses,
   title_key => 'description',
   default   => $_[0]->warehouse->id,
   onchange  => 'reload_bin_selection()',
  )
}

sub build_bin_select {
  select_tag('bin_id', $_[0]->warehouse->bins_sorted_naturally,
    title_key => 'description',
    default   => $_[0]->bin->id,
  );
}

sub build_unit_select {
  $_[0]->part->id
    ? select_tag('unit_id', $_[0]->part->available_units,
        title_key => 'name',
        default   => $_[0]->part->unit_obj->id,
      )
    : select_tag('unit_id', $_[0]->units,
        title_key => 'name',
      )
}

sub mini_journal {
  my ($self) = @_;

  # We want to fetch the last 10 inventory events (inventory rows with the same trans_id)
  # To prevent a Seq Scan on inventory set an index on inventory.itime
  # Each event may have one (transfer_in/out) or two (transfer) inventory rows
  # So fetch the last 20, group by trans_id, limit to the last 10 trans_ids,
  # and then extract the inventory ids from those 10 trans_ids
  # By querying Inventory->get_all via the id instead of trans_id we can make
  # use of the existing index on id

  # inventory ids of the most recent 10 inventory trans_ids
  my $query = <<SQL;
with last_inventories as (
   select id,
          trans_id,
          itime
     from inventory
 order by itime desc
    limit 20
),
grouped_ids as (
   select trans_id,
          array_agg(id) as ids
     from last_inventories
 group by trans_id
 order by max(itime)
     desc limit 20
)
select unnest(ids)
  from grouped_ids
 limit 20  -- so the planner knows how many ids to expect, the cte is an optimisation fence
SQL

  my $objs  = SL::DB::Manager::Inventory->get_all(
    query        => [ id => [ \"$query" ] ],                           # " make emacs happy
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

sub mini_stock {
  my ($self) = @_;

  my $stock             = $self->part->get_simple_stock;
  $self->{stock_by_bin} = { map { $_->{bin_id} => $_ } @$stock };
  $self->{stock_empty}  = ! grep { $_->{sum} * 1 } @$stock;
}

sub show_no_warehouses_error {
  my ($self) = @_;

  my $msg = t8('No warehouse has been created yet or the quantity of the bins is not configured yet.') . ' ';

  if ($::auth->check_right($::myconfig{login}, 'config')) { # TODO wut?
    $msg .= t8('You can create warehouses and bins via the menu "System -> Warehouses".');
  } else {
    $msg .= t8('Please ask your administrator to create warehouses and bins.');
  }
  $::form->show_generic_error($msg);
}

sub prepare_stocktaking_report {
  my ($self, %params) = @_;

  my $callback    = $self->stocktaking_models->get_callback;

  my $report       = SL::ReportGenerator->new(\%::myconfig, $::form);
  $report->{title} = t8('Stocktaking Journal');
  $self->{report}  = $report;

  my @columns     = qw(itime employee ean partnumber part qty unit bin chargenumber comment cutoff_date);
  my @sortable    = qw(itime employee ean partnumber part qty bin chargenumber comment cutoff_date);

  my %column_defs = (
    itime           => { sub   => sub { $_[0]->itime_as_timestamp },
                         text  => t8('Insert Date'), },
    employee        => { sub   => sub { $_[0]->employee->safe_name },
                         text  => t8('Employee'), },
    ean             => { sub   => sub { $_[0]->part->ean },
                         text  => t8('EAN'), },
    partnumber      => { sub   => sub { $_[0]->part->partnumber },
                         text  => t8('Part Number'), },
    part            => { sub   => sub { $_[0]->part->description },
                         text  => t8('Part Description'), },
    qty             => { sub   => sub { $_[0]->qty_as_number },
                         text  => t8('Target Qty'),
                         align => 'right', },
    unit            => { sub   => sub { $_[0]->part->unit },
                         text  => t8('Unit'), },
    bin             => { sub   => sub { $_[0]->bin->full_description },
                         text  => t8('Bin'), },
    chargenumber    => { text  => t8('Charge Number'), },
    comment         => { text  => t8('Comment'), },
    cutoff_date     => { sub   => sub { $_[0]->cutoff_date_as_date },
                         text  => t8('Cutoff Date'), },
  );

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'Inventory',
    output_format         => 'HTML',
    title                 => (!!$params{full})? $::locale->text('Stocktaking Journal') : $::locale->text('Stocktaking History'),
    allow_pdf_export      => !!$params{full},
    allow_csv_export      => !!$params{full},
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(stocktaking_journal filter));
  $report->set_options_from_form;
  $self->stocktaking_models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->stocktaking_models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable) if !!$params{full};
  if (!!$params{full}) {
    $report->set_options(
      raw_top_info_text    => $self->render('inventory/stocktaking/full_report_top', { output => 0 }),
    );
  }
  $report->set_options(
    raw_bottom_info_text => $self->render('inventory/stocktaking/report_bottom',   { output => 0 }),
  );
}

sub _get_stocked_qty {
  my ($part, %params) = @_;

  my $bestbefore_filter  = '';
  my $bestbefore_val_cnt = 0;
  if ($::instance_conf->get_show_bestbefore) {
    $bestbefore_filter  = ($params{bestbefore}) ? 'AND bestbefore = ?' : 'AND bestbefore IS NULL';
    $bestbefore_val_cnt = ($params{bestbefore}) ? 1                    : 0;
  }

  my $query = <<SQL;
    SELECT sum(qty) FROM inventory
      WHERE parts_id = ? AND warehouse_id = ? AND bin_id = ? AND chargenumber = ? $bestbefore_filter
      GROUP BY warehouse_id, bin_id, chargenumber
SQL

  my @values = ($part->id,
                $params{warehouse_id},
                $params{bin_id},
                $params{chargenumber});
  push @values, $params{bestbefore} if $bestbefore_val_cnt;

  my ($stocked_qty) = selectrow_query($::form, $::form->get_standard_dbh, $query, @values);

  return 1*($stocked_qty || 0);
}

sub _already_counted {
  my ($part, %params) = @_;

  my %bestbefore_filter;
  if ($::instance_conf->get_show_bestbefore) {
    %bestbefore_filter = (bestbefore => ($params{bestbefore} || undef));
  }

  SL::DB::Manager::Stocktaking->get_all(query => [and => [parts_id     => $part->id,
                                                          warehouse_id => $params{warehouse_id},
                                                          bin_id       => $params{bin_id},
                                                          cutoff_date  => $params{cutoff_date},
                                                          chargenumber => $params{chargenumber},
                                                          %bestbefore_filter]],
                                        sort_by => ['itime DESC']);
}

sub setup_stock_in_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Stock'),
        submit    => [ '#form', { action => 'Inventory/stock' } ],
        checks    => [ 'check_part_selection_before_stocking' ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_stock_usage_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#form', { action => 'Inventory/usage' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_stock_stocktaking_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        checks    => [ 'kivi.Inventory.check_stocktaking_qty_threshold' ],
        call      => [ 'kivi.Inventory.save_stocktaking' ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
__END__

=encoding utf-8

=head1 NAME

SL::Controller::Inventory - Controller for inventory

=head1 DESCRIPTION

This controller handles stock in, stocktaking and reports about inventory
in warehouses/stocks

- warehouse content

- warehouse journal

- warehouse withdrawal

- stocktaking

=head2 Stocktaking

Stocktaking allows to document the counted quantities of parts during
stocktaking for a certain cutoff date. Differences between counted and stocked
quantities are corrected in the stock. The transfer type 'stocktacking' is set
here.

After picking a part, the mini stock for this part is displayed. At the bottom
of the form a history of already counted parts for the current employee and the
choosen cutoff date is shown.

Warehouse, bin and cutoff date canbe preselected in the client configuration.

If a part was already counted for this cutoff date, warehouse and bin, a warning
is displayed, allowing the user to choose to add the counted quantity to the
stocked one or to take his counted quantity as the new stocked quantity.

There is also a journal of stocktakings.

Templates are located under C<templates/design40_webpages/inventory/stocktaking>.
JavaScript functions can be found in C<js/kivi.Inventory.js>.

=head1 FUNCTIONS

=over 4

=item C<action_stock_usage>

Create a search form for stock withdrawal.
The search parameter for report are made like the reports in bin/mozilla/rp.pl

=item C<action_usage>

Make a report about stock withdrawal.

The manual pagination is implemented like the pagination in SL::Controller::CsvImport.

=item C<action_stocktaking>

This action renders the input form for stocktaking.

=item C<action_save_stocktaking>

This action saves the stocktaking values and corrects the stock after checking
if the part is already counted for this warehouse, bin and cutoff date.
For saving SL::WH->transfer is called.

=item C<action_reload_stocktaking_history>

This action is responsible for displaying the stocktaking history at the bottom
of the form. It uses the stocktaking journal with fixed filters for cutoff date
and the current employee. The history is displayed via javascript.

=item C<action_stocktaking_part_changed>

This action is called after the user selected or changed the part.

=item C<action_stocktaking_get_warn_qty_threshold>

This action checks if a warning should be shown and returns the warning text via
ajax. The warning will be shown if the given target value is greater than the
threshold given in the client configuration.

=item C<is_stocktaking>

This is a method to check if actions are called from stocktaking form.
This actions should contain "stocktaking" in their name.

=back

=head1 SPECIAL CASES

Because of the PFD-Table Formatter some parameters for PDF must be different to the HTML parameters.
So in german language there are some tries to use a HTML Break in the second heading line
to produce two line heading inside table. The actual version has some abbreviations for the header texts.

=head1 BUGS

The PDF-Table library has some limits (doesn't display all if the line is to large) so
the format is adapted to this


=head1 AUTHOR

=over 4

=item only for C<action_stock_usage> and C<action_usage>:

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>

=item for stocktaking:

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=back

=cut
