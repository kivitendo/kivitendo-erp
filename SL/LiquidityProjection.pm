package SL::LiquidityProjection;

use strict;

use List::MoreUtils qw(uniq);

use SL::DBUtils;
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
# Diese Werte sollen zusätzlich optional nach Verkäufer(in) und nach
# Buchungsgruppe aufgeschlüsselt werden.
#
# Diese Lösung geht deshalb immer über die Positionen der Belege
# (wegen der Buchungsgruppe) und berechnet die Summen daraus manuell.
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
# ausgelesen und mit Verkäufer(in), Buchungsgruppe verknüpft. Aus
# Menge, Einzelpreis und Zeilenrabatt wird die Zeilensumme berechnet.
#
# 5. Mit den Informationen aus 3. und 4. werden Datenstrukturen
# initialisiert, die für die Gesamtsummen, für alle Verkäufer(innen),
# für alle Buchungsgruppen, für alle Monate Werte enthalten.
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
# in 4. gefundene Buchungsgruppe damit belastet.

sub create {
  my ($self)   = @_;
  my %params   = %{ $self->{params} };

  my $dbh      = $params{dbh} || $::form->get_standard_dbh;
  my ($sth, $ref, $query);

  $params{months} ||= 6;

  # 1. Auslesen aller erzeugten periodischen Rechnungen im
  # Betrachtungszeitraum
  my $q_min_date = $dbh->quote($self->{min_date} . '-01');
  $query         = <<SQL;
    SELECT pi.config_id, to_char(pi.period_start_date, 'YYYY-MM') AS period_start_date
    FROM periodic_invoices pi
    LEFT JOIN periodic_invoices_configs pcfg ON (pi.config_id = pcfg.id)
    WHERE pcfg.active
      AND NOT pcfg.periodicity = 'o'
      AND (pi.period_start_date >= to_date($q_min_date, 'YYYY-MM-DD'))
SQL

  my %periodic_invoices;
  $sth = prepare_execute_query($::form, $dbh, $query);
  while ($ref = $sth->fetchrow_hashref) {
    $periodic_invoices{ $ref->{config_id} }                                ||= { };
    $periodic_invoices{ $ref->{config_id} }->{ $ref->{period_start_date} }   = 1;
  }
  $sth->finish;

  # 2. Auslesen aktiver Wartungsvertragskonfigurationen
  $query = <<SQL;
    SELECT (oi.qty * (1 - oi.discount) * oi.sellprice) AS linetotal,
      bg.description AS buchungsgruppe,
      CASE WHEN COALESCE(e.name, '') = '' THEN e.login ELSE e.name END AS salesman,
      pcfg.periodicity, pcfg.order_value_periodicity, pcfg.id AS config_id,
      EXTRACT(year FROM pcfg.start_date) AS start_year, EXTRACT(month FROM pcfg.start_date) AS start_month
    FROM orderitems oi
    LEFT JOIN oe                             ON (oi.trans_id                              = oe.id)
    LEFT JOIN periodic_invoices_configs pcfg ON (oi.trans_id                              = pcfg.oe_id)
    LEFT JOIN parts p                        ON (oi.parts_id                              = p.id)
    LEFT JOIN buchungsgruppen bg             ON (p.buchungsgruppen_id                     = bg.id)
    LEFT JOIN employee e                     ON (COALESCE(oe.salesman_id, oe.employee_id) = e.id)
    WHERE pcfg.active
      AND NOT pcfg.periodicity = 'o'
SQL

  # 3. Iterieren über Saldierungsintervalle, vormerken
  my @scentries;
  $sth = prepare_execute_query($::form, $dbh, $query);
  while ($ref = $sth->fetchrow_hashref) {
    my ($year, $month) = ($ref->{start_year}, $ref->{start_month});
    my $date;

    while (($date = _the_date($year, $month)) le $self->{max_date}) {
      my $billing_len = $SL::DB::PeriodicInvoicesConfig::PERIOD_LENGTHS{ $ref->{periodicity} } || 1;

      if (($date ge $self->{min_date}) && (!$periodic_invoices{ $ref->{config_id} } || !$periodic_invoices{ $ref->{config_id} }->{$date})) {
        my $order_value_periodicity = $ref->{order_value_periodicity} eq 'p' ? $ref->{periodicity} : $ref->{order_value_periodicity};
        my $order_value_len         = $SL::DB::PeriodicInvoicesConfig::ORDER_VALUE_PERIOD_LENGTHS{$order_value_periodicity} || 1;

        push @scentries, { buchungsgruppe => $ref->{buchungsgruppe},
                           salesman       => $ref->{salesman},
                           linetotal      => $ref->{linetotal} * $billing_len / $order_value_len,
                           date           => $date,
                         };
      }

      ($year, $month) = _fix_date($year, $month + $billing_len);
    }
  }
  $sth->finish;

  # 4. Auslesen offener Aufträge
  $query = <<SQL;
    SELECT (oi.qty * (1 - oi.discount) * oi.sellprice) AS linetotal,
      bg.description AS buchungsgruppe,
      CASE WHEN COALESCE(e.name, '') = '' THEN e.login ELSE e.name END AS salesman,
      oe.ordnumber, EXTRACT(month FROM oe.reqdate) AS month, EXTRACT(year  FROM oe.reqdate) AS year
    FROM orderitems oi
    LEFT JOIN oe                 ON (oi.trans_id                              = oe.id)
    LEFT JOIN parts p            ON (oi.parts_id                              = p.id)
    LEFT JOIN buchungsgruppen bg ON (p.buchungsgruppen_id                     = bg.id)
    LEFT JOIN employee e         ON (COALESCE(oe.salesman_id, oe.employee_id) = e.id)
    WHERE (oe.customer_id IS NOT NULL)
      AND NOT COALESCE(oe.quotation, FALSE)
      AND NOT COALESCE(oe.closed,    FALSE)
      AND (oe.id NOT IN (SELECT oe_id FROM periodic_invoices_configs WHERE periodicity <> 'o'))
SQL

  # 5. Initialisierung der Datenstrukturen zum Speichern der
  # Ergebnisse
  my @entries               = selectall_hashref_query($::form, $dbh, $query);
  my @salesmen              = uniq map { $_->{salesman}       } (@entries, @scentries);
  my @buchungsgruppen       = uniq map { $_->{buchungsgruppe} } (@entries, @scentries);
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
                        sorted         => { month          => [ sort { ($date_sorter{$a} || $a) cmp ($date_sorter{$b} || $b) } @dates           ],
                                            salesman       => [ sort { $a                       cmp $b                       } @salesmen        ],
                                            buchungsgruppe => [ sort { $a                       cmp $b                       } @buchungsgruppen ],
                                            type           => [ qw(order partial support)                                                       ],
                                          },
                      };

  # 6. Aufsummieren der Auftragspositionen
  foreach $ref (@entries) {
    my $date = $self->_date_for($ref);

    $projection->{total}->{$date}                                      += $ref->{linetotal};
    $projection->{order}->{$date}                                      += $ref->{linetotal};
    $projection->{salesman}->{ $ref->{salesman} }->{$date}             += $ref->{linetotal};
    $projection->{buchungsgruppe}->{ $ref->{buchungsgruppe} }->{$date} += $ref->{linetotal};
  }

  # 7. Aufsummieren der Wartungsvertragspositionen
  foreach $ref (@scentries) {
    my $date = $ref->{date};

    $projection->{total}->{$date}                                      += $ref->{linetotal};
    $projection->{support}->{$date}                                    += $ref->{linetotal};
    $projection->{salesman}->{ $ref->{salesman} }->{$date}             += $ref->{linetotal};
    $projection->{buchungsgruppe}->{ $ref->{buchungsgruppe} }->{$date} += $ref->{linetotal};
  }

  if (%dates_by_ordnumber) {
    # 8. Auslesen von Positionen von Teilrechnungen zu Aufträgen
    my $ordnumbers = join ', ', map { $dbh->quote($_) } keys %dates_by_ordnumber;
    $query         = <<SQL;
      SELECT (i.qty * (1 - i.discount) * i.sellprice) AS linetotal,
        bg.description AS buchungsgruppe,
        ar.ordnumber
      FROM invoice i
      LEFT JOIN ar                 ON (i.trans_id           = ar.id)
      LEFT JOIN parts p            ON (i.parts_id           = p.id)
      LEFT JOIN buchungsgruppen bg ON (p.buchungsgruppen_id = bg.id)
      WHERE (ar.ordnumber IN ($ordnumbers))
SQL

    @entries = selectall_hashref_query($::form, $dbh, $query);

    # 9. Abziehen der abgerechneten Positionen
    foreach $ref (@entries) {
      my $date           = $dates_by_ordnumber{    $ref->{ordnumber} } || die;
      my $salesman       = $salesman_by_ordnumber{ $ref->{ordnumber} } || die;
      my $buchungsgruppe = $projection->{buchungsgruppe}->{ $ref->{buchungsgruppe} } ? $ref->{buchungsgruppe} : $buchungsgruppen[0];

      $projection->{partial}->{$date}                           -= $ref->{linetotal};
      $projection->{total}->{$date}                             -= $ref->{linetotal};
      $projection->{salesman}->{$salesman}->{$date}             -= $ref->{linetotal};
      $projection->{buchungsgruppe}->{$buchungsgruppe}->{$date} -= $ref->{linetotal};
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

1;
