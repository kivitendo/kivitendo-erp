package SL::Controller::CsvImport::ARTransaction;

use strict;

use List::MoreUtils qw(any);

use Data::Dumper;
use SL::Helper::Csv;
use SL::Controller::CsvImport::Helper::Consistency;
use SL::DB::Invoice;
use SL::DB::AccTransaction;
use SL::DB::Department;
use SL::DB::Project;
use SL::DB::TaxZone;
use SL::DB::Chart;
use SL::TransNumber;
use DateTime;

use parent qw(SL::Controller::CsvImport::BaseMulti);

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(settings charts_by taxkeys_by) ],
);


sub init_class {
  my ($self) = @_;
  $self->class(['SL::DB::Invoice', 'SL::DB::AccTransaction']);
}

sub set_profile_defaults {
  my ($self) = @_;

  $self->controller->profile->_set_defaults(
                       ar_column          => $::locale->text('Invoice'),
                       transaction_column => $::locale->text('AccTransaction'),
                       max_amount_diff    => 0.02,
                      );
};


sub init_settings {
  my ($self) = @_;

  return { map { ( $_ => $self->controller->profile->get($_) ) } qw(ar_column transaction_column max_amount_diff) };
}

sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;

  # SUPER::init_profile sets row_ident to the translated class name
  # overwrite it with the user specified settings
# TODO: remove hardcoded row_idents
  foreach my $p (@{ $profile }) {
    if ($p->{class} eq 'SL::DB::Invoice') {
      $p->{row_ident} = $self->_ar_column;
    }
    if ($p->{class} eq 'SL::DB::AccTransaction') {
      $p->{row_ident} = $self->_transaction_column;
    }
  }

  foreach my $p (@{ $profile }) {
    my $prof = $p->{profile};
    if ($p->{row_ident} eq $self->_ar_column) {
      # no need to handle
      delete @{$prof}{qw(delivery_customer_id delivery_vendor_id )};
    }
    if ($p->{row_ident} eq $self->_transaction_column) {
      # no need to handle
      delete @{$prof}{qw(trans_id)};
    }
  }

  return $profile;
}


sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_displayable_columns($self->_ar_column,
                                 { name => 'datatype',                description => $self->_ar_column . ' [1]'                               },
                                 { name => 'currency',                description => $::locale->text('Currency')                              },
                                 { name => 'cusordnumber',            description => $::locale->text('Customer Order Number')                 },
                                 { name => 'direct_debit',            description => $::locale->text('direct debit')                          },
                                 { name => 'donumber',                description => $::locale->text('Delivery Order Number')                 },
                                 { name => 'duedate',                 description => $::locale->text('Due Date')                              },
                                 { name => 'delivery_term_id',        description => $::locale->text('Delivery terms (database ID)')          },
                                 { name => 'delivery_term',           description => $::locale->text('Delivery terms (name)')                 },
                                 { name => 'deliverydate',            description => $::locale->text('Delivery Date')                         },
                                 { name => 'employee_id',             description => $::locale->text('Employee (database ID)')                },
                                 { name => 'intnotes',                description => $::locale->text('Internal Notes')                        },
                                 { name => 'notes',                   description => $::locale->text('Notes')                                 },
                                 { name => 'invnumber',               description => $::locale->text('Invoice Number')                        },
                                 { name => 'quonumber',               description => $::locale->text('Quotation Number')                      },
                                 { name => 'reqdate',                 description => $::locale->text('Reqdate')                               },
                                 { name => 'salesman_id',             description => $::locale->text('Salesman (database ID)')                },
                                 { name => 'transaction_description', description => $::locale->text('Transaction description')               },
                                 { name => 'transdate',               description => $::locale->text('Invoice Date')                          },
                                 { name => 'verify_amount',           description => $::locale->text('Amount (for verification)') . ' [2]'    },
                                 { name => 'verify_netamount',        description => $::locale->text('Net amount (for verification)') . ' [2]'},
                                 { name => 'taxincluded',             description => $::locale->text('Tax Included')                          },
                                 { name => 'customer',                description => $::locale->text('Customer (name)')                       },
                                 { name => 'customernumber',          description => $::locale->text('Customer Number')                       },
                                 { name => 'customer_gln',            description => $::locale->text('Customer GLN')                          },
                                 { name => 'customer_id',             description => $::locale->text('Customer (database ID)')                },
                                 { name => 'language_id',             description => $::locale->text('Language (database ID)')                },
                                 { name => 'language',                description => $::locale->text('Language (name)')                       },
                                 { name => 'payment_id',              description => $::locale->text('Payment terms (database ID)')           },
                                 { name => 'payment',                 description => $::locale->text('Payment terms (name)')                  },
                                 { name => 'taxzone_id',              description => $::locale->text('Tax zone (database ID)')                },
                                 { name => 'taxzone',                 description => $::locale->text('Tax zone (description)')                },
                                 { name => 'department_id',           description => $::locale->text('Department (database ID)')              },
                                 { name => 'department',              description => $::locale->text('Department (description)')              },
                                 { name => 'globalproject_id',        description => $::locale->text('Document Project (database ID)')        },
                                 { name => 'globalprojectnumber',     description => $::locale->text('Document Project (number)')             },
                                 { name => 'globalproject',           description => $::locale->text('Document Project (description)')        },
                                 { name => 'archart',                 description => $::locale->text('Receivables account (account number)')  },
                                 { name => 'orddate',                 description => $::locale->text('Order Date')                            },
                                 { name => 'ordnumber',               description => $::locale->text('Order Number')                          },
                                 { name => 'quonumber',               description => $::locale->text('Quotation Number')                      },
                                 { name => 'quodate',                 description => $::locale->text('Quotation Date')                        },
                                );

  $self->add_displayable_columns($self->_transaction_column,
                                 { name => 'datatype',      description => $self->_transaction_column . ' [1]'       },
                                 { name => 'projectnumber', description => $::locale->text('Project (number)')       },
                                 { name => 'project',       description => $::locale->text('Project (description)')  },
                                 { name => 'amount',        description => $::locale->text('Amount')                 },
                                 { name => 'accno',         description => $::locale->text('Account number')         },
                                 { name => 'taxkey',        description => $::locale->text('Taxkey')                 },
                                );
}

