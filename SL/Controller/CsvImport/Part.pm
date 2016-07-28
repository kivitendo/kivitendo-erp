package SL::Controller::CsvImport::Part;

use strict;

use SL::Helper::Csv;

use SL::DBUtils;
use SL::DB::Buchungsgruppe;
use SL::DB::CustomVariable;
use SL::DB::CustomVariableConfig;
use SL::DB::PartsGroup;
use SL::DB::PaymentTerm;
use SL::DB::PriceFactor;
use SL::DB::Pricegroup;
use SL::DB::Price;
use SL::DB::Translation;
use SL::DB::Unit;

use List::MoreUtils qw(none);

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(table makemodel_columns) ],
 'scalar --get_set_init' => [ qw(bg_by settings parts_by price_factors_by units_by partsgroups_by
                                 translation_columns all_pricegroups) ],
);

sub set_profile_defaults {
  my ($self) = @_;

  my $bugru = SL::DB::Manager::Buchungsgruppe->find_by(description => { like => 'Standard%19%' });

  $self->controller->profile->_set_defaults(
                       sellprice_places          => 2,
                       sellprice_adjustment      => 0,
                       sellprice_adjustment_type => 'percent',
                       article_number_policy     => 'update_prices',
                       shoparticle_if_missing    => '0',
                       parts_type                => 'part',
                       default_buchungsgruppe    => ($bugru ? $bugru->id : undef),
                       apply_buchungsgruppe      => 'all',
                      );
};


sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::Part');
}

sub init_bg_by {
  my ($self) = @_;

  my $all_bg = SL::DB::Manager::Buchungsgruppe->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_bg } } ) } qw(id description) };
}

sub init_price_factors_by {
  my ($self) = @_;

  my $all_price_factors = SL::DB::Manager::PriceFactor->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_price_factors } } ) } qw(id description) };
}

sub init_partsgroups_by {
  my ($self) = @_;

  my $all_partsgroups = SL::DB::Manager::PartsGroup->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_partsgroups } } ) } qw(id partsgroup) };
}

sub init_units_by {
  my ($self) = @_;

  my $all_units = SL::DB::Manager::Unit->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_units } } ) } qw(name) };
}

sub init_parts_by {
  my ($self) = @_;

#  my $parts_by = { id         => { map { ( $_->id => $_ ) } grep { !$_->part_type = 'assembly' } @{ $self->existing_objects } },
#                   partnumber => { part    => { },
#                                   service => { } } };
#
#  foreach my $part (@{ $self->existing_objects }) {
#    next if $part->part_type eq 'assembly';
#    $parts_by->{partnumber}->{ $part->type }->{ $part->partnumber } = $part;
#  }

  my $parts_by = {};
  my $sth = prepare_execute_query($::form, SL::DB::Object->new->db->dbh, 'SELECT partnumber FROM parts');
  while (my ($partnumber) = $sth->fetchrow_array()) {
    $parts_by->{partnumber}{$partnumber} = 1;
  }

  return $parts_by;
}

sub init_all_pricegroups {
  my ($self) = @_;

  return SL::DB::Manager::Pricegroup->get_all(sort => 'id');
}

sub init_settings {
  my ($self) = @_;

  return { map { ( $_ => $self->controller->profile->get($_) ) } qw(apply_buchungsgruppe default_buchungsgruppe article_number_policy
                                                                    sellprice_places sellprice_adjustment sellprice_adjustment_type
                                                                    shoparticle_if_missing parts_type default_unit) };
}

sub init_all_cvar_configs {
  my ($self) = @_;

  return SL::DB::Manager::CustomVariableConfig->get_all(where => [ module => 'IC' ]);
}

sub init_translation_columns {
  my ($self) = @_;

  return [ map { ("description_" . $_->article_code, "notes_" . $_->article_code) } (@{ $self->all_languages }) ];
}

