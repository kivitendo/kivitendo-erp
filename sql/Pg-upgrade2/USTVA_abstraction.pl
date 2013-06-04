# @tag: USTVA_abstraction
# @description: Abstraktion der USTVA Report Daten. Dies vereinfacht die Integration von Steuerberichten anderer Nationen in kivitendo.
# @depends: release_2_4_2
package SL::DBUpgrade2::USTVA_abstraction;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

# Abstraktionlayer between general Taxreports and USTVA
# Most of the data and structures are not used yet, but maybe in future,
# if there are other international customizings are requested...

###################

sub create_tables {
  my ($self) = @_;

  # Watch out, SCHEMAs are new in Lx!
  my @queries = ( # Watch out, it's a normal array!
      q{ CREATE SCHEMA tax;
      },
      q{ CREATE TABLE tax.report_categorys (
           id              integer NOT NULL PRIMARY KEY,
           description     text,
           subdescription  text
         );
      },
      q{ CREATE TABLE tax.report_headings (
           id              integer NOT NULL PRIMARY KEY,
           category_id     integer NOT NULL REFERENCES tax.report_categorys(id),
           type            text,
           description     text,
           subdescription  text
         );
      },
      q{ CREATE TABLE tax.report_variables (
           id            integer NOT NULL PRIMARY KEY,
           position      text NOT NULL,
           heading_id    integer REFERENCES tax.report_headings(id),
           description   text,
           taxbase       text,
           dec_places    text,
           valid_from    date
         );
      },
  );

  $self->db_query("DROP SCHEMA tax CASCADE;", may_fail => 1);
  $self->db_query($_) for @queries;

  return 1;

}

