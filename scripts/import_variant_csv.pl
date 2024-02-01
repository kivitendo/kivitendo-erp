#!/usr/bin/perl

use strict;
use warnings;
use utf8;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.
}

use Data::Dumper;
use List::Util qw(first sum0);
use List::MoreUtils qw(any);
use File::Basename;
use Encode;

use SL::DBUtils;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::Locale::String qw(t8);

SL::LxOfficeConf->read;
our $lxdebug = LXDebug->new();

use SL::Auth;
use SL::Form;
use SL::Locale;

use SL::Helper::Csv;
use SL::Helper::Inventory qw(get_stock);

use SL::DB::Part;
use SL::DB::PartsGroup;
use SL::DB::VariantProperty;
use SL::DB::VariantPropertyValue;
use SL::DB::Warehouse;
use SL::DB::Inventory;

use feature "say";

chdir($FindBin::Bin . '/..');

my (
  $opt_user, $opt_client,
  $opt_warengruppen_csv_file, $opt_farben_folder,
  $opt_part_csv_file, $opt_groessen_staffeln_csv_file,
  $opt_test_run, $opt_force
);
our (%myconfig, $form, $user, $employee, $auth, $locale);

$opt_client = "variant";
$opt_user   = "test_user";

$opt_warengruppen_csv_file = "kuw/Warengruppen.csv";
$opt_groessen_staffeln_csv_file = "kuw/Größenstaffeln.csv";
$opt_farben_folder = "kuw/Farben";
$opt_part_csv_file = "kuw/Export_bearbeitet.csv";

$opt_test_run = 1;
$opt_force = 0; # Writes all valid entries to DB

if ($opt_test_run && $opt_force) {
  die "Can't do test run and force the write to the db.\n".
  "Change \$opt_test_run or \$opt_force."
}

$locale = Locale->new;
$form   = Form->new;

sub connect_auth {
  return $auth if $auth;

  $auth = SL::Auth->new;
  if (!$auth->session_tables_present) {
    $form->error("The session and user management tables are not present in the authentication database. Please use the administration web interface to create them.");
  }

  return $auth;
}


if ($opt_client && !connect_auth()->set_client($opt_client)) {
  $form->error($form->format_string("The client '#1' does not exist.", $opt_client));
}

if ($opt_user) {
  $form->error("Need a client, too.") if !$auth || !$auth->client;

  %myconfig = connect_auth()->read_user(login => $opt_user);

  if (!$myconfig{login}) {
    $form->error($form->format_string("The user '#1' does not exist.", $opt_user));
  }

  $locale = Locale->new($myconfig{countrycode}, "all");
  $user   = User->new(login => $opt_user);
  $employee = SL::DB::Manager::Employee->find_by(login => $opt_user);
}

# Mappings
my %parts_mapping = (
  VK                      => 'sellprice',
  EANNR                   => 'ean',
  EIGENEARTIKELNR         => 'description',
  WARENGRUPPE             => 'warengruppe_nummer',
  WAR_KURZBEZEICHNUNG     => 'warengruppe_name',
  GROESSE                 => 'varianten_groesse',
  LAENGE                  => 'varianten_laenge',
  FARBNR                  => 'varianten_farbnummer',
  INFO1                   => 'varianten_farbname',
  ARTIKELNR               => 'makemodel_model',
  LST_ID                  => 'vendor_number',
  FIL_KURZBEZEICHNUNG     => 'warehouse_description',
  STUECK                  => 'part_qty',
);

