package AccTransCorrections;

use utf8;
use strict;

use List::Util qw(first);

use SL::DBUtils;
use SL::Taxkeys;
use SL::DB;

sub new {
  my $type = shift;

  my $self = {};

  bless $self, $type;

  $self->{taxkeys} = Taxkeys->new();

  return $self;
}

sub _fetch_transactions {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my (@where, @values) = ((), ());

  if ($params{transdate_from}) {
    push @where,  qq|at.transdate >= ?|;
    push @values, $params{transdate_from};
  }

  if ($params{transdate_to}) {
    push @where,  qq|at.transdate <= ?|;
    push @values, $params{transdate_to};
  }

  if ($params{trans_id}) {
    push @where,  qq|at.trans_id = ?|;
    push @values, $params{trans_id};
  }

  my $where = '';
  if (scalar @where) {
    $where = 'WHERE ' . join(' AND ', map { "($_)" } @where);
  }

  my $query = qq!
    SELECT at.*,
      c.accno, c.description AS chartdescription, c.charttype, c.category AS chartcategory, c.link AS chartlink,
      COALESCE(gl.reference, COALESCE(ap.invnumber, ar.invnumber)) AS reference,
      COALESCE(ap.invoice, COALESCE(ar.invoice, FALSE)) AS invoice,
      CASE
        WHEN gl.id IS NOT NULL THEN gl.storno AND (gl.storno_id IS NOT NULL)
        WHEN ap.id IS NOT NULL THEN ap.storno AND (ap.storno_id IS NOT NULL)
        ELSE                        ar.storno AND (ar.storno_id IS NOT NULL)
      END AS is_storno,
      CASE
        WHEN gl.id IS NOT NULL THEN 'gl'
        WHEN ap.id IS NOT NULL THEN 'ap'
        ELSE                        'ar'
      END AS module

    FROM acc_trans at
    LEFT JOIN chart c ON (at.chart_id = c.id)
    LEFT JOIN gl      ON (at.trans_id = gl.id)
    LEFT JOIN ap      ON (at.trans_id = ap.id)
    LEFT JOIN ar      ON (at.trans_id = ar.id)
    $where
    ORDER BY at.trans_id, at.acc_trans_id
!;

  my @transactions = ();
  my $last_trans   = undef;

  foreach my $entry (@{ selectall_hashref_query($form, $dbh, $query, @values) }) {
    if (!$last_trans || ($last_trans->[0]->{trans_id} != $entry->{trans_id})) {
      $last_trans = [];
      push @transactions, $last_trans;
    }

    push @{ $last_trans }, $entry;
  }

  $main::lxdebug->leave_sub();

  return @transactions;
}