sub check_objects {
  my ($self) = @_;

  return unless @{ $self->controller->data };

  $self->controller->track_progress(phase => 'building data', progress => 0);

  $self->makemodel_columns({});

  my $i;
  my $num_data = scalar @{ $self->controller->data };
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    $self->check_buchungsgruppe($entry);
    $self->check_type($entry);
    $self->check_unit($entry);
    $self->check_price_factor($entry);
    $self->check_payment($entry);
    $self->check_partsgroup($entry);
    $self->handle_pricegroups($entry);
    $self->check_existing($entry) unless @{ $entry->{errors} };
    $self->handle_prices($entry) if $self->settings->{sellprice_adjustment};
    $self->handle_shoparticle($entry);
    $self->handle_translations($entry);
    $self->handle_cvars($entry);
    $self->handle_makemodel($entry);
    $self->set_various_fields($entry);
  } continue {
    $i++;
  }

  $self->add_columns(qw(type)) if $self->settings->{parts_type} eq 'mixed';
  $self->add_columns(qw(buchungsgruppen_id unit));
  $self->add_columns(map { "${_}_id" } grep { exists $self->controller->data->[0]->{raw_data}->{$_} } qw (price_factor payment partsgroup));
  $self->add_columns(qw(shop)) if $self->settings->{shoparticle_if_missing};
  $self->add_cvar_raw_data_columns;
  map { $self->add_raw_data_columns("pricegroup_${_}") if exists $self->controller->data->[0]->{raw_data}->{"pricegroup_$_"} } (1..scalar(@{ $self->all_pricegroups }));
  map { $self->add_raw_data_columns($_) if exists $self->controller->data->[0]->{raw_data}->{$_} } @{ $self->translation_columns };
  map { $self->add_raw_data_columns("make_${_}", "model_${_}", "lastcost_${_}") } sort { $a <=> $b } keys %{ $self->makemodel_columns };
}

sub get_duplicate_check_fields {
  return {
    partnumber => {
      label     => $::locale->text('Part Number'),
      default   => 0
    },

    description => {
      label     => $::locale->text('Description'),
      default   => 1,
      maker     => sub {
        my $desc = shift->description;
        $desc =~ s/[\s,\.\-]//g;
        return $desc;
      }
    },
  };
}

sub check_buchungsgruppe {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check Buchungsgruppe

  # Store and verify default ID.
  my $default_id = $self->settings->{default_buchungsgruppe};
  $default_id    = undef unless $self->bg_by->{id}->{ $default_id };

  # 1. Use default ID if enforced.
  $object->buchungsgruppen_id($default_id) if $default_id && ($self->settings->{apply_buchungsgruppe} eq 'all');

  # 2. Use supplied ID if valid
  $object->buchungsgruppen_id(undef) if $object->buchungsgruppen_id && !$self->bg_by->{id}->{ $object->buchungsgruppen_id };

  # 3. Look up name if supplied.
  if (!$object->buchungsgruppen_id) {
    my $bg = $self->bg_by->{description}->{ $entry->{raw_data}->{buchungsgruppe} };
    $object->buchungsgruppen_id($bg->id) if $bg;
  }

  # 4. Use default ID if not valid.
  $object->buchungsgruppen_id($default_id) if !$object->buchungsgruppen_id && $default_id && ($self->settings->{apply_buchungsgruppe} eq 'missing');

  return 1 if $object->buchungsgruppen_id;

  push @{ $entry->{errors} }, $::locale->text('Error: booking group missing or invalid');
  return 0;
}

