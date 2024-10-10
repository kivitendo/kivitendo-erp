package SL::LiquidityProjection;

use strict;

use List::MoreUtils qw(uniq);

use SL::DBUtils;
use SL::Helper::DateTime;
use SL::DB::PeriodicInvoicesConfig;

sub new {
  my $package       = shift;
  my $self          = bless {}, $package;

  my %params        = @_;

  $self->{params}   = \%params;

  my @now           = localtime;
  my $now_year      = $now[5] + 1900;
  my $now_month     = $now[4] + 1;

  $self->{min_date} = _the_date($now_year, $now_month);
  $self->{max_date} = _the_date($now_year, $now_month + $params{months} - 1);

  $self;
}

# Algorithmus:
#
# Für den aktuellen Monat und alle x Folgemonate soll der geplante
# Liquiditätszufluss aufgeschlüsselt werden. Der Zufluss berechnet
# sich dabei aus:
#
# 1. Summe aller offenen Auträge
#
# 2. abzüglich aller zu diesen Aufträgen erstellten Rechnungen
# (Teillieferungen/Teilrechnungen)
#
# 3. zuzüglich alle aktiven Wartungsverträge, die in dem jeweiligen
# Monat ihre Saldierungsperiode haben, außer Wartungsverträgen, die
# für den jeweiligen Monat bereits abgerechnet wurden.
#
# Diese Werte sollen zusätzlich optional nach Verkäufer(in),
# Buchungsgruppe und Warengruppe aufgeschlüsselt werden.
#
# Diese Lösung geht deshalb immer über die Positionen der Belege
# (wegen der Buchungsgruppen & Warengruppen) und berechnet die Summen
# daraus manuell.
#
# Alle Aufträge, deren Lieferdatum leer ist, oder deren Lieferdatum
# vor dem aktuellen Monat liegt, werden in einer Kategorie 'alt'
# zusammengefasst.
#
# Alle Aufträge, deren Lieferdatum nach dem zu betrachtenden Zeitraum
# (aktueller Monat + x Monate) liegen, werden in einer Kategorie
# 'Zukunft' zusammengefasst.
#
# Insgesamt läuft es wie folgt ab:
#
# 1. Es wird das Datum aller periodisch erzeugten Rechnungen innerhalb
# des Betrachtungszeitraumes herausgesucht.
#
# 2. Alle aktiven Wartungsvertragskonfigurationen werden
# ausgelesen. Die Saldierungsmonate werden solange aufaddiert, wie der
# dabei herauskommende Monat nicht nach dem zu betrachtenden Zeitraum
# liegt.
#
# 3. Für jedes Saldierungsintervall, das innerhalb des
# Betrachtungszeitraumes liegt, und für das es für den Monat noch
# keine Rechnung gibt (siehe 1.), wird diese Konfiguration für den
# Monat vorgemerkt.
#
# 4. Es werden für alle offenen Kundenaufträge die Positionen
# ausgelesen und mit Verkäufer(in), Buchungsgruppe, Warengruppe
# verknüpft. Aus Menge, Einzelpreis und Zeilenrabatt wird die
# Zeilensumme berechnet.
#
# 5. Mit den Informationen aus 3. und 4. werden Datenstrukturen
# initialisiert, die für die Gesamtsummen, für alle Verkäufer(innen),
# für alle Buchungsgruppen, für alle Warengruppen, für alle Monate
# Werte enthalten.
#
# 6. Es wird über alle Einträge aus 4. iteriert. Die Zeilensummen
# werden in den entsprechenden Datenstrukturen aus 5. addiert.
#
# 7. Es wird über alle Einträge aus 3. iteriert. Die Zeilensummen
# werden in den entsprechenden Datenstrukturen aus 5. addiert.
#
# 8. Es werden alle Rechnungspositionen ausgelesen, bei denen die
# Auftragsnummer einer der aus 5. ermittelten Aufträge entspricht.
#
# 9. Es wird über alle Einträge aus 8. iteriert. Die Zeilensummen
# werden von den entsprechenden Datenstrukturen aus 5. abgezogen. Als
# Datum wird dabei das Datum des zu der Rechnung gehörenden Auftrages
# genommen. Als Buchungsgruppe wird die Buchungsgruppe der Zeile
# genommen. Falls es passieren sollte, dass diese Buchungsgruppe in
# den Aufträgen nie vorgekommen ist (sprich Rechnung enthält
# Positionen, die im Auftrag nicht enthalten sind, und die komplett
# andere Buchungsgruppen verwenden), so wird schlicht die allererste
# in 4. gefundene Buchungsgruppe damit belastet. Analog passiert dies
# auch für Warengruppen.