sub init_taxkeys_by {
  my ($self) = @_;

  my $all_taxes = SL::DB::Manager::Tax->get_all;
  return { map { $_->taxkey => $_->id } @{ $all_taxes } };
}


sub init_charts_by {
  my ($self) = @_;

  my $all_charts = SL::DB::Manager::Chart->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_charts } } ) } qw(id accno) };
}

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my $i = 0;
  my $num_data = scalar @{ $self->controller->data };
  my $invoice_entry;

  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    if ($entry->{raw_data}->{datatype} eq $self->_ar_column) {
      $self->handle_invoice($entry);
      $invoice_entry = $entry;
    } elsif ($entry->{raw_data}->{datatype} eq $self->_transaction_column ) {
      die "Cannot process transaction row without an invoice row" if !$invoice_entry;
      $self->handle_transaction($entry, $invoice_entry);
    } else {
      die "unknown datatype";
    };

  } continue {
    $i++;
  } # finished data parsing

  $self->add_transactions_to_ar(); # go through all data entries again, adding receivable entry to ar lines while calculating amount and netamount

  foreach my $entry (@{ $self->controller->data }) {
    next unless ($entry->{raw_data}->{datatype} eq $self->_ar_column);
    $self->check_verify_amounts($entry->{object});
  };

  foreach my $entry (@{ $self->controller->data }) {
    next unless ($entry->{raw_data}->{datatype} eq $self->_ar_column);
    unless ( $entry->{object}->validate_acc_trans ) {
      push @{ $entry->{errors} }, $::locale->text('Error: ar transaction doesn\'t validate');
    };
  };

  # add info columns that aren't directly part of the object to be imported
  # but are always determined or should always be shown because they are mandatory
  $self->add_info_columns($self->_ar_column,
                          { header => $::locale->text('Customer/Vendor'),     method => 'vc_name'   },
                          { header => $::locale->text('Receivables account'), method => 'archart'   },
                          { header => $::locale->text('Amount'),              method => 'amount'    },
                          { header => $::locale->text('Net amount'),          method => 'netamount' },
                          { header => $::locale->text('Tax zone'),            method => 'taxzone'   });

  # Adding info_header this way only works, if the first invoice $self->controller->data->[0]

  # Todo: access via ->[0] ok? Better: search first order column and use this
  $self->add_info_columns($self->_ar_column, { header => $::locale->text('Department'),    method => 'department' }) if $self->controller->data->[0]->{info_data}->{department} or $self->controller->data->[0]->{raw_data}->{department};

  $self->add_info_columns($self->_ar_column, { header => $::locale->text('Project Number'), method => 'globalprojectnumber' }) if $self->controller->data->[0]->{info_data}->{globalprojectnumber};

  $self->add_columns($self->_ar_column,
                     map { "${_}_id" } grep { exists $self->controller->data->[0]->{raw_data}->{$_} } qw(payment department globalproject taxzone cp currency));
  $self->add_columns($self->_ar_column, 'globalproject_id') if exists $self->controller->data->[0]->{raw_data}->{globalprojectnumber};
  $self->add_columns($self->_ar_column, 'notes')            if exists $self->controller->data->[0]->{raw_data}->{notes};

  # Todo: access via ->[1] ok? Better: search first item column and use this
  $self->add_info_columns($self->_transaction_column, { header => $::locale->text('Chart'), method => 'accno' });
  $self->add_columns($self->_transaction_column, 'amount');

  $self->add_info_columns($self->_transaction_column, { header => $::locale->text('Project Number'), method => 'projectnumber' }) if $self->controller->data->[1]->{info_data}->{projectnumber};

  # $self->add_columns($self->_transaction_column,
  #                    map { "${_}_id" } grep { exists $self->controller->data->[1]->{raw_data}->{$_} } qw(project price_factor pricegroup));
  # $self->add_columns($self->_transaction_column,
  #                    map { "${_}_id" } grep { exists $self->controller->data->[2]->{raw_data}->{$_} } qw(project price_factor pricegroup));
  # $self->add_columns($self->_transaction_column, 'project_id') if exists $self->controller->data->[1]->{raw_data}->{projectnumber};
  # $self->add_columns($self->_transaction_column, 'taxkey') if exists $self->controller->data->[1]->{raw_data}->{taxkey};

  # If invoice has errors, add error for acc_trans items
  # If acc_trans item has an error, add an error to the invoice item
  my $ar_entry;
  foreach my $entry (@{ $self->controller->data }) {
    # Search first order
    if ($entry->{raw_data}->{datatype} eq $self->_ar_column) {
      $ar_entry = $entry;
    } elsif ( defined $ar_entry
              && $entry->{raw_data}->{datatype} eq $self->_transaction_column
              && scalar @{ $ar_entry->{errors} } > 0 ) {
      push @{ $entry->{errors} }, $::locale->text('Error: invalid ar row for this transaction');
    } elsif ( defined $ar_entry
              && $entry->{raw_data}->{datatype} eq $self->_transaction_column
              && scalar @{ $entry->{errors} } > 0 ) {
      push @{ $ar_entry->{errors} }, $::locale->text('Error: invalid acc transactions for this ar row');
    }
  }
}