sub check_existing {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  if ($object->partnumber && $self->parts_by->{partnumber}{$object->partnumber}) {
    $entry->{part} = SL::DB::Manager::Part->find_by(partnumber => $object->partnumber);
  }

  if ($entry->{part}) {
    if ($self->settings->{article_number_policy} eq 'update_prices') {
      if ($self->settings->{parts_type} eq 'mixed' && $entry->{part}->type ne $object->type) {
        push(@{$entry->{errors}}, $::locale->text('Skipping due to existing entry in database with different type'));
      } else {
        map { $entry->{part}->$_( $object->$_ ) if defined $object->$_ } qw(sellprice listprice lastcost);

        # merge prices
        my %prices_by_pricegroup_id = map { $_->pricegroup->id => $_ } $entry->{part}->prices, $object->prices;
        $entry->{part}->prices(grep { $_ } map { $prices_by_pricegroup_id{$_->id} } @{ $self->all_pricegroups });

        push @{ $entry->{information} }, $::locale->text('Updating prices of existing entry in database');
        $entry->{object_to_save} = $entry->{part};
      }
    } elsif ( $self->settings->{article_number_policy} eq 'skip' ) {
      push(@{$entry->{errors}}, $::locale->text('Skipping due to existing entry in database'));

    } else {
      $object->partnumber('####');
      push(@{$entry->{errors}}, $::locale->text('Skipping, for assemblies are not importable (yet)')) if $object->type eq 'assembly';
    }
  } else {
    push(@{$entry->{errors}}, $::locale->text('Skipping, for assemblies are not importable (yet)')) if $object->type eq 'assembly';
  }
}

sub handle_prices {
  my ($self, $entry) = @_;

  foreach my $column (qw(sellprice)) {
    my $object     = $entry->{object_to_save} || $entry->{object};
    my $adjustment = $self->settings->{sellprice_adjustment};
    my $value      = $object->$column;

    $value = $self->settings->{sellprice_adjustment_type} eq 'percent' ? $value * (100 + $adjustment) / 100 : $value + $adjustment;
    $object->$column($::form->round_amount($value, $self->settings->{sellprice_places}));
  }
}

sub handle_shoparticle {
  my ($self, $entry) = @_;

  $entry->{object}->shop(1) if $self->settings->{shoparticle_if_missing} && !$self->controller->headers->{used}->{shop};
}

sub check_type {
  my ($self, $entry) = @_;

  my $bg = $self->bg_by->{id}->{ $entry->{object}->buchungsgruppen_id };
  $bg  ||= SL::DB::Buchungsgruppe->new(inventory_accno_id => 1); # does this case ever occur?

  my $type = $self->settings->{parts_type};
  if ($type eq 'mixed') {
    $type = $entry->{raw_data}->{type} =~ m/^p/i ? 'part'
          : $entry->{raw_data}->{type} =~ m/^s/i ? 'service'
          : $entry->{raw_data}->{type} =~ m/^a/i ? 'assembly'
          :                                        undef;
  }

  $entry->{object}->assembly($type eq 'assembly');

  # when saving income_accno_id or expense_accno_id use ids from the selected
  # $bg according to the default tax_zone (the one with the highest sort
  # order).  Alternatively one could use the ids from defaults, but they might
  # not all be set.

  $entry->{object}->income_accno_id( $bg->income_accno_id( SL::DB::Manager::TaxZone->get_default->id ) );

  if ($type eq 'part' || $type eq 'service') {
    $entry->{object}->expense_accno_id( $bg->expense_accno_id( SL::DB::Manager::TaxZone->get_default->id ) );
  }

  if ($type eq 'part') {
    $entry->{object}->inventory_accno_id( $bg->inventory_accno_id );
  }

  if (none { $_ eq $type } qw(part service assembly)) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid part type');
    return 0;
  }

  return 1;
}

sub check_price_factor {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not price factor ID is valid.
  if ($object->price_factor_id && !$self->price_factors_by->{id}->{ $object->price_factor_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid price factor');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->price_factor_id && $entry->{raw_data}->{price_factor}) {
    my $pf = $self->price_factors_by->{description}->{ $entry->{raw_data}->{price_factor} };

    if (!$pf) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid price factor');
      return 0;
    }

    $object->price_factor_id($pf->id);
  }

  return 1;
}

sub check_partsgroup {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not part group ID is valid.
  if ($object->partsgroup_id && !$self->partsgroups_by->{id}->{ $object->partsgroup_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid parts group');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->partsgroup_id && $entry->{raw_data}->{partsgroup}) {
    my $pg = $self->partsgroups_by->{partsgroup}->{ $entry->{raw_data}->{partsgroup} };

    if (!$pg) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid parts group');
      return 0;
    }

    $object->partsgroup_id($pg->id);
  }

  return 1;
}