sub create {
  my ($self)   = @_;
  my %params   = %{ $self->{params} };

  my $dbh      = $params{dbh} || $::form->get_standard_dbh;
  my ($sth, $ref, $query);

  $params{months} ||= 6;

  my @scentries;

  # 1. Auslesen aller erzeugten periodischen Rechnungen im Betrachtungszeitraum
  my $configs = SL::DB::Manager::PeriodicInvoicesConfig->get_all(query => [ active => 1 ]);
  foreach my $config (@{ $configs }) {
    my $open_orders = $config->get_open_orders_for_period(
      end_date => DateTime->from_ymd(
        $self->{max_date} . '-01'
      )->add(months => 1, days => -1)
    );
    foreach my $order (@$open_orders) {
      my $month_date = _the_date($order->reqdate->year, $order->reqdate->month);
      foreach my $order_item ($order->items()) {
        push @scentries, {
          buchungsgruppe => $order_item->part->buchungsgruppe->description,
          salesman       => $order->salesman ? $order->salesman->name : $order->employee->name,
          linetotal      => $order_item->qty * (1 - $order_item->discount) * $order_item->sellprice,
          date           => $month_date,
          parts_group    => $order_item->part->partsgroup,
        };
      }
    }
  }

  # 2. Auslesen offener Aufträge
  $query = <<SQL;
    SELECT (oi.qty * (1 - oi.discount) * oi.sellprice) AS linetotal,
      bg.description AS buchungsgruppe,
      pg.partsgroup AS parts_group,
      CASE WHEN COALESCE(e.name, '') = '' THEN e.login ELSE e.name END AS salesman,
      oe.ordnumber, EXTRACT(month FROM oe.reqdate) AS month, EXTRACT(year  FROM oe.reqdate) AS year
    FROM orderitems oi
    LEFT JOIN oe                 ON (oi.trans_id                              = oe.id)
    LEFT JOIN parts p            ON (oi.parts_id                              = p.id)
    LEFT JOIN buchungsgruppen bg ON (p.buchungsgruppen_id                     = bg.id)
    LEFT JOIN partsgroup pg      ON (p.partsgroup_id                          = pg.id)
    LEFT JOIN employee e         ON (COALESCE(oe.salesman_id, oe.employee_id) = e.id)
    WHERE oe.record_type = 'sales_order'
      AND NOT COALESCE(oe.closed,    FALSE)
      AND (oe.id NOT IN (SELECT oe_id FROM periodic_invoices_configs))
SQL

  # 3. Initialisierung der Datenstrukturen zum Speichern der
  # Ergebnisse
  my @entries               = selectall_hashref_query($::form, $dbh, $query);
  my @salesmen              = uniq map { $_->{salesman}       } (@entries, @scentries);
  my @buchungsgruppen       = uniq map { $_->{buchungsgruppe} } (@entries, @scentries);
  my @parts_groups          = uniq map { $_->{parts_group}    } (@entries, @scentries);
  my @now                   = localtime;
  my @dates                 = map { $self->_date_for($now[5] + 1900, $now[4] + $_) } (0..$self->{params}->{months} + 1);
  my %dates_by_ordnumber    = map { $_->{ordnumber} => $self->_date_for($_) } @entries;
  my %salesman_by_ordnumber = map { $_->{ordnumber} => $_->{salesman}       } @entries;
  my %date_sorter           = ( old => '0000-00', future => '9999-99' );

  my $projection    = { total          =>               { map { $_ => 0 } @dates },
                        order          =>               { map { $_ => 0 } @dates },
                        partial        =>               { map { $_ => 0 } @dates },
                        support        =>               { map { $_ => 0 } @dates },
                        salesman       => { map { $_ => { map { $_ => 0 } @dates } } @salesmen        },
                        buchungsgruppe => { map { $_ => { map { $_ => 0 } @dates } } @buchungsgruppen },
                        parts_group    => { map { $_ => { map { $_ => 0 } @dates } } @parts_groups    },
                        sorted         => { month          => [ sort { ($date_sorter{$a} || $a) cmp ($date_sorter{$b} || $b) } @dates           ],
                                            salesman       => [ sort { $a                       cmp $b                       } @salesmen        ],
                                            buchungsgruppe => [ sort { $a                       cmp $b                       } @buchungsgruppen ],
                                            parts_group    => [ sort { $a                       cmp $b                       } @parts_groups    ],
                                            type           => [ qw(order partial support)                                                       ],
                                          },
                      };

  # 4. Aufsummieren der Auftragspositionen
  foreach $ref (@entries) {
    my $date = $self->_date_for($ref);

    $projection->{total}->{$date}                                      += $ref->{linetotal};
    $projection->{order}->{$date}                                      += $ref->{linetotal};
    $projection->{salesman}->{ $ref->{salesman} }->{$date}             += $ref->{linetotal};
    $projection->{buchungsgruppe}->{ $ref->{buchungsgruppe} }->{$date} += $ref->{linetotal};
    $projection->{parts_group}->{ $ref->{parts_group} }->{$date}       += $ref->{linetotal};
  }

  # 5. Aufsummieren der Wartungsvertragspositionen
  foreach $ref (@scentries) {
    my $date = $ref->{date};

    $projection->{total}->{$date}                                      += $ref->{linetotal};
    $projection->{support}->{$date}                                    += $ref->{linetotal};
    $projection->{salesman}->{ $ref->{salesman} }->{$date}             += $ref->{linetotal};
    $projection->{buchungsgruppe}->{ $ref->{buchungsgruppe} }->{$date} += $ref->{linetotal};
    $projection->{parts_group}->{ $ref->{parts_group} }->{$date}       += $ref->{linetotal};
  }

  if (%dates_by_ordnumber) {
    # 8. Auslesen von Positionen von Teilrechnungen zu Aufträgen
    my $ordnumbers = join ', ', map { $dbh->quote($_) } keys %dates_by_ordnumber;
    $query         = <<SQL;
      SELECT (i.qty * (1 - i.discount) * i.sellprice) AS linetotal,
        bg.description AS buchungsgruppe,
        pg.partsgroup AS parts_group,
        ar.ordnumber
      FROM invoice i
      LEFT JOIN ar                 ON (i.trans_id           = ar.id)
      LEFT JOIN parts p            ON (i.parts_id           = p.id)
      LEFT JOIN buchungsgruppen bg ON (p.buchungsgruppen_id = bg.id)
      LEFT JOIN partsgroup pg      ON (p.partsgroup_id      = pg.id)
      WHERE (ar.ordnumber IN ($ordnumbers))
SQL

    @entries = selectall_hashref_query($::form, $dbh, $query);

    # 9. Abziehen der abgerechneten Positionen
    foreach $ref (@entries) {
      my $date           = $dates_by_ordnumber{    $ref->{ordnumber} } || die;
      my $salesman       = $salesman_by_ordnumber{ $ref->{ordnumber} } || die;
      my $buchungsgruppe = $projection->{buchungsgruppe}->{ $ref->{buchungsgruppe} } ? $ref->{buchungsgruppe} : $buchungsgruppen[0];
      my $parts_group    = $projection->{parts_group}->{    $ref->{parts_group}    } ? $ref->{parts_group}    : $parts_groups[0];

      $projection->{partial}->{$date}                           -= $ref->{linetotal};
      $projection->{total}->{$date}                             -= $ref->{linetotal};
      $projection->{salesman}->{$salesman}->{$date}             -= $ref->{linetotal};
      $projection->{buchungsgruppe}->{$buchungsgruppe}->{$date} -= $ref->{linetotal};
      $projection->{parts_group}->{$parts_group}->{$date}       -= $ref->{linetotal};
    }
  }

  return $projection;
}