sub _prepare_data {
  $main::lxdebug->enter_sub();

  my $self        = shift;
  my %params      = @_;

  my $transaction = $params{transaction};
  my $callback    = $params{callback};

  my $myconfig    = \%main::myconfig;
  my $form        = $main::form;

  my $data          = {
    'credit'        => {
      'num'         => 0,
      'sum'         => 0,
      'entries'     => [],
      'tax_sum'     => 0,
      'tax_entries' => [],
    },
    'debit'         => {
      'num'         => 0,
      'sum'         => 0,
      'entries'     => [],
      'tax_sum'     => 0,
      'tax_entries' => [],
    },
    'payments'      => [],
  };

  foreach my $entry (@{ $transaction }) {
    $entry->{chartlinks} = { map { $_ => 1 } split(m/:/, $entry->{chartlink}) };
    delete $entry->{chartlink};
  }

  # Verknüpfungen zwischen Steuerschlüsseln und zum Zeitpunkt der Transaktion
  # gültigen Steuersätze
  my %all_taxes = $self->{taxkeys}->get_full_tax_info('transdate' => $transaction->[0]->{transdate});

  my ($trans_type, $previous_non_tax_entry);
  my $sum             = 0;
  my $first_sub_trans = 1;

  my $storno_mult     = $transaction->[0]->{is_storno} ? -1 : 1;

  # Aufteilung der Buchungspositionen in Soll-, Habenseite sowie
  # getrennte Auflistung der Positionen, die auf Steuerkonten gebucht werden.
  foreach my $entry (@{ $transaction }) {
    if (!$first_sub_trans && ($entry->{chartlinks}->{AP_paid} || $entry->{chartlinks}->{AR_paid})) {
      push @{ $data->{payments} }, $entry;
      next;
    }

    my $tax_info = $all_taxes{taxkeys}->{ $entry->{taxkey} };
    if ($tax_info) {
      $entry->{taxdescription} = $tax_info->{taxdescription} . ' ' . $form->format_amount($myconfig, $tax_info->{taxrate} * 100) . ' %';
    }

    if ($entry->{chartlinks}->{AP}) {
      $trans_type = 'AP';
    } elsif ($entry->{chartlinks}->{AR}) {
      $trans_type = 'AR';
    }

    my $idx = 0 < ($entry->{amount} * $storno_mult) ? 'credit' : 'debit';

    if ($entry->{chartlinks}->{AP_tax} || $entry->{chartlinks}->{AR_tax}) {
      $data->{$idx}->{tax_sum} += $entry->{amount};
      push @{ $data->{$idx}->{tax_entries} }, $entry;

      if ($previous_non_tax_entry) {
        $previous_non_tax_entry->{tax_entry} = $entry;
        undef $previous_non_tax_entry;
      }

    } else {
      $data->{$idx}->{sum} += $entry->{amount};
      push @{ $data->{$idx}->{entries} }, $entry;

      $previous_non_tax_entry = $entry;
    }

    $sum += $entry->{amount};

    if (abs($sum) < 0.02) {
      $sum             = 0;
      $first_sub_trans = 0;
    }
  }

  # Alle Einträge entfernen, die die Gegenkonten zu Zahlungsein- und
  # -ausgängen darstellen.
  foreach my $payment (@{ $data->{payments} }) {
    my $idx = 0 < $payment->{amount} ? 'debit' : 'credit';

    foreach my $i (0 .. scalar(@{ $data->{$idx}->{entries} }) - 1) {
      my $entry = $data->{$idx}->{entries}->[$i];

      next if ((($payment->{amount} * -1) != $entry->{amount}) || ($payment->{transdate} ne $entry->{transdate}));

      splice @{ $data->{$idx}->{entries} }, $i, 1;

      last;
    }
  }

  delete $data->{payments};

  map { $data->{$_}->{num} = scalar @{ $data->{$_}->{entries} } } qw(credit debit);

  my $info   = $transaction->[0];
  my $script = ($info->{module} eq 'ar') && $info->{invoice} ? 'is'
             : ($info->{module} eq 'ap') && $info->{invoice} ? 'ir'
             :                                                 $info->{module};

  my %common_args = (
    'data'          => $data,
    'trans_type'    => $trans_type,
    'all_taxes'     => { %all_taxes },
    'transaction'   => $transaction,
    'full_analysis' => $params{full_analysis},
    'problem'       => {
      'data'        => $info,
      'link'        => $script . ".pl?action=edit${callback}&id=" . $info->{trans_id},
    },
    );

  $main::lxdebug->leave_sub();

  return %common_args;
}

sub _group_sub_transactions {
  $main::lxdebug->enter_sub();

  my $self             = shift;
  my $transaction      = shift;

  my @sub_transactions = ();
  my $sum              = 0;

  foreach my $i (0 .. scalar(@{ $transaction }) - 1) {
    my $entry = $transaction->[$i];

    if (abs($sum) <= 0.01) {
      push @sub_transactions, [];
      $sum = 0;
    }
    $sum += $entry->{amount};

    push @{ $sub_transactions[-1] }, $entry;
  }

  $main::lxdebug->leave_sub();

  return @sub_transactions;
}

# Problemfall: Verkaufsrechnungen, bei denen Buchungen auf Warenbestandskonten
# mit Steuerschlüssel != 0 durchgeführt wurden. Richtig wäre, dass alle
# Steuerschlüssel für solche Warenbestandsbuchungen 0 sind.
sub _check_trans_invoices_inventory_with_taxkeys {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my %params = @_;

  # ist nur für bestandsmethode notwendig. bei der Aufwandsmethode
  # können Warenkonten mit Steuerschlüssel sein (5400 in SKR04)
  return 0 if $::instance_conf->get_inventory_system eq 'periodic';

  if (!$params{transaction}->[0]->{invoice}) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  my @sub_transactions = $self->_group_sub_transactions($params{transaction});

  foreach my $sub_transaction (@sub_transactions) {
    my $is_cogs = first { $_->{chartlinks}->{IC_cogs} } @{ $sub_transaction };
    next unless ($is_cogs);

    my $needs_fixing = first { $_->{taxkey} != 0 } @{ $sub_transaction };
    next unless ($needs_fixing);

    $params{problem}->{type} = 'invoice_inventory_with_taxkeys';
    push @{ $self->{invoice_inventory_taxkey_problems} }, $params{problem};

    $main::lxdebug->leave_sub();

    return 1;
  }

  $main::lxdebug->leave_sub();

  return 0;
}