sub check_unit {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  $object->unit($self->settings->{default_unit}) unless $object->unit;

  # Check whether or unit is valid.
  if (!$self->units_by->{name}->{ $object->unit }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Unit missing or invalid');
    return 0;
  }

  return 1;
}

sub handle_translations {
  my ($self, $entry) = @_;

  my @translations;
  foreach my $language (@{ $self->all_languages }) {
    my ($desc, $notes) = @{ $entry->{raw_data} }{ "description_" . $language->article_code, "notes_" . $language->article_code };
    next unless $desc || $notes;

    push @translations, SL::DB::Translation->new(language_id     => $language->id,
                                                 translation     => $desc,
                                                 longdescription => $notes);
  }

  $entry->{object}->translations(\@translations);
}

sub handle_pricegroups {
  my ($self, $entry) = @_;

  my @prices;
  my $idx = 0;
  foreach my $pricegroup (@{ $self->all_pricegroups }) {
    $idx++;
    my $sellprice = $entry->{raw_data}->{"pricegroup_${idx}"};
    next if $sellprice eq '';

    push @prices, SL::DB::Price->new(pricegroup_id => $pricegroup->id,
                                     price         => $::form->parse_amount(\%::myconfig, $sellprice));
  }

  $entry->{object}->prices(\@prices);
}

sub handle_makemodel {
  my ($self, $entry) = @_;
  my $object = $entry->{object};
  my $found_any;

  my @makemodels;
  foreach my $idx (sort map { substr $_, 5 } grep { m/^make_\d+$/ && $entry->{raw_data}->{$_} } keys %{ $entry->{raw_data} }) {
    my $vendor = $entry->{raw_data}->{"make_${idx}"};
    $vendor    = $self->vc_by->{id}->               { $vendor }
              || $self->vc_by->{number}->{vendors}->{ $vendor }
              || $self->vc_by->{name}->  {vendors}->{ $vendor };

    if (ref($vendor) ne 'SL::DB::Vendor') {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid vendor in column make_#1', $idx);

    } else {
      $found_any = 1;
      push @makemodels, SL::DB::MakeModel->new(make               => $vendor->id,
                                               model              => $entry->{raw_data}->{"model_${idx}"},
                                               lastcost_as_number => $entry->{raw_data}->{"lastcost_${idx}"});

      $self->makemodel_columns->{$idx}    = 1;
      $entry->{raw_data}->{"make_${idx}"} = $vendor->name;
    }
  }

  $object->makemodels(\@makemodels);
  $object->makemodel(scalar(@makemodels) ? 1 : 0);

  if ( !$entry->{part} || $self->settings->{article_number_policy} ne 'update_prices' ) {
    return;
  }

  my %old_makemodels_by_mm = map { $_->make . $; . $_->model => $_ } $entry->{part}->makemodels;
  my @new_makemodels;

  foreach my $makemodel ($object->makemodels()) {
    my $makemodel_orig = $old_makemodels_by_mm{$makemodel->make,$makemodel->model};
    $found_any = 1;

    if ($makemodel_orig) {
      $makemodel_orig->model($makemodel->model);
      $makemodel_orig->lastcost($makemodel->lastcost);

    } else {
      push @new_makemodels, $makemodel;
    }
  }

  $entry->{part}->makemodels([ $entry->{part}->makemodels, @new_makemodels ]) if @new_makemodels;

  # reindex makemodels
  my $i = 0;
  $_->sortorder(++$i) for @{ $entry->{part}->makemodels };

  $self->save_with_cascade(1) if $found_any;
}

sub set_various_fields {
  my ($self, $entry) = @_;

  $entry->{object}->priceupdate(DateTime->now_local);
}

sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;
  delete @{$profile}{qw(bom expense_accno_id income_accno_id inventory_accno_id makemodel priceupdate stockable type)};

  $profile->{"pricegroup_$_"} = '' for 1 .. scalar @{ $_[0]->all_pricegroups };

  return $profile;
}