# Skaliert '$year' und '$month' so, dass 1 <= Monat <= 12 gilt. Zum
# Einfachen Addieren gedacht, z.B.
#
# my ($new_year, $new_month) = _fix_date($old_year, $old_month + 6);

sub _fix_date {
  my $year   = shift;
  my $month  = shift;

  $year     += int(($month - 1) / 12);
  $month     = (($month - 1) % 12 ) + 1;

  ($year, $month);
}

# Formartiert Jahr & Monat wie benötigt.

sub _the_date {
  sprintf '%04d-%02d', _fix_date(@_);
}

# Mappt Datum auf Kategorie. Ist das Datum leer, oder liegt es vor dem
# Betrachtungszeitraum, so ist die Kategorie 'old'. Liegt das Datum
# nach dem Betrachtungszeitraum, so ist die Kategorie
# 'future'. Andernfalls ist sie das formartierte Datum selber.

sub _date_for {
  my $self = shift;
  my $ref  = ref $_[0] eq 'HASH' ? shift : { year => $_[0], month => $_[1] };

  return 'old' if !$ref->{year} || !$ref->{month};

  my $date = _the_date($ref->{year}, $ref->{month});

    $date lt $self->{min_date} ? 'old'
  : $date gt $self->{max_date} ? 'future'
  :                              $date;
}