# Problemfall: Verkaufsrechnungen, bei denen Steuern verbucht wurden, obwohl
# kein Steuerschlüssel eingetragen ist.
sub _check_missing_taxkeys_in_invoices {
  $::lxdebug->enter_sub;

  my $self        = shift;
  my %params      = @_;
  my $transaction = $params{transaction};
  my $found_broken = 0;

  $::lxdebug->leave_sub and return 0
    if    !$transaction->[0]->{invoice};

  my @sub_transactions = $self->_group_sub_transactions($transaction);

  for my $sub_transaction (@sub_transactions) {
    $::lxdebug->leave_sub and return 0
      if    _is_split_transaction($sub_transaction)
         || _is_simple_transaction($sub_transaction);

    my $split_side_entries = _get_splitted_side($sub_transaction);
    my $num_tax_rows;
    my $num_taxed_rows;
    for my $entry (@{ $split_side_entries }) {
      my $is_tax = grep { m/(?:AP_tax|AR_tax)/ } keys %{ $entry->{chartlinks} };

      $num_tax_rows++   if  $is_tax;
      $num_taxed_rows++ if !$is_tax && $entry->{tax_key} != 0;
    }

    # now if this has tax rows but NO taxed rows, something is wrong.
    if ($num_tax_rows > 0 && $num_taxed_rows == 0) {
      $params{problem}->{type} = 'missing_taxkeys_in_invoices';
      push @{ $self->{missing_taxkeys_in_invoices} ||= [] }, $params{problem};
      $found_broken = 1;
    }
  }

  $::lxdebug->leave_sub;

  return $found_broken;
}

# Problemfall: Kreditorenbuchungen, bei denen mit Umsatzsteuerschlüsseln
# gebucht wurde und Debitorenbuchungen, bei denen mit Vorsteuerschlüsseln
# gebucht wurde.
sub _check_trans_ap_ar_wrong_taxkeys {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my %params = @_;

  my $retval = 0;

  if (!$params{transaction}->[0]->{invoice}
      && ((   ($params{transaction}->[0]->{module} eq 'ap')
          && (first { my $taxkey = $_->{taxkey}; first { $taxkey == $_ } (2, 3, 12, 13) } @{ $params{transaction} }))
         ||
         (   ($params{transaction}->[0]->{module} eq 'ar')
          && (first { my $taxkey = $_->{taxkey}; first { $taxkey == $_ } (8, 9, 18, 19) } @{ $params{transaction} })))) {
    $params{problem}->{type} = 'ap_ar_wrong_taxkeys';
    push @{ $self->{ap_ar_taxkey_problems} }, $params{problem};

    $retval = 1;
  }

  $main::lxdebug->leave_sub();

  return $retval;
}

# Problemfall: Splitbuchungen, die mehrere Haben- und Sollkonten ansprechen.
# Aber nur für Debitoren- und Kreditorenbuchungen, weil das bei Einkaufs- und
# Verkaufsrechnungen hingegen völlig normal ist.
sub _check_trans_split_multiple_credit_and_debit {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my %params = @_;

  my $retval = 0;

  if (   !$params{transaction}->[0]->{invoice}
      && (1 < $params{data}->{credit}->{num})
      && (1 < $params{data}->{debit}->{num})) {
    $params{problem}->{type} = 'split_multiple_credit_and_debit';
    push @{ $self->{problems} }, $params{problem};

    $retval = 1;
  }

  $main::lxdebug->leave_sub();

  return $retval;
}