sub handle_invoice {

  my ($self, $entry) = @_;

  my $object = $entry->{object};

  $object->transactions( [] ); # initialise transactions for ar object so methods work on unsaved transactions

  my $vc_obj;
  if (any { $entry->{raw_data}->{$_} } qw(customer customernumber customer_gln customer_id)) {
    $self->check_vc($entry, 'customer_id');
    # check_vc only sets customer_id, but we need vc_obj later for customer defaults
    $vc_obj = SL::DB::Customer->new(id => $object->customer_id)->load if $object->customer_id;
  } elsif (any { $entry->{raw_data}->{$_} } qw(vendor vendornumber vendor_gln vendor_id)) {
    $self->check_vc($entry, 'vendor_id');
    $vc_obj = SL::DB::Vendor->new(id => $object->vendor_id)->load if $object->vendor_id;
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: Customer/vendor missing');
  }

  # check for duplicate invnumbers already in database
  if ( SL::DB::Manager::Invoice->get_all_count( where => [ invnumber => $object->invnumber ] ) ) {
    push @{ $entry->{errors} }, $::locale->text('Error: invnumber already exists');
  }

  $self->check_archart($entry); # checks for receivable account
  # $self->check_amounts($entry); # checks and sets amount and netamount, use verify_amount and verify_netamount instead
  $self->check_payment($entry); # currency default from customer used below
  $self->check_department($entry);
  $self->check_taxincluded($entry);
  $self->check_project($entry, global => 1);
  $self->check_taxzone($entry); # taxzone default from customer used below
  $self->check_currency($entry); # currency default from customer used below
  $self->handle_salesman($entry);
  $self->handle_employee($entry);

  if ($vc_obj ) {
    # copy defaults from customer if not specified in import file
    foreach (qw(payment_id language_id taxzone_id currency_id)) {
      $object->$_($vc_obj->$_) unless $object->$_;
    }
  }
}