sub save_objects {
  my ($self, %params) = @_;

  my $with_number    = [ grep { $_->{object}->partnumber ne '####' } @{ $self->controller->data } ];
  my $without_number = [ grep { $_->{object}->partnumber eq '####' } @{ $self->controller->data } ];

  map { $_->{object}->partnumber('') } @{ $without_number };

  $self->SUPER::save_objects(data => $with_number);
  $self->SUPER::save_objects(data => $without_number);
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;
  $self->add_cvar_columns_to_displayable_columns;

  $self->add_displayable_columns({ name => 'bin',                description => $::locale->text('Bin')                                                  },
                                 { name => 'buchungsgruppen_id', description => $::locale->text('Booking group (database ID)')                          },
                                 { name => 'buchungsgruppe',     description => $::locale->text('Booking group (name)')                                 },
                                 { name => 'description',        description => $::locale->text('Description')                                          },
                                 { name => 'drawing',            description => $::locale->text('Drawing')                                              },
                                 { name => 'ean',                description => $::locale->text('EAN')                                                  },
                                 { name => 'formel',             description => $::locale->text('Formula')                                              },
                                 { name => 'gv',                 description => $::locale->text('Business Volume')                                      },
                                 { name => 'has_sernumber',      description => $::locale->text('Has serial number')                                    },
                                 { name => 'image',              description => $::locale->text('Image')                                                },
                                 { name => 'lastcost',           description => $::locale->text('Last Cost')                                            },
                                 { name => 'listprice',          description => $::locale->text('List Price')                                           },
                                 { name => 'make_X',             description => $::locale->text('Make (vendor\'s database ID, number or name; with X being a number)') . ' [1]' },
                                 { name => 'microfiche',         description => $::locale->text('Microfiche')                                           },
                                 { name => 'model_X',            description => $::locale->text('Model (with X being a number)') . ' [1]'               },
                                 { name => 'lastcost_X',         description => $::locale->text('Lastcost (with X being a number)') . ' [1]'            },
                                 { name => 'not_discountable',   description => $::locale->text('Not Discountable')                                     },
                                 { name => 'notes',              description => $::locale->text('Notes')                                                },
                                 { name => 'obsolete',           description => $::locale->text('Obsolete')                                             },
                                 { name => 'onhand',             description => $::locale->text('On Hand') . ' [2]'                                     },
                                 { name => 'partnumber',         description => $::locale->text('Part Number')                                          },
                                 { name => 'partsgroup_id',      description => $::locale->text('Partsgroup (database ID)')                             },
                                 { name => 'partsgroup',         description => $::locale->text('Partsgroup (name)')                                    },
                                 { name => 'payment_id',         description => $::locale->text('Payment terms (database ID)')                          },
                                 { name => 'payment',            description => $::locale->text('Payment terms (name)')                                 },
                                 { name => 'price_factor_id',    description => $::locale->text('Price factor (database ID)')                           },
                                 { name => 'price_factor',       description => $::locale->text('Price factor (name)')                                  },
                                 { name => 'rop',                description => $::locale->text('ROP')                                                  },
                                 { name => 'sellprice',          description => $::locale->text('Sellprice')                                            },
                                 { name => 'shop',               description => $::locale->text('Shop article')                                         },
                                 { name => 'type',               description => $::locale->text('Article type')  . ' [3]'                             },
                                 { name => 'unit',               description => $::locale->text('Unit (if missing or empty default unit will be used)') },
                                 { name => 've',                 description => $::locale->text('Verrechnungseinheit')                                  },
                                 { name => 'weight',             description => $::locale->text('Weight')                                               },
                                );

  foreach my $language (@{ $self->all_languages }) {
    $self->add_displayable_columns({ name        => 'description_' . $language->article_code,
                                     description => $::locale->text('Description (translation for #1)', $language->description) },
                                   { name        => 'notes_' . $language->article_code,
                                     description => $::locale->text('Notes (translation for #1)', $language->description) });
  }

  my $idx = 0;
  foreach my $pricegroup (@{ $self->all_pricegroups }) {
    $idx++;
    $self->add_displayable_columns({ name        => 'pricegroup_' . $idx,
                                     description => $::locale->text("Sellprice for price group '#1'", $pricegroup->pricegroup) });
  }
}

1;