# STA_ID                  => ?
# STD_ID                  => ?
# ARTIKELNR + LIEFERANT   => Stammartikel mit Lieferantenartikelnummer ARTIKELNR
# FARBNR                  => Varianten Eigenschaft 'farbnr'
# LAENGE                  => Varianten Eigenschaft 'laenge'; hat 32,34,U
# LST_ID                  => Lager?
# GROESSE                 => Varianten Eigenschaft 'groesse'
# FIL_ID                  => Filialen ID 2,3,4,9
# FILIALE                 => Filiale 1,2,3,4
# FIL_KURZBEZEICHNUNG     => Name der Filiale
# SAI_ID                  => Saison ID
# SAISON                  => Saison Nummer
# WAR_ID                  => Warehouse ID?
# STUECK                  => Anzahl im Lager
# VK                      => Verkaufspreis
# LIEFERANT               => Lieferantenname
# SAISONBEZEICHNUNG       => Saisonbezeichnung
# WARENGRUPPE             => Warengruppennummer
# WARENGRUPPENBEZEICHNUNG => Warengruppenbezeichnung
# LIEFARTIKELBEZEICHNUNG  => Lieferanten Artikelbezeichung
# EIGENEARTIKELNR         => Eigene Artikelnummer; ist eher Bezeichnung
# KOLLEKTION              => Kollektion (hat auch -)
# INFO1                   => Farbenname
# INFO2                   => ?
# INFO3                   => ?
# INFO4                   => ?
# INFO5                   => ?
# BILD1                   => ?
# BILD2                   => ?
# BILD3                   => ?
# BILD4                   => ?
# BILD5                   => ?
# EANNR                   => ean
# VKWEB                   => Verkaufspreis online Shop?
# WAR_KURZBEZEICHNUNG     => Warenbezeichnung
# LETZTERWE               => Letzter Wareneingang?

my $part_csv = SL::Helper::Csv->new(
  file        => $opt_part_csv_file,
  encoding    => 'utf-8', # undef means utf8
  sep_char    => ';',     # default ';'
  quote_char  => '"',     # default '"'
  escape_char => '"',     # default '"'
);
$part_csv->parse or die "Could not parse csv";
my $part_hrefs = $part_csv->get_data;

my %parent_variants_to_variants;
my $row = 0;
foreach my $part_row (@$part_hrefs) {
  my %part =
    map {$parts_mapping{$_} => $part_row->{$_}}
    grep {$part_row->{$_}}
    keys %parts_mapping;
  $part{csv_row} = $row++;

  if ($part{varianten_farbnummer} || $part{varianten_farbname}) {
    $part{varianten_farbnummer} ||= '';
    $part{varianten_farbname} ||= '';
    $part{varianten_farbe} = (delete $part{varianten_farbnummer}) . '-' . (delete $part{varianten_farbname});
  }

  if ($part{warengruppe_nummer} eq '114310' || $part{warengruppe_nummer} eq '124310') {
    # gürtel
  } elsif ($part{warengruppe_nummer} eq '151010') {
    # Feinstrumpfhosen
    if ($part{varianten_groesse}) {
      $part{varianten_groesse} =~ s/^([IV]*) EW$/$1 ew/;
      $part{varianten_groesse} =~ s/^([IV]*) E$/$1 ew/;
      $part{varianten_groesse} =~ s/^([IV]*) e$/$1 ew/;
    }
  } elsif ($part{warengruppe_nummer} eq '114415') {
    # Hosenträger haben keine Größe
    delete $part{varianten_groesse};
  } elsif ($part{warengruppe_nummer} eq '114210' || $part{warengruppe_nummer} eq '124210') {
    # Handschuhe
    if ($part{varianten_groesse}) {
      $part{varianten_groesse} =~ s/^([0-9]*)\.5$/$1 ½/;
    }
  } else {
    if ($part{varianten_groesse}) {
      # map to valid sizes
      $part{varianten_groesse} =~ s/^([0-9][0-9])5$/$1,5/; # 345 -> 34,5
      $part{varianten_groesse} =~ s/^([0-9][0-9])\.5$/$1,5/; # 34.5 -> 34,5
      $part{varianten_groesse} =~ s/^2XL$/XXL/;
      $part{varianten_groesse} =~ s/^XXXL$/3XL/;
      $part{varianten_groesse} =~ s/^([0-9]*)½$/$1 ½/;
      $part{varianten_groesse} =~ s/^([0-9]*)\/½$/$1 ½/;
      $part{varianten_groesse} =~ s/^([0-9]*) 1\/2$/$1 ½/;
      $part{varianten_groesse} =~ s/\/U//; # 34/U -> 34
      $part{varianten_groesse} =~ s/\/I//; # 34/I -> 34
      $part{varianten_groesse} =~ s/\/M//; # 34/M -> 34
      $part{varianten_groesse} =~ s/\/L//; # 34/L -> 34
      $part{varianten_groesse} =~ s/\/XL//; # 34/XL -> 34
      $part{varianten_groesse} =~ s/\/XX//; # 34/XX -> 34

      if ($part{varianten_groesse} =~ m/^([0-9][0-9])([0-9][0-9])$/) { # 3432 -> weite 34 laenge 32
        my $weite = $1;
        my $laenge = $2;
        $part{varianten_groesse} = $weite;
        $part{varianten_laenge} = $laenge;
      }

      if (any {$part{varianten_groesse} eq $_} ('.', '-', '_', 'ONE', 'ONE S', 'ONES', 'OSFA', 'ONESI', 'O/S', 'OSO')) {
        delete $part{varianten_groesse};
      }

    }
  }

  if ($part{varianten_laenge}) {
    if (any {$part{varianten_laenge} eq $_} ('.', 'U')) {
      delete $part{varianten_laenge};
    }
  }

  push @{$parent_variants_to_variants{$part_row->{LIEFERANT}}->{$part_row->{ARTIKELNR}}}, \%part;
}