# Problemfall: Buchungen, bei denen Steuersummen nicht mit den Summen
# übereinstimmen, die nach ausgewähltem Steuerschlüssel hätten auftreten müssen.
sub _check_trans_wrong_taxkeys {
  $main::lxdebug->enter_sub();

  my $self        = shift;
  my %params      = @_;

  my $form        = $main::form;

  my %data        = %{ $params{data} };
  my $transaction = $params{transaction};

  if (   $transaction->[0]->{invoice}
      || $transaction->[0]->{ob_transaction}
      || $transaction->[0]->{cb_transaction}
      || (!scalar @{ $data{credit}->{entries} } && !scalar @{ $data{debit}->{entries} })
      || (   ($transaction->[0]->{module} eq 'gl')
          && (!scalar @{ $data{credit}->{entries} } || !scalar @{ $data{debit}->{entries} }))) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  my $retval = 0;

  my ($side, $other_side);
  if (   (grep { $_->{taxkey} * 1 } @{ $data{credit}->{entries} })
      || (scalar @{ $data{credit}->{tax_entries} })) {
    $side       = 'credit';
    $other_side = 'debit';

  } elsif (   (grep { $_->{taxkey} * 1 } @{ $data{debit}->{entries} })
           || (scalar @{ $data{debit}->{tax_entries} })) {
    $side       = 'debit';
    $other_side = 'credit';
  }

  if (!$side) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  my $expected_tax          = 0;
  my %num_entries_per_chart = ();
  my $num_taxed_entries     = 0;

  foreach my $entry (@{ $data{$side}->{entries} }) {
    my $taxinfo             = $params{all_taxes}->{taxkeys}->{$entry->{taxkey}} || { };
    $entry->{expected_tax}  = $entry->{amount} * $taxinfo->{taxrate};
    $expected_tax          += $entry->{expected_tax};

    $num_taxed_entries++ if ($taxinfo->{taxrate} * 1);

    my $chart_key = $entry->{chart_id} . "-" . $entry->{taxkey};
    $num_entries_per_chart{$chart_key} ||= 0;
    $num_entries_per_chart{$chart_key}++;
  }

#   $main::lxdebug->message(0, "side $side trans_id $transaction->[0]->{trans_id} expected tax $expected_tax actual tax $data{$side}->{tax_sum}");

  if (abs($expected_tax - $data{$side}->{tax_sum}) >= (0.01 * ($num_taxed_entries + 1))) {
    if ($params{full_analysis}) {
      my $storno_mult = $data{$side}->{entries}->[0]->{is_storno} ? -1 : 1;

      foreach my $entry (@{ $data{$other_side}->{entries} }) {
        $entry->{display_amount} = $form->round_amount(abs($entry->{amount}) * $storno_mult, 2);
      }

      foreach my $entry (@{ $data{$side}->{entries} }) {
        $entry->{actual_tax}              = $form->round_amount(abs($entry->{tax_entry} ? $entry->{tax_entry}->{amount} : 0), 2);
        $entry->{expected_tax}            = $form->round_amount(abs($entry->{expected_tax}), 2);
        $entry->{taxkey_error}            =    ( $entry->{taxkey} && !$entry->{tax_entry})
                                            || (!$entry->{taxkey} &&  $entry->{tax_entry})
                                            || (abs($entry->{expected_tax} - $entry->{actual_tax}) >= 0.02);
        $entry->{tax_entry_acc_trans_id}  = $entry->{tax_entry}->{acc_trans_id};
        delete $entry->{tax_entry};

        $entry->{display_amount}       = $form->round_amount(abs($entry->{amount}) * $storno_mult, 2);
        $entry->{display_actual_tax}   = $entry->{actual_tax}   * $storno_mult;
        $entry->{display_expected_tax} = $entry->{expected_tax} * $storno_mult;

        if ($entry->{taxkey_error}) {
          $self->{negative_taxkey_filter} ||= {
            'ar' => { map { $_ => 1 } (   8, 9, 18, 19) },
            'ap' => { map { $_ => 1 } (1, 2, 3, 12, 13) },
            'gl' => { },
          };

          $entry->{correct_taxkeys} = [];

          my %all_taxes = $self->{taxkeys}->get_full_tax_info('transdate' => $entry->{transdate});

          foreach my $taxkey (sort { $a <=> $b } keys %{ $all_taxes{taxkeys} }) {
            next if ($self->{negative_taxkey_filter}->{ $entry->{module} }->{$taxkey});

            my $tax_info = $all_taxes{taxkeys}->{$taxkey};

            next if ((!$tax_info || (0 == $tax_info->{taxrate} * 1)) && $entry->{tax_entry_acc_trans_id});

            push @{ $entry->{correct_taxkeys} }, {
              'taxkey'      => $taxkey,
              'tax'         => $form->round_amount(abs($entry->{amount}) * $tax_info->{taxrate}, 2),
              'description' => sprintf("%s %d%%", $tax_info->{taxdescription}, int($tax_info->{taxrate} * 100)),
            };
          }
        }
      }
    }

    if (first { $_ > 1 } values %num_entries_per_chart) {
      $params{problem}->{type} = 'wrong_taxkeys';
    } else {
      $params{problem}->{type} = 'wrong_taxes';
    }

    $params{problem}->{acc_trans} = { %data };
    push @{ $self->{problems} }, $params{problem};

    $retval = 1;
  }

  $main::lxdebug->leave_sub();

  return $retval;
}