sub check_taxkey {
  my ($self, $entry, $invoice_entry, $chart) = @_;

  die "check_taxkey needs chart object as an argument" unless ref($chart) eq 'SL::DB::Chart';
  # problem: taxkey is not unique in table tax, normally one of those entries is chosen directly from a dropdown
  # so we check if the chart has an active taxkey, and if it matches the taxkey from the import, use the active taxkey
  # if the chart doesn't have an active taxkey, use the first entry from Tax that matches the taxkey

  my $object         = $entry->{object};
  my $invoice_object = $invoice_entry->{object};

  unless ( defined $entry->{raw_data}->{taxkey} ) {
    push @{ $entry->{errors} }, $::locale->text('Error: taxkey missing'); # don't just assume 0, force taxkey in import
    return 0;
  };

  my $tax = $chart->get_active_taxkey($invoice_object->deliverydate // $invoice_object->transdate // DateTime->today_local)->tax;
  if ( $entry->{raw_data}->{taxkey} != $tax->taxkey ) {
   # assume there is only one tax entry with that taxkey, can't guess
    $tax = SL::DB::Manager::Tax->get_first( where => [ taxkey => $entry->{raw_data}->{taxkey} ]);
  };

  unless ( $tax ) {
    push @{ $entry->{errors} }, $::locale->text('Error: invalid taxkey');
    return 0;
  };

  $object->taxkey($tax->taxkey);
  $object->tax_id($tax->id);
  return 1;
};

sub check_amounts {
  my ($self, $entry) = @_;
  # currently not used in favour of verify_amount and verify_netamount

  my $object = $entry->{object};

  unless ($entry->{raw_data}->{amount} && $entry->{raw_data}->{netamount}) {
    push @{ $entry->{errors} }, $::locale->text('Error: need amount and netamount');
    return 0;
  };
  unless ($entry->{raw_data}->{amount} * 1 && $entry->{raw_data}->{netamount} * 1) {
    push @{ $entry->{errors} }, $::locale->text('Error: amount and netamount need to be numeric');
    return 0;
  };

  $object->amount( $entry->{raw_data}->{amount} );
  $object->netamount( $entry->{raw_data}->{netamount} );
};

sub handle_transaction {
  my ($self, $entry, $invoice_entry) = @_;

  # Prepare acc_trans data. amount is dealt with in add_transactions_to_ar

  my $object = $entry->{object};

  $self->check_project($entry, global => 0);
  if ( $self->check_chart($entry) ) {
    my $chart_obj = SL::DB::Manager::Chart->find_by(id => $object->chart_id);

    unless ( $chart_obj->link =~ /AR_amount/ ) {
      push @{ $entry->{errors} }, $::locale->text('Error: chart isn\'t an ar_amount chart');
      return 0;
    };

    if ( $self->check_taxkey($entry, $invoice_entry, $chart_obj) ) {
      # do nothing, taxkey was assigned, just continue
    } else {
      # missing taxkey, don't do anything
      return 0;
    };
  } else {
    return 0;
  };

  # check whether taxkey and automatic taxkey match
  # die sprintf("taxkeys don't match: %s not equal default taxkey for chart %s: %s", $object->taxkey, $chart_obj->accno, $active_tax_for_chart->tax->taxkey) unless $object->taxkey == $active_tax_for_chart->tax->taxkey;

  die "no taxkey for transaction object" unless $object->taxkey or $object->taxkey == 0;

}

sub check_chart {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  if (any { $entry->{raw_data}->{$_} } qw(accno chart_id)) {

    # Check whether or not chart ID is valid.
    if ($object->chart_id && !$self->charts_by->{id}->{ $object->chart_id }) {
      push @{ $entry->{errors} }, $::locale->text('Error: invalid chart_id');
      return 0;
    }

    # Map number to ID if given.
    if (!$object->chart_id && $entry->{raw_data}->{accno}) {
      my $chart = $self->charts_by->{accno}->{ $entry->{raw_data}->{accno} };
      if (!$chart) {
        push @{ $entry->{errors} }, $::locale->text('Error: invalid chart (accno)');
        return 0;
      }

      $object->chart_id($chart->id);
    }

    # Map description to ID if given.
    if (!$object->chart_id && $entry->{raw_data}->{description}) {
      my $chart = $self->charts_by->{description}->{ $entry->{raw_data}->{description} };
      if (!$chart) {
        push @{ $entry->{errors} }, $::locale->text('Error: invalid chart');
        return 0;
      }

      $object->chart_id($chart->id);
    }

    if ($object->chart_id) {
      # add account number to preview
      $entry->{info_data}->{accno} = $self->charts_by->{id}->{ $object->chart_id }->accno;
    } else {
      push @{ $entry->{errors} }, $::locale->text('Error: chart not found');
      return 0;
    }
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: chart missing');
    return 0;
  }

  return 1;
}

sub check_archart {
  my ($self, $entry) = @_;

  my $chart;

  if ( $entry->{raw_data}->{archart} ) {
    my $archart = $entry->{raw_data}->{archart};
    $chart = SL::DB::Manager::Chart->find_by(accno => $archart);
    unless ($chart) {
      push @{ $entry->{errors} }, $::locale->text("Error: can't find ar chart with accno #1", $archart);
      return 0;
    };
  } elsif ( $::instance_conf->get_ar_chart_id ) {
    $chart = SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_ar_chart_id);
  } else {
    push @{ $entry->{errors} }, $::locale->text("Error: neither archart passed, no default receivables chart configured");
    return 0;
  };

  unless ($chart->link eq 'AR') {
    push @{ $entry->{errors} }, $::locale->text('Error: archart isn\'t an AR chart');
    return 0;
  };

  $entry->{info_data}->{archart} = $chart->accno;
  $entry->{object}->{archart} = $chart;
  return 1;
};