my $groessen_staffel_csv = SL::Helper::Csv->new(
  file        => $opt_groessen_staffeln_csv_file,
  encoding    => 'utf-8', # undef means utf8
  sep_char    => ';',     # default ';'
  quote_char  => '"',     # default '"'
  escape_char => '"',     # default '"'
);
$groessen_staffel_csv->parse or die "Could not parse csv";
my $groessen_staffel_hrefs = $groessen_staffel_csv->get_data;

my $warengruppen_csv = SL::Helper::Csv->new(
  file        => $opt_warengruppen_csv_file,
  encoding    => 'utf-8', # undef means utf8
  sep_char    => ';',     # default ';'
  quote_char  => '"',     # default '"'
  escape_char => '"',     # default '"'
);
$warengruppen_csv->parse or die "Could not parse csv";
my $warengruppen_hrefs = $warengruppen_csv->get_data;

my $transfer_type = SL::DB::Manager::TransferType->find_by(
  direction => 'in',
  description => 'stock',
) or die "Could no find transfer_type";

SL::DB->client->with_transaction(sub {
  my @errors;

  # create farben listen
  foreach my $farb_csv_file (glob( $opt_farben_folder . '/*' )) {
    $farb_csv_file = Encode::decode('utf-8', $farb_csv_file);
    my $farb_csv = SL::Helper::Csv->new(
      file        => $farb_csv_file,
      encoding    => 'utf-8', # undef means utf8
      sep_char    => ';',     # default ';'
      quote_char  => '"',     # default '"'
      escape_char => '"',     # default '"'
    );
    unless ($farb_csv->parse) {
      push @errors, "Could not parse csv '$farb_csv_file'";
      next;
    }
    my $farb_hrefs = $farb_csv->get_data;

    my $vendor_name = basename($farb_csv_file);
    $vendor_name =~ s/\.csv//;

    my %variant_property_att = (
      name         => "Farbliste $vendor_name",
      unique_name  => "Farbliste $vendor_name",
      abbreviation => "fa",
    );
    my $variant_property = SL::DB::Manager::VariantProperty->find_by(
      %variant_property_att
    );
    $variant_property ||= SL::DB::VariantProperty->new(
      %variant_property_att
    );
    $variant_property->save;

    my $pos = 1;
    SL::DB::VariantPropertyValue->new(
      variant_property => $variant_property,
      value            => $_->{Joined},
      abbreviation     => $_->{Joined},
    )->update_attributes(
      sortkey => $pos++,
    )->save for @$farb_hrefs;
  }

  # create groessen staffeln
  foreach my $groessen_staffel_row (@$groessen_staffel_hrefs) {
    my $name = delete $groessen_staffel_row->{BEZEICHNUNG};
    my %variant_property_att = (
      name         => $name,
      unique_name  => $name,
      abbreviation => "gr",
    );
    my $variant_property = SL::DB::Manager::VariantProperty->find_by(
      %variant_property_att
    );
    $variant_property ||= SL::DB::VariantProperty->new(
      %variant_property_att
    );
    $variant_property->save;

    my $pos = 1;
    SL::DB::VariantPropertyValue->new(
      variant_property => $variant_property,
      value            => $_,
      abbreviation     => $_,
    )->update_attributes(
      sortkey => $pos++,
    )->save for
      map {$groessen_staffel_row->{$_}}
      sort
      grep {$groessen_staffel_row->{$_} ne ''}
      keys %$groessen_staffel_row;
  }

  # create partsgroups
  my %partsgroup_id_to_groessen_staffeln;
  my @hierachy_descrioptions = qw(
    Bereich Hauptabteilung Abteilung Hauptwarengruppe Warengruppe
  );
  my %current_partsgroup_hierachy;
  foreach my $partsgroup_row (@$warengruppen_hrefs) {
    my $valid_groessen_staffen = delete $partsgroup_row->{Größenstaffeln};
    my $last_hierachy_key;
    foreach my $hierachy_key (@hierachy_descrioptions) {
      if ($partsgroup_row->{$hierachy_key}) {
        my ($number, @rest) = split(' ', $partsgroup_row->{$hierachy_key});
        my $name = join(' ', @rest);
        unless ($number && $name) {
          push @errors, "Could not find number and name for $hierachy_key partsgroup '".$partsgroup_row->{$hierachy_key}."' in the row:'\n".
            join(';', map {$partsgroup_row->{$_}} @hierachy_descrioptions);
          next;
        }
        my %partsgroup_att = (
          partsgroup  => $name,
          sortkey     => $number,
          description => "$number $name",
          parent_id   => $last_hierachy_key ? $current_partsgroup_hierachy{$last_hierachy_key}->id : undef,
        );
        my $partsgroup = SL::DB::Manager::PartsGroup->find_by(
          %partsgroup_att
        );
        $partsgroup ||= SL::DB::PartsGroup->new(
          %partsgroup_att
        );
        $partsgroup->save();
        $current_partsgroup_hierachy{$hierachy_key} = $partsgroup;
      }
      $last_hierachy_key = $hierachy_key;
    }
    my $last_partsgroup = $current_partsgroup_hierachy{$last_hierachy_key};
    my @valid_groessen_staffen =
      grep { $_ }
      map {
        my $variant = SL::DB::Manager::VariantProperty->find_by(unique_name => $_);
        push @errors, "Could not find Variant Property '$_' while importing partsgroups." unless $variant;
        $variant;
      }
      grep { $_ ne 'ohne'}
      split(', ', $valid_groessen_staffen);
    $partsgroup_id_to_groessen_staffeln{$last_partsgroup->id} = \@valid_groessen_staffen;
  }

  my %partsgroup_number_to_partsgroup = map {my ($number) = split(' ', $_->description); $number => $_} @{SL::DB::Manager::PartsGroup->get_all()};
  my %vendor_number_to_vendor = map {$_->vendornumber => $_} @{SL::DB::Manager::Vendor->get_all()};
  my %warehouse_description_to_warehouse = map {lc($_->description) => $_} @{SL::DB::Manager::Warehouse->get_all()};

  # create parts
  foreach my $vendor_kurz_name (keys %parent_variants_to_variants) {
    foreach my $partnumber (keys %{$parent_variants_to_variants{$vendor_kurz_name}}) {
      my $count_errors_at_start = scalar @errors;
      my $grouped_variant_values = $parent_variants_to_variants{$vendor_kurz_name}->{$partnumber};
      # check for variants the same variant_values
      my %variant_values_to_variant;
      foreach my $variant_values (@$grouped_variant_values) {
        my $key =
          join ';',
          map {$variant_values->{$_}}
          sort
          grep { $_ =~ m/^variant/ }
          keys %$variant_values;

        push @{$variant_values_to_variant{$key}}, $variant_values
      }

      #get data for parent_variant
      my $first_part = $grouped_variant_values->[0];
      my $description = $first_part->{description} || '';
      my $partsgroup_number = $first_part->{warengruppe_nummer};
      my $warehouse_description = $first_part->{warehouse_description};
      my $vendor_number = $first_part->{vendor_number};
      my $makemodel_model = $first_part->{makemodel_model};
      my $best_sellprice = first {$_} sort map {$_->{sellprice}} @$grouped_variant_values;
      $best_sellprice =~ s/,/./;
      my $partsgroup = $partsgroup_number_to_partsgroup{$partsgroup_number} or
        push @errors, "Could not find partsgroup '$partsgroup_number' for part '$makemodel_model $description' in row " . $first_part->{csv_row};
      my $vendor = $vendor_number_to_vendor{$vendor_number} or
        push @errors, "Could not find vendor: '$vendor_number' for part '$makemodel_model $description' in row " . $first_part->{csv_row};
      my $warehouse = $warehouse_description_to_warehouse{lc($warehouse_description)} or
        push @errors, "Could not find warehouse '$warehouse_description' for part '$makemodel_model $description' in row " . $first_part->{csv_row};
      next if $count_errors_at_start != scalar @errors;
      my %parent_variant_fix_att = (
        partnumber   => $vendor_number . '-' . $makemodel_model,
        variant_type => 'parent_variant',
        part_type    => 'part',
      );
      my $parent_variant = SL::DB::Manager::Part->find_by(
        %parent_variant_fix_att
      );
      $parent_variant ||= SL::DB::Part->new(
        %parent_variant_fix_att
      );
      $parent_variant->update_attributes(
        description => $description,
        sellprice   => $best_sellprice,
        partsgroup  => $partsgroup,
        warehouse   => $warehouse,
        bin         => $warehouse->bins->[0],
        unit        => 'Stck',
      );

      unless (scalar @{$parent_variant->makemodels}) {
        # add makemodel
        my $makemodel = SL::DB::MakeModel->new(
          make             => $vendor->id,
          model            => $makemodel_model,
          part_description => $description,
        );
        $parent_variant->add_makemodels($makemodel);
      }

      # get active variant_properties
      my %group_variant_property_vales;
      foreach my $variant_values (@$grouped_variant_values) {
        $group_variant_property_vales{$_}->{$variant_values->{$_}} = 1 for
          grep { $_ =~ m/^variant/ }
          keys %$variant_values;
      }
      foreach my $variant_property (keys %group_variant_property_vales) {
        $group_variant_property_vales{$variant_property} = [sort keys %{$group_variant_property_vales{$variant_property}}];
      }

      # find variant_properties
      my %property_name_to_variant_property;
      foreach my $property_name (keys %group_variant_property_vales) {
        my $needed_property_values = $group_variant_property_vales{$property_name};

        my @valid_variant_properties;
        if ($property_name eq 'varianten_groesse') {
          @valid_variant_properties = @{$partsgroup_id_to_groessen_staffeln{$partsgroup->id}};
          unless (scalar @valid_variant_properties) {
            push @errors, "NO variant property for key '$property_name' and partsgroup '${\$partsgroup->description}'. values '@$needed_property_values' in part '$makemodel_model $description' in row " . $first_part->{csv_row};
            next;
          }
        } elsif ($property_name eq 'varianten_farbe') {
          my $color = SL::DB::Manager::VariantProperty->find_by(
            name => { ilike => "Farbliste $vendor_kurz_name" },
          );
          unless ($color) {
            push @errors, "Could not find variant property 'Farbliste $vendor_kurz_name'";
            next;
          }
          @valid_variant_properties = ($color);
        } elsif ($property_name eq 'varianten_laenge') {
          # Only 'Jeanslängen' is vaild
          my $laenge = SL::DB::Manager::VariantProperty->find_by(
              name => { ilike => "Jeanslängen" },
          );
          unless ($laenge) {
            push @errors, "Could not find variant property 'Jenaslänge'";
            next;
          }
          @valid_variant_properties = ($laenge);
        } else {
          push @errors, "Not implemented for property '$property_name'";
          next;
        }

        my ($best_match) =
          sort {scalar @{$a->{missing}} <=> scalar @{$b->{missing}}}
          map {
            my @property_values = map {$_->value} @{$_->property_values};
            my @missing;
            foreach my $needed_property_value (@$needed_property_values) {
              push @missing, $needed_property_value unless scalar grep {$needed_property_value eq $_} @property_values;
            }
            {property => $_, missing => \@missing};
          }
          @valid_variant_properties;

        if (scalar @{$best_match->{missing}}) {
          push @errors, "Could not find variant property with values for $property_name '@{$needed_property_values}' of part '$makemodel_model $description' in row " . $first_part->{csv_row} . "\n" .
          "Best match is '${\$best_match->{property}->name}' with missing values '@{$best_match->{missing}}'.\n" .
          "Valid properties for partsgroup '${\$partsgroup->description}' are: " . join(', ', map {$_->name} @valid_variant_properties) . "\n"
          ;
          next;
        }
        $property_name_to_variant_property{$property_name} = $best_match->{property};
      }
      my @variant_properties = values %property_name_to_variant_property;
      if (scalar @{$parent_variant->variant_properties}) {
        my @current_variant_property_ids = sort map {$_->id} $parent_variant->variant_properties;
        my @new_variant_property_ids = sort map {$_->id} @variant_properties;
        if ("@current_variant_property_ids" ne "@new_variant_property_ids") {
          push @errors, "The variant properties changed for part '$makemodel_model $description' in row " . $first_part->{csv_row} . "\n" .
          "Please change them manually before import.\n";
        }
      } else {
        $parent_variant->variant_properties(@variant_properties);
      }

      next if ($opt_test_run);

      next if $count_errors_at_start != scalar @errors;
      $parent_variant->save();

      foreach my $variant_values_list (values %variant_values_to_variant) {
        my $variant_values = $variant_values_list->[0];
        my @property_values =
          map {
            my $value = $variant_values->{$_};
            first {$_->value eq $value} @{$property_name_to_variant_property{$_}->property_values}}
          grep { $_ =~ m/^variant/ }
          keys %$variant_values;

        if (scalar @property_values != scalar keys %property_name_to_variant_property) {
          push @errors, "Missing property value for part '$makemodel_model $description' in row " . $variant_values->{csv_row};
          next;
        }

        my $variant = first {join(' ', sort map {$_->id} @property_values) eq join(' ', sort map {$_->id} $_->variant_property_values)}
          $parent_variant->variants;
        my $variant_is_new = !$variant;
        $variant ||= $parent_variant->create_new_variant(\@property_values);

        my @stocks;
        foreach my $variant_values_with_stock_info (@$variant_values_list) {
          my $warehouse_description = $variant_values_with_stock_info->{warehouse_description};
          my $warehouse = $warehouse_description_to_warehouse{lc($warehouse_description)};
          unless ($warehouse) {
            push @errors, "Could not find warehouse '$warehouse_description' for part '$makemodel_model $description' in row " . $variant_values_with_stock_info->{csv_row};
            next;
          }
          push @stocks, {
            part_qty  => $variant_values_with_stock_info->{part_qty} || 0,
            warehouse => $warehouse,
          };
        }
        my $main_warehouse =
          first {$_}
          map {$_->{warehouse}}
          sort {$b->{part_qty} <=> $a->{part_qty}} # descending
          @stocks;

        unless ($main_warehouse) {
          push @errors, "Could not find warehouse for part '$makemodel_model $description'";
          next;
        }

        my $sellprice = $variant_values->{sellprice};
        $sellprice =~ s/,/./;
        $variant->update_attributes(
          ean         => $variant_values->{ean},
          description => $variant_values->{description},
          sellprice   => $sellprice,
          warehouse   => $main_warehouse,
          bin         => $main_warehouse->bins->[0],
        );

        # set stock
        if ($variant_is_new) {
          foreach my $stock (@stocks) {
            next unless $stock->{part_qty} > 0;
            my ($trans_id) = selectrow_query($::form, $::form->get_standard_dbh, qq|SELECT nextval('id')|);
            SL::DB::Inventory->new(
              part         => $variant,
              trans_id     => $trans_id,
              trans_type   => $transfer_type,
              shippingdate => 'now()',
              comment      => 'initialer Bestand',
              warehouse    => $stock->{warehouse},
              bin          => $stock->{warehouse}->bins->[0],
              qty          => $stock->{part_qty},
              employee     => $employee,
            )->save;
          }
        } else {
          foreach my $stock (@stocks) {
            my $current_part_qty = get_stock(
              part => $variant,
              warehouse => $stock->{warehouse},
              bin => $stock->{warehouse}->bins->[0]
            ) || 0;

            next if $current_part_qty == $stock->{part_qty};

            my $transfer_type_correction = SL::DB::Manager::TransferType->find_by(
              direction   => $current_part_qty > $stock->{part_qty} ? 'out' : 'in',
              description => 'correction',
            ) or die "Could no find transfer_type correction";
            my ($trans_id) = selectrow_query($::form, $::form->get_standard_dbh, qq|SELECT nextval('id')|);
            SL::DB::Inventory->new(
              part         => $variant,
              trans_id     => $trans_id,
              trans_type   => $transfer_type_correction,
              shippingdate => 'now()',
              comment      => 'Korrektur bei Import',
              warehouse    => $stock->{warehouse},
              bin          => $stock->{warehouse}->bins->[0],
              qty          => $stock->{part_qty} - $current_part_qty,
              employee     => $employee,
            )->save;
          }
        }

      }
    }
  }
  if (scalar @errors) {
    say join("\n", @errors);
    die join("\n", @errors) unless $opt_force;
  }
  if ($opt_test_run) {
    die "Test run successfull: no erros in the data.";
  }
}) or do {
  if (SL::DB->client->error) {
    say t8('Error while creating variants: '), SL::DB->client->error;
  }
};