# Inaktiver Code für das Erraten möglicher Verteilungen von
# Steuerschlüsseln. Deaktiviert, weil er exponentiell Zeit
# benötigt.

#       if (abs($expected_tax - $data{$side}->{tax_sum}) >= 0.02) {
#         my @potential_taxkeys = $trans_type eq 'AP' ? (0, 8, 9) : (0, 1, 2, 3);

#         $main::lxdebug->dump(0, "pota", \@potential_taxkeys);

#         # Über alle Kombinationen aus Buchungssätzen und potenziellen Steuerschlüsseln
#         # iterieren und jeweils die Summe ermitteln.
#         my $num_entries    = scalar @{ $data{$side}->{entries} };
#         my @taxkey_indices = (0) x $num_entries;

#         my @solutions      = ();

#         my $start_time     = time();

#         $main::lxdebug->message(0, "num_entries $num_entries");

#         while ($num_entries == scalar @taxkey_indices) {
#           my @tax_cache = ();

#           # Berechnen der Steuersumme für die aktuell angenommenen Steuerschlüssel.
#           my $tax_sum = 0;
#           foreach my $i (0 .. $num_entries - 1) {
#             my $taxkey      = $potential_taxkeys[$taxkey_indices[$i]];
#             my $entry       = $data{$side}->{entries}->[$i];
#             my $taxinfo     = $all_taxes{taxkeys}->{ $taxkey } || { };
#             $tax_cache[$i]  = $entry->{amount} * $taxinfo->{taxrate};
#             $tax_sum       += $tax_cache[$i];
#           }

#           # Entspricht die Steuersumme mit den aktuell angenommenen Steuerschlüsseln
#           # der verbuchten Steuersumme? Wenn ja, dann ist das eine potenzielle
#           # Lösung.
#           if (abs($tax_sum - $data{$side}->{tax_sum}) < 0.02) {
#             push @solutions, {
#               'taxkeys' => [ @potential_taxkeys[@taxkey_indices] ],
#               'taxes'   => [ @tax_cache ],
#             }
#           }

#           # Weiterzählen der Steuerschlüsselindices zum Interieren über
#           # alle möglichen Kombinationen.
#           my $i = 0;
#           while (1) {
#             $taxkey_indices[$i]++;
#             last if ($taxkey_indices[$i] < scalar @potential_taxkeys);

#             $taxkey_indices[$i] = 0;
#             $i++;
#           }

#           my $now = time();
#           if (($now - $start_time) >= 5) {
#             $main::lxdebug->message(0, "  " . join("", @taxkey_indices));
#             $start_time = $now;
#           }
#         }

#         foreach my $solution (@solutions) {
#           $solution->{rows}    = [];
#           $solution->{changes} = [];
#           my $error            = 0;

#           foreach my $i (0 .. $num_entries - 1) {
#             if ($solution->{taxes}->[$i]) {
#               my $tax_rounded          = $form->round_amount($solution->{taxes}->[$i] + $error, 2);
#               $error                   = $solution->{taxes}->[$i] + $error - $tax_rounded;
#               $solution->{taxes}->[$i] = $tax_rounded;
#             }

#             my $entry     = $data{$side}->{entries}->[$i];
#             my $tax_entry = $all_taxes{taxkeys}->{ $solution->{taxkeys}->[$i] };

#             push @{ $solution->{rows} }, {
#               %{ $entry },
#               %{ $tax_entry },
#               'taxamount' => $solution->{taxes}->[$i],
#             };

#             $solution->{rows}->[$i]->{taxdescription} .= ' ' . $form->format_amount(\%myconfig, $tax_entry->{taxrate} * 100) . ' %';

#             push @{ $solution->{changes} }, {
#               'acc_trans_id'    => $entry->{acc_trans_id},
#               'taxkey' => $solution->{taxkeys}->[$i],
#             };
#           }