sub check_taxincluded {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  if ( $entry->{raw_data}->{taxincluded} ) {
    if ( $entry->{raw_data}->{taxincluded} eq 'f' or $entry->{raw_data}->{taxincluded} eq '0' ) {
      $object->taxincluded('0');
    } elsif ( $entry->{raw_data}->{taxincluded} eq 't' or $entry->{raw_data}->{taxincluded} eq '1' ) {
      $object->taxincluded('1');
    } else {
      push @{ $entry->{errors} }, $::locale->text('Error: taxincluded has to be t or f');
      return 0;
    };
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: taxincluded wasn\'t set');
    return 0;
  };
  return 1;
};

sub check_verify_amounts {
  my ($self) = @_;

  # If amounts are given, show calculated amounts as info and given amounts (verify_xxx).
  # And throw an error if the differences are too big.
  my @to_verify = ( { column      => 'amount',
                      raw_column  => 'verify_amount',
                      info_header => 'Calc. Amount',
                      info_method => 'calc_amount',
                      err_msg     => $::locale->text('Amounts differ too much'),
                    },
                    { column      => 'netamount',
                      raw_column  => 'verify_netamount',
                      info_header => 'Calc. Net amount',
                      info_method => 'calc_netamount',
                      err_msg     => $::locale->text('Net amounts differ too much'),
                    } );

  foreach my $tv (@to_verify) {
    if (exists $self->controller->data->[0]->{raw_data}->{ $tv->{raw_column} }) {
      $self->add_raw_data_columns($self->_ar_column, $tv->{raw_column});
      $self->add_info_columns($self->_ar_column,
                              { header => $::locale->text($tv->{info_header}), method => $tv->{info_method} });
    }

    # check differences
    foreach my $entry (@{ $self->controller->data }) {
      if ( @{ $entry->{errors} } ) {
        push @{ $entry->{errors} }, $::locale->text($tv->{err_msg});
        return 0;
      };

      if ($entry->{raw_data}->{datatype} eq $self->_ar_column) {
        next if !$entry->{raw_data}->{ $tv->{raw_column} };
        my $parsed_value = $::form->parse_amount(\%::myconfig, $entry->{raw_data}->{ $tv->{raw_column} });
        # round $abs_diff, otherwise it might trigger for 0.020000000000021
        my $abs_diff = $::form->round_amount(abs($entry->{object}->${ \$tv->{column} } - $parsed_value),2);
        if ( $abs_diff > $self->settings->{'max_amount_diff'}) {
          push @{ $entry->{errors} }, $::locale->text($tv->{err_msg});
        }
      }
    }
  }
};