sub do_copy {
  my ($self) = @_;

  my @copy_statements = (
    "INSERT INTO tax.report_categorys (id, description, subdescription) VALUES (?, ?, ?)",
    "INSERT INTO tax.report_headings (id, category_id, type, description, subdescription) VALUES (?, ?, ?, ?, ?)",
    "INSERT INTO tax.report_variables (id, position, heading_id, description, taxbase, dec_places, valid_from) VALUES (?, ?, ?, ?, ?, ?, ?)",
  );

  my @copy_data = (
    [ "0;;",
      "1;Lieferungen und sonstige Leistungen;(einschließlich unentgeltlicher Wertabgaben)",
      "2;Innergemeinschaftliche Erwerbe;",
      "3;Ergänzende Angaben zu Umsätzen;",
      "99;Summe;",
    ],
    ["0;0;;;",
     "1;1;received;Steuerfreie Umsätze mit Vorsteuerabzug;",
     "2;1;recieved;Steuerfreie Umsätze ohne Vorsteuerabzug;",
     "3;1;recieved;Steuerpflichtige Umsätze;(Lieferungen und sonstige Leistungen einschl. unentgeltlicher Wertabgaben)",
     "4;2;recieved;Steuerfreie innergemeinschaftliche Erwerbe;",
     "5;2;recieved;Steuerpflichtige innergemeinschaftliche Erwerbe;",
     "6;3;recieved;Umsätze, für die als Leistungsempfänger die Steuer nach § 13b Abs. 2 UStG geschuldet wird;",
     "66;3;recieved;;",
     "7;3;paied;Abziehbare Vorsteuerbeträge;",
     "8;3;paied;Andere Steuerbeträge;",
     "99;99;;Summe;",
    ],
    ["0;keine;0;< < < keine UStVa Position > > >;;;19700101",
     "1;41;1;Innergemeinschaftliche Lieferungen (§ 4 Nr. 1 Buchst. b UStG) an Abnehmer mit USt-IdNr.;0;0;19700101",
     "2;44;1;neuer Fahrzeuge an Abnehmer ohne USt-IdNr.;0;0;19700101",
     "3;49;1;neuer Fahrzeuge außerhalb eines Unternehmens (§ 2a UStG);0;0;19700101",
     "4;43;1;Weitere steuerfreie Umsätze mit Vorsteuerabzug;0;0;19700101",
     "5;48;2;Umsätze nach § 4 Nr. 8 bis 28 UStG;0;0;19700101",
     "6;51;3;zum Steuersatz von 16 %;0;0;19700101",
     "7;511;3;;6;2;19700101",
     "8;81;3;zum Steuersatz von 19 %;0;0;19700101",
     "9;811;3;;8;2;19700101",
     "10;86;3;zum Steuersatz von 7 %;0;0;19700101",
     "11;861;3;;10;2;19700101",
     "12;35;3;Umsätze, die anderen Steuersätzen unterliegen;0;0;19700101",
     "13;36;3;;12;2;19700101",
     "14;77;3;Lieferungen in das übrige Gemeinschaftsgebiet an Abnehmer mit USt-IdNr.;0;0;19700101",
     "15;76;3;Umsätze, für die eine Steuer nach § 24 UStG zu entrichten ist;0;0;19700101",
     "16;80;3;;15;2;19700101",
     "17;91;4;Erwerbe nach § 4b UStG;0;0;19700101",
     "18;97;5;zum Steuersatz von 16 %;0;0;19700101",
     "19;971;5;;18;2;19700101",
     "20;89;5;zum Steuersatz von 19 %;0;0;19700101",
     "21;891;5;;20;2;19700101",
     "22;93;5;zum Steuersatz von 7 %;0;0;19700101",
     "23;931;5;;22;2;19700101",
     "24;95;5;zu anderen Steuersätzen;0;0;19700101",
     "25;98;5;;24;2;19700101",
     "26;94;5;neuer Fahrzeuge von Lieferern ohne USt-IdNr. zum allgemeinen Steuersatz;0;0;19700101",
     "27;96;5;;26;2;19700101",
     "28;42;66;Lieferungen des ersten Abnehmers bei innergemeinschaftlichen Dreiecksgeschäften (§ 25b Abs. 2 UStG);0;0;19700101",
     "29;60;66;Steuerpflichtige Umsätze im Sinne des § 13b Abs. 1 Satz 1 Nr. 1 bis 5 UStG, für die der Leistungsempfänger die Steuer schuldet;0;0;19700101",
     "30;45;66;Nicht steuerbare Umsätze (Leistungsort nicht im Inland);0;0;19700101",
     "31;52;6;Leistungen eines im Ausland ansässigen Unternehmers (§ 13b Abs. 1 Satz 1 Nr. 1 und 5 UStG);0;0;19700101",
     "32;53;6;;31;2;19700101",
     "33;73;6;Lieferungen sicherungsübereigneter Gegenstände und Umsätze, die unter das GrEStG fallen (§ 13b Abs. 1 Satz 1 Nr. 2 und 3 UStG);0;0;19700101",
     "34;74;6;;33;2;19700101",
     "35;84;6;Bauleistungen eines im Inland ansässigen Unternehmers (§ 13b Abs. 1 Satz 1 Nr. 4 UStG);0;0;19700101",
     "36;85;6;;35;2;19700101",
     "37;65;6;Steuer infolge Wechsels der Besteuerungsform sowie Nachsteuer auf versteuerte Anzahlungen u. ä. wegen Steuersatzänderung;;2;19700101",
     "38;66;7;Vorsteuerbeträge aus Rechnungen von anderen Unternehmern (§ 15 Abs. 1 Satz 1 Nr. 1 UStG), aus Leistungen im Sinne des § 13a Abs. 1 Nr. 6 UStG (§ 15 Abs. 1 Satz 1 Nr. 5 UStG) und aus innergemeinschaftlichen Dreiecksgeschäften (§ 25b Abs. 5 UStG);;2;19700101",
     "39;61;7;Vorsteuerbeträge aus dem innergemeinschaftlichen Erwerb von Gegenständen (§ 15 Abs. 1 Satz 1 Nr. 3 UStG);;2;19700101",
     "40;62;7;Entrichtete Einfuhrumsatzsteuer (§ 15 Abs. 1 Satz 1 Nr. 2 UStG);;2;19700101",
     "41;67;7;Vorsteuerbeträge aus Leistungen im Sinne des § 13b Abs. 1 UStG (§ 15 Abs. 1 Satz 1 Nr. 4 UStG);;2;19700101",
     "42;63;7;Vorsteuerbeträge, die nach allgemeinen Durchschnittssätzen berechnet sind (§§ 23 und 23a UStG);;2;19700101",
     "43;64;7;Berichtigung des Vorsteuerabzugs (§ 15a UStG);;2;19700101",
     "44;59;7;Vorsteuerabzug für innergemeinschaftliche Lieferungen neuer Fahrzeuge außerhalb eines Unternehmens (§ 2a UStG) sowie von Kleinunternehmern im Sinne des § 19 Abs. 1 UStG (§ 15 Abs. 4a UStG);;2;19700101",
     "45;69;8;in Rechnungen unrichtig oder unberechtigt ausgewiesene Steuerbeträge (§ 14c UStG) sowie Steuerbeträge, die nach § 4 Nr. 4a Satz 1 Buchst. a Satz 2, § 6a Abs. 4 Satz 2, § 17 Abs. 1 Satz 6 oder § 25b Abs. 2 UStG geschuldet werden;;2;19700101",
     "46;39;8;Anrechnung (Abzug) der festgesetzten Sondervorauszahlung für Dauerfristverlängerung (nur auszufüllen in der letzten Voranmeldung des Besteuerungszeitraums, in der Regel Dezember);;2;19700101",
  ],
  );

  for my $statement ( 0 .. $#copy_statements ) {
    my $query = $copy_statements[$statement];
    my $sth   = $self->dbh->prepare($query) || $self->db_error($query);

    for my $copy_line ( 0 .. $#{$copy_data[$statement]} ) {
      #print $copy_data[$statement][$copy_line] . "<br />"
      $sth->execute(split m/;/, $copy_data[$statement][$copy_line], -1) || $self->db_error($query);
    }
    $sth->finish();
  }
  return 1;
}

sub run {
  my ($self) = @_;
  return $self->create_tables && $self->do_copy ? 1 : undef;
}

1;