#           push @{ $solution->{rows} }, @{ $data{$other_side}->{entries} };

#           delete @{ $solution }{ qw(taxes taxkeys) };
#         }

#         $problem->{type}      = 'wrong_taxkeys';
#         $problem->{solutions} = [ @solutions ];
#         $problem->{acc_trans} = { %data };
#         push @problems, $problem;

#         next;
#       }

sub analyze {
  $main::lxdebug->enter_sub();

  my $self         = shift;
  my %params       = @_;

  my $myconfig     = \%main::myconfig;
  my $form         = $main::form;

  my $dbh          = $params{dbh} || $form->get_standard_dbh($myconfig);

  my @transactions = $self->_fetch_transactions(%params, 'dbh' => $dbh);

  if (!scalar @transactions) {
    $main::lxdebug->leave_sub();
    return ();
  }

  my $callback = $params{callback} ? '&callback=' . $params{callback} : '';

  $self->{problems}                          = [];
  $self->{ap_ar_taxkey_problems}             = [];
  $self->{invoice_inventory_taxkey_problems} = [];

  foreach my $transaction (@transactions) {
    my %common_args = $self->_prepare_data('transaction' => $transaction, 'callback' => $callback, 'full_analysis' => $params{full_analysis});

    next if ($self->_check_trans_ap_ar_wrong_taxkeys(%common_args));
    next if ($self->_check_trans_invoices_inventory_with_taxkeys(%common_args));
    next if ($self->_check_trans_split_multiple_credit_and_debit(%common_args));
    next if ($self->_check_trans_wrong_taxkeys(%common_args));
  }

  my @problems = @{ $self->{problems} };

  map { $self->{$_} ||= [] } qw(ap_ar_taxkey_problems invoice_inventory_taxkey_problems missing_taxkeys_in_invoices);

  if (0 != scalar @{ $self->{ap_ar_taxkey_problems} }) {
    my $problem = {
      'type'        => 'ap_ar_wrong_taxkeys',
      'ap_problems' => [ grep { $_->{data}->{module} eq 'ap' } @{ $self->{ap_ar_taxkey_problems} } ],
      'ar_problems' => [ grep { $_->{data}->{module} eq 'ar' } @{ $self->{ap_ar_taxkey_problems} } ],
    };
    unshift @problems, $problem;
  }

  if (0 != scalar @{ $self->{invoice_inventory_taxkey_problems} }) {
    my $problem = {
      'type'        => 'invoice_inventory_with_taxkeys',
      'ap_problems' => [ grep { $_->{data}->{module} eq 'ap' } @{ $self->{invoice_inventory_taxkey_problems} } ],
      'ar_problems' => [ grep { $_->{data}->{module} eq 'ar' } @{ $self->{invoice_inventory_taxkey_problems} } ],
    };
    unshift @problems, $problem;
  }

  if (0 != scalar @{ $self->{missing_taxkeys_in_invoices} }) {
    my $problem = {
      'type'        => 'missing_taxkeys_in_invoices',
      'ap_problems' => [ grep { $_->{data}->{module} eq 'ap' } @{ $self->{missing_taxkeys_in_invoices} } ],
      'ar_problems' => [ grep { $_->{data}->{module} eq 'ar' } @{ $self->{missing_taxkeys_in_invoices} } ],
    };
    unshift @problems, $problem;
  }

  $main::lxdebug->leave_sub();

#  $::lxdebug->dump(0, 'problems:', \@problems);

  return @problems;
}