sub orders_for_time_period {
  my ($class, %params) = @_;

  my $dbh = SL::DB::Order->new->db->dbh;

  my @recurring_orders;

  # 1. Alle aktiven Konfigurationen für wiederkehrende Rechnungen auslesen.

  my $configs = SL::DB::Manager::PeriodicInvoicesConfig->get_all(where => [ active => 1 ]);

  my %calc_params;
  $calc_params{start_date} = $params{after}->clone                   if $params{after};
  $calc_params{end_date}   = $params{before}->clone->add(days => -1) if $params{before};
  $calc_params{end_date} //= $calc_params{start_date}->clone->add(years => 1);

  foreach my $config (@{ $configs }) {

    my $rec_orders = $config->get_open_orders_for_period(%calc_params);
    next unless scalar $rec_orders;

    $_->{is_recurring} = 1 for @$rec_orders;

    push @recurring_orders, @$rec_orders;
  }

  my @where = (
    record_type    => 'sales_order',
    or             => [ closed    => undef, closed    => 0, ],
  );
  push @where, (reqdate => { ge => $params{after}->clone })  if $params{after};
  push @where, (reqdate => { lt => $params{before}->clone }) if $params{before};
  push @where, '!id' => [ map { $_->id } @recurring_orders ] if @recurring_orders;

  # 1. Auslesen aller offenen Aufträge, deren Lieferdatum im
  # gewünschten Bereich liegt
  my $regular_orders = SL::DB::Manager::Order->get_all(
    where        => \@where,
    with_objects => [ qw(customer employee) ],
  );

  return sort {
         ($a->transdate          <=> $b->transdate)
      || ($a->reqdate            <=> $b->reqdate)
      || (lc($a->customer->name) cmp lc($b->customer->name))
  } (@recurring_orders, @{ $regular_orders });
}

1;
