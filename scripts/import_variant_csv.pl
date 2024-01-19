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
use List::Util qw(first);

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
use SL::DB::Part;
use SL::DB::PartsGroup;
use SL::DB::VariantProperty;
use SL::DB::Warehouse;
use SL::DB::Inventory;

use feature "say";

chdir($FindBin::Bin . '/..');

my ($opt_user, $opt_client, $opt_part_csv_file);
our (%myconfig, $form, $user, $employee, $auth, $locale);

$opt_client = "variant";
$opt_user   = "test_user";

# $opt_part_csv_file = "Artikel_Auswahl.csv";
$opt_part_csv_file = "Artikel_small.csv";
# $opt_part_csv_file = "Artikel_komplett.csv";


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
  WAR_KURZBEZEICHNUNG     => 'description',
  WARENGRUPPENBEZEICHNUNG => 'warengruppe',
  GROESSE                 => 'varianten_groesse',
  LAENGE                  => 'varianten_laenge',
  FARBNR                  => 'varianten_farbnummer',
  INFO1                   => 'varianten_farbname',
  ARTIKELNR               => 'makemodel_model',
  LIEFERANT               => 'vendor_name',
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
  quote_char  => '"',    # default '"'
  escape_char => '"',     # default '"'
);

$part_csv->parse or die "Could not parse csv";
my $hrefs   = $part_csv->get_data;

my %parent_variants_to_variants;
foreach my $part_row (@$hrefs) {
  my %part =
    map {$parts_mapping{$_} => $part_row->{$_}}
    grep {$part_row->{$_}}
    keys %parts_mapping;

  if ($part{varianten_farbnummer} || $part{varianten_farbname}) {
    $part{varianten_farbe} = (delete $part{varianten_farbnummer}) . '-' . (delete $part{varianten_farbname});
  }

  push @{$parent_variants_to_variants{$part_row->{LIEFERANT}}->{$part_row->{ARTIKELNR}}}, \%part;
}

my %variant_property_groups;
my @parent_variants;
my @variants;

my %partsgroup_name_to_partsgroup = map {$_->partsgroup => $_} @{SL::DB::Manager::PartsGroup->get_all()};
my %vendor_name_to_vendor = map {$_->name => $_} @{SL::DB::Manager::Vendor->get_all()};
my %warehouse_description_to_warehouse = map {$_->description => $_} @{SL::DB::Manager::Warehouse->get_all()};

my @all_variant_properties = @{SL::DB::Manager::VariantProperty->get_all()};

my $transfer_type = SL::DB::Manager::TransferType->find_by(
  direction => 'in',
  description => 'stock',
) or die "Could no find transfer_type";

SL::DB->client->with_transaction(sub {
foreach my $vendor (keys %parent_variants_to_variants) {
  foreach my $partnumber (keys %{$parent_variants_to_variants{$vendor}}) {
    my $grouped_variant_values = $parent_variants_to_variants{$vendor}->{$partnumber};

    #get data for parent_variant
    my $first_part = $grouped_variant_values->[0];
    my $description = $first_part->{description};
    my $partsgroup_name = $first_part->{warengruppe};
    my $warehouse_description = $first_part->{warehouse_description};
    my $vendor_name = $first_part->{vendor_name};
    my $makemodel_model = $first_part->{makemodel_model};
    my $best_sellprice = first {$_} sort map {$_->{sellprice}} @$grouped_variant_values;
    my $partsgroup = $partsgroup_name_to_partsgroup{$partsgroup_name} or die
      die "Could not find partsgroup '$partsgroup_name' for part '$makemodel_model $description'";
    my $vendor = $vendor_name_to_vendor{$vendor_name} or
      die "Could not find vendor: '$vendor_name' for part '$makemodel_model $description'";
    my $warehouse = $warehouse_description_to_warehouse{$warehouse_description} or
      die "Could not find warehouse '$warehouse_description' for part '$makemodel_model $description'";
    my $parent_variant = SL::DB::Part->new_parent_variant(
      description => $description,
      sellprice   => $best_sellprice,
      partsgroup  => $partsgroup,
      warehouse   => $warehouse,
      bin         => $warehouse->bins->[0],
      part_type   => 'part',
      unit        => 'Stck',
    );

    # add makemodel
    my $makemodel = SL::DB::MakeModel->new(
      make             => $vendor->id,
      model            => $makemodel_model,
      part_description => $description,
    );
    $parent_variant->add_makemodels($makemodel);

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
      # TODO find valid properties for partsgroup
      my $needed_property_values = $group_variant_property_vales{$property_name};
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
        @all_variant_properties;

      if (scalar @{$best_match->{missing}}) {
        die "Could not find variant property with values '@{$needed_property_values}'.\n" .
        "Best match is ${\$best_match->{property}->name} with missing values '@{$best_match->{missing}}'";
      }
      $property_name_to_variant_property{$property_name} = $best_match->{property};
    }
    my @variant_properties = values %property_name_to_variant_property;
    $parent_variant->variant_properties(@variant_properties);

    $parent_variant->save();

    foreach my $variant_values (@$grouped_variant_values) {
      my @property_values =
        map {
          my $value = $variant_values->{$_};
          first {$_->value eq $value} @{$property_name_to_variant_property{$_}->property_values}}
        grep { $_ =~ m/^variant/ }
        keys %$variant_values;

      my $variant = $parent_variant->create_new_variant(\@property_values);

      $variant->update_attributes(
        ean => $variant_values->{ean},
        description => $variant_values->{description},
        sellprice => $variant_values->{sellprice},
      );

      # set stock
      my ($trans_id) = selectrow_query($::form, $::form->get_standard_dbh, qq|SELECT nextval('id')|);
      SL::DB::Inventory->new(
        part         => $variant,
        trans_id     => $trans_id,
        trans_type   => $transfer_type,
        shippingdate => 'now()',
        comment      => 'initialer Bestand',
        warehouse    => $variant->warehouse,
        bin          => $variant->bin,
        qty          => $variant_values->{part_qty},
        employee     => $employee,
      )->save;

    }
  }
}
1;
}) or do {
  die t8('Error while creating variants: '), SL::DB->client->error;
};