sub fix_ap_ar_wrong_taxkeys {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  my $query    = qq|SELECT 'ap' AS module,
                      at.acc_trans_id, at.trans_id, at.chart_id, at.amount, at.taxkey, at.transdate,
                      c.link
                    FROM acc_trans at
                    LEFT JOIN chart c ON (at.chart_id = c.id)
                    WHERE (trans_id IN (SELECT id FROM ap WHERE NOT invoice))
                      AND (taxkey IN (2, 3, 12, 13))

                    UNION

                    SELECT 'ar' AS module,
                      at.acc_trans_id, at.trans_id, at.chart_id, at.amount, at.taxkey, at.transdate,
                      c.link
                    FROM acc_trans at
                    LEFT JOIN chart c ON (at.chart_id = c.id)
                    WHERE (trans_id IN (SELECT id FROM ar WHERE NOT invoice))
                      AND (taxkey IN (8, 9, 18, 19))

                    ORDER BY trans_id, acc_trans_id|;

  my $sth      = prepare_execute_query($form, $dbh, $query);
  my @transactions;

  while (my $ref = $sth->fetchrow_hashref()) {
    if ((!scalar @transactions) || ($ref->{trans_id} != $transactions[-1]->[0]->{trans_id})) {
      push @transactions, [];
    }

    push @{ $transactions[-1] }, $ref;
  }

  $sth->finish();

  @transactions = grep { (scalar(@transactions) % 2) == 0 } @transactions;

  my %taxkey_replacements = (
     2 =>  8,
     3 =>  9,
     8 =>  2,
     9 =>  3,
    12 => 18,
    13 => 19,
    18 => 12,
    19 => 13,
    );

  my %bad_taxkeys = (
    'ap' => { map { $_ => 1 } (2, 3, 12, 13) },
    'ar' => { map { $_ => 1 } (8, 9, 18, 19) },
    );

  my @corrections = ();

  foreach my $transaction (@transactions) {

    for (my $i = 0; $i < scalar @{ $transaction }; $i += 2) {
      my ($non_tax_idx, $tax_idx) = abs($transaction->[$i]->{amount}) > abs($transaction->[$i + 1]->{amount}) ? ($i, $i + 1) : ($i + 1, $i);
      my ($non_tax,     $tax)     = @{ $transaction }[$non_tax_idx, $tax_idx];

      last if ($non_tax->{link} =~ m/(:?AP|AR)_tax(:?$|:)/);
      last if ($tax->{link}     !~ m/(:?AP|AR)_tax(:?$|:)/);

      next if (!$bad_taxkeys{ $non_tax->{module} }->{ $non_tax->{taxkey} });

      my %all_taxes = $self->{taxkeys}->get_full_tax_info('transdate' => $non_tax->{transdate});

      push @corrections, ({ 'acc_trans_id' => $non_tax->{acc_trans_id},
                            'taxkey'       => $taxkey_replacements{$non_tax->{taxkey}},
                          },
                          {
                            'acc_trans_id' => $tax->{acc_trans_id},
                            'taxkey'       => $taxkey_replacements{$non_tax->{taxkey}},
                            'chart_id'     => $all_taxes{taxkeys}->{ $taxkey_replacements{$non_tax->{taxkey}} }->{taxchart_id},
                          });
    }
  }

  if (scalar @corrections) {
    SL::DB->client->with_transaction(sub {
      my $q_taxkey_only     = qq|UPDATE acc_trans SET taxkey = ? WHERE acc_trans_id = ?|;
      my $h_taxkey_only     = prepare_query($form, $dbh, $q_taxkey_only);

      my $q_taxkey_chart_id = qq|UPDATE acc_trans SET taxkey = ?, chart_id = ? WHERE acc_trans_id = ?|;
      my $h_taxkey_chart_id = prepare_query($form, $dbh, $q_taxkey_chart_id);

      foreach my $entry (@corrections) {
        if ($entry->{chart_id}) {
          do_statement($form, $h_taxkey_chart_id, $q_taxkey_chart_id, $entry->{taxkey}, $entry->{chart_id}, $entry->{acc_trans_id});
        } else {
          do_statement($form, $h_taxkey_only, $q_taxkey_only, $entry->{taxkey}, $entry->{acc_trans_id});
        }
      }

      $h_taxkey_only->finish();
      $h_taxkey_chart_id->finish();
      1;
    }) or do { die SL::DB->client->error };
  }

  $main::lxdebug->leave_sub();
}