sub add_transactions_to_ar {
  my ($self) = @_;

  # go through all verified ar and acc_trans rows in import, adding acc_trans objects to ar objects

  my $ar_entry;  # the current ar row

  foreach my $entry (@{ $self->controller->data }) {
    # when we reach an ar_column for the first time, don't do anything, just store in $ar_entry
    # when we reach an ar_column for the second time, save it
    if ($entry->{raw_data}->{datatype} eq $self->_ar_column) {
      if ( $ar_entry && $ar_entry->{object} ) { # won't trigger the first time, finishes the last object
        if ( $ar_entry->{object}->{archart} && $ar_entry->{object}->{archart}->isa('SL::DB::Chart') ) {
          $ar_entry->{object}->recalculate_amounts; # determine and set amount and netamount for ar
          $ar_entry->{object}->create_ar_row(chart => $ar_entry->{object}->{archart});
          $ar_entry->{info_data}->{amount}    = $ar_entry->{object}->amount;
          $ar_entry->{info_data}->{netamount} = $ar_entry->{object}->netamount;
        } else {
          push @{ $entry->{errors} }, $::locale->text("ar_chart isn't a valid chart");
        };
      };
      $ar_entry = $entry; # remember as last ar_entry

    } elsif ( defined $ar_entry && $entry->{raw_data}->{datatype} eq $self->_transaction_column ) {
      push @{ $entry->{errors} }, $::locale->text('no tax_id in acc_trans') if !defined $entry->{object}->tax_id;
      next if @{ $entry->{errors} };

      my $acc_trans_objects = $ar_entry->{object}->add_ar_amount_row(
        amount      => $entry->{object}->amount,
        chart       => SL::DB::Manager::Chart->find_by(id => $entry->{object}->chart_id), # add_ar_amount takes chart obj. as argument
        tax_id      => $entry->{object}->tax_id,
        project_id  => $entry->{object}->project_id,
        debug       => 0,
      );

    } else {
      die "This should never happen\n";
    };
  }

  # finish the final object
  if ( $ar_entry->{object} ) {
    if ( $ar_entry->{object}->{archart} && $ar_entry->{object}->{archart}->isa('SL::DB::Chart') ) {
      $ar_entry->{object}->recalculate_amounts;
      $ar_entry->{info_data}->{amount}    = $ar_entry->{object}->amount;
      $ar_entry->{info_data}->{netamount} = $ar_entry->{object}->netamount;

      $ar_entry->{object}->create_ar_row(chart => $ar_entry->{object}->{archart});
    } else {
      push @{ $ar_entry->{errors} }, $::locale->text("The receivables chart isn't a valid chart.");
      return 0;
    };
  } else {
    die "There was no final ar_entry object";
  };
}

sub save_objects {
  my ($self, %params) = @_;

  # save all the Invoice objects
  my $objects_to_save;
  foreach my $entry (@{ $self->controller->data }) {
    # only push the invoice objects that don't have an error
    next if $entry->{raw_data}->{datatype} ne $self->_ar_column;
    next if @{ $entry->{errors} };

    die unless $entry->{object}->validate_acc_trans;

    push @{ $objects_to_save }, $entry;
  }

  $self->SUPER::save_objects(data => $objects_to_save);
}

sub _ar_column {
  $_[0]->settings->{'ar_column'}
}

sub _transaction_column {
  $_[0]->settings->{'transaction_column'}
}

1;