sub fix_invoice_inventory_with_taxkeys {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  # ist nur für bestandsmethode notwendig. bei der Aufwandsmethode
  # können Warenkonten mit Steuerschlüssel sein (5400 in SKR04)
  return 0 if $::instance_conf->get_inventory_system eq 'periodic';

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  my $query    = qq|SELECT at.*, c.link
                    FROM acc_trans at
                    LEFT JOIN ar      ON (at.trans_id = ar.id)
                    LEFT JOIN chart c ON (at.chart_id = c.id)
                    WHERE (ar.invoice)

                    UNION

                    SELECT at.*, c.link
                    FROM acc_trans at
                    LEFT JOIN ap      ON (at.trans_id = ap.id)
                    LEFT JOIN chart c ON (at.chart_id = c.id)
                    WHERE (ap.invoice)

                    ORDER BY trans_id, acc_trans_id|;

  my $sth      = prepare_execute_query($form, $dbh, $query);
  my @transactions;

  while (my $ref = $sth->fetchrow_hashref()) {
    if ((!scalar @transactions) || ($ref->{trans_id} != $transactions[-1]->[0]->{trans_id})) {
      push @transactions, [];
    }

    push @{ $transactions[-1] }, $ref;
  }

  $sth->finish();

  my @corrections = ();

  foreach my $transaction (@transactions) {
    my @sub_transactions = $self->_group_sub_transactions($transaction);

    foreach my $sub_transaction (@sub_transactions) {
      my $is_cogs = first { $_->{link} =~ m/IC_cogs/ } @{ $sub_transaction };
      next unless ($is_cogs);

      foreach my $entry (@{ $sub_transaction }) {
        next if ($entry->{taxkey} == 0);
        push @corrections, $entry->{acc_trans_id};
      }
    }
  }

  if (@corrections) {
    SL::DB->client->with_transaction(sub {
      $query = qq|UPDATE acc_trans SET taxkey = 0 WHERE acc_trans_id = ?|;
      $sth   = prepare_query($form, $dbh, $query);

      foreach my $acc_trans_id (@corrections) {
        do_statement($form, $sth, $query, $acc_trans_id);
      }

      $sth->finish();
      1;
    }) or do { die SL::DB->client->error };
  }

  $main::lxdebug->leave_sub();
}

sub fix_wrong_taxkeys {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(fixes));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  SL::DB->client->with_transaction(sub {
    my $q_taxkey_only  = qq|UPDATE acc_trans SET taxkey = ? WHERE acc_trans_id = ?|;
    my $h_taxkey_only  = prepare_query($form, $dbh, $q_taxkey_only);

    my $q_taxkey_chart = qq|UPDATE acc_trans SET taxkey = ?, chart_id = ? WHERE acc_trans_id = ?|;
    my $h_taxkey_chart = prepare_query($form, $dbh, $q_taxkey_chart);

    my $q_transdate    = qq|SELECT transdate FROM acc_trans WHERE acc_trans_id = ?|;
    my $h_transdate    = prepare_query($form, $dbh, $q_transdate);

    foreach my $fix (@{ $params{fixes} }) {
      next unless ($fix->{acc_trans_id});

      do_statement($form, $h_taxkey_only, $q_taxkey_only, conv_i($fix->{taxkey}), conv_i($fix->{acc_trans_id}));

      next unless ($fix->{tax_entry_acc_trans_id});

      do_statement($form, $h_transdate, $q_transdate, conv_i($fix->{tax_entry_acc_trans_id}));
      my ($transdate) = $h_transdate->fetchrow_array();

      my %all_taxes = $self->{taxkeys}->get_full_tax_info('transdate' => $transdate);
      my $tax_info  = $all_taxes{taxkeys}->{ $fix->{taxkey} };

      next unless ($tax_info);

      do_statement($form, $h_taxkey_chart, $q_taxkey_chart, conv_i($fix->{taxkey}), conv_i($tax_info->{taxchart_id}), conv_i($fix->{tax_entry_acc_trans_id}));
    }

    $h_taxkey_only->finish();
    $h_taxkey_chart->finish();
    $h_transdate->finish();
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub delete_transaction {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(trans_id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  SL::DB->client->with_transaction(sub {
    do_query($form, $dbh, qq|UPDATE ar SET storno_id = NULL WHERE storno_id = ?|, conv_i($params{trans_id}));
    do_query($form, $dbh, qq|UPDATE ap SET storno_id = NULL WHERE storno_id = ?|, conv_i($params{trans_id}));
    do_query($form, $dbh, qq|UPDATE gl SET storno_id = NULL WHERE storno_id = ?|, conv_i($params{trans_id}));

    do_query($form, $dbh, qq|DELETE FROM ar        WHERE id       = ?|, conv_i($params{trans_id}));
    do_query($form, $dbh, qq|DELETE FROM ap        WHERE id       = ?|, conv_i($params{trans_id}));
    do_query($form, $dbh, qq|DELETE FROM gl        WHERE id       = ?|, conv_i($params{trans_id}));
    do_query($form, $dbh, qq|DELETE FROM acc_trans WHERE trans_id = ?|, conv_i($params{trans_id}));
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

1;
