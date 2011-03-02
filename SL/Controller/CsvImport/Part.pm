package SL::Controller::CsvImport::Part;

use strict;

use SL::Helper::Csv;

use SL::DB::Buchungsgruppe;
use SL::DB::PartsGroup;
use SL::DB::PaymentTerm;
use SL::DB::PriceFactor;
use SL::DB::Unit;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(table) ],
 'scalar --get_set_init' => [ qw(bg_by settings parts_by price_factors_by units_by payment_terms_by packing_types_by partsgroups_by) ],
);

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

sub init_payment_terms_by {
  my ($self) = @_;

  my $all_payment_terms = SL::DB::Manager::PaymentTerm->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_payment_terms } } ) } qw(id description) };
}

sub init_packing_types_by {
  my ($self) = @_;

  my $all_packing_types = SL::DB::Manager::PackingType->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_packing_types } } ) } qw(id description) };
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

  my $parts_by = { id         => { map { ( $_->id => $_ ) } grep { !$_->assembly } @{ $self->existing_objects } },
                   partnumber => { part    => { },
                                   service => { } } };

  foreach my $part (@{ $self->existing_objects }) {
    next if $part->assembly;
    $parts_by->{partnumber}->{ $part->type }->{ $part->partnumber } = $part;
  }

  return $parts_by;
}

sub init_settings {
  my ($self) = @_;

  return { map { ( $_ => $self->controller->profile->get($_) ) } qw(apply_buchungsgruppe default_buchungsgruppe article_number_policy
                                                                    sellprice_places sellprice_adjustment sellprice_adjustment_type
                                                                    shoparticle_if_missing parts_type) };
}

sub check_objects {
  my ($self) = @_;

  return unless @{ $self->controller->data };

  foreach my $entry (@{ $self->controller->data }) {
    my $object   = $entry->{object};
    my $raw_data = $entry->{raw_data};

    next unless $self->check_buchungsgruppe($entry);
    next unless $self->check_type($entry);
    next unless $self->check_unit($entry);
    next unless $self->check_price_factor($entry);
    next unless $self->check_payment($entry);
    next unless $self->check_packing_type($entry);
    next unless $self->check_partsgroup($entry);
    $self->check_existing($entry);
    $self->handle_prices($entry) if $self->settings->{sellprice_adjustment};
    $self->handle_shoparticle($entry);
    $self->set_various_fields($entry);
  }

  $self->add_columns(qw(type)) if $self->settings->{parts_type} eq 'mixed';
  $self->add_columns(qw(buchungsgruppen_id unit));
  $self->add_columns(map { "${_}_id" } grep { exists $self->controller->data->[0]->{raw_data}->{$_} } qw (price_factor payment packing_type partsgroup));
  $self->add_columns(qw(shop)) if $self->settings->{shoparticle_if_missing};
}

sub check_duplicates {
  my ($self, %params) = @_;

  my $normalizer = sub { my $name = $_[0]; $name =~ s/[\s,\.\-]//g; return $name; };
  my $name_maker = sub { return $normalizer->($_[0]->description) };

  my %by_name;
  if ('check_db' eq $self->controller->profile->get('duplicates')) {
    %by_name = map { ( $name_maker->($_) => 'db' ) } @{ $self->existing_objects };
  }

  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    my $name = $name_maker->($entry->{object});

    if (!$by_name{ $name }) {
      $by_name{ $name } = 'csv';

    } else {
      push @{ $entry->{errors} }, $by_name{ $name } eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file');
    }
  }
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

  push @{ $entry->{errors} }, $::locale->text('Error: Buchungsgruppe missing or invalid');
  return 0;
}

sub check_existing {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $entry->{part} = $self->parts_by->{partnumber}->{ $object->type }->{ $object->partnumber };

  if ($self->settings->{article_number_policy} eq 'update_prices') {
    if ($entry->{part}) {
      map { $object->$_( $entry->{part}->$_ ) } qw(sellprice listprice lastcost);
      $entry->{priceupdate} = 1;
    }

  } else {
    $object->partnumber('####') if $entry->{part};
  }
}

sub handle_prices {
  my ($self, $entry) = @_;

  foreach my $column (qw(sellprice listprice lastcost)) {
    next unless $self->controller->headers->{used}->{ $column };

    my $adjustment = $self->settings->{sellprice_adjustment};
    my $value      = $entry->{object}->$column;

    $value = $self->settings->{sellprice_adjustment_type} eq 'percent' ? $value * (100 + $adjustment) / 100 : $value + $adjustment;
    $entry->{object}->$column($::form->round_amount($value, $self->settings->{sellprice_places}));
  }
}

sub handle_shoparticle {
  my ($self, $entry) = @_;

  $entry->{object}->shop(1) if $self->settings->{shoparticle_if_missing} && !$self->controller->headers->{used}->{shop};
}

sub check_type {
  my ($self, $entry) = @_;

  my $bg = $self->bg_by->{id}->{ $entry->{object}->buchungsgruppen_id };
  die "Program logic error" if !$bg;

  my $type = $self->settings->{parts_type};
  if ($type eq 'mixed') {
    $type = $entry->{raw_data}->{type} =~ m/^p/i ? 'part'
          : $entry->{raw_data}->{type} =~ m/^s/i ? 'service'
          :                                        undef;
  }

  $entry->{object}->income_accno_id(  $bg->income_accno_id_0 );
  $entry->{object}->expense_accno_id( $bg->expense_accno_id_0 );

  if ($type eq 'part') {
    $entry->{object}->inventory_accno_id( $bg->inventory_accno_id );

  } elsif ($type ne 'service') {
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

sub check_payment {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not payment ID is valid.
  if ($object->payment_id && !$self->payment_terms_by->{id}->{ $object->payment_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid payment terms');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->payment_id && $entry->{raw_data}->{payment}) {
    my $terms = $self->payment_terms_by->{description}->{ $entry->{raw_data}->{payment} };

    if (!$terms) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid payment terms');
      return 0;
    }

    $object->payment_id($terms->id);
  }

  return 1;
}

sub check_packing_type {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not packing type ID is valid.
  if ($object->packing_type_id && !$self->packing_types_by->{id}->{ $object->packing_type_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid packing type');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->packing_type_id && $entry->{raw_data}->{packing_type}) {
    my $type = $self->packing_types_by->{description}->{ $entry->{raw_data}->{packing_type} };

    if (!$type) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid packing type');
      return 0;
    }

    $object->packing_type_id($type->id);
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

  # Check whether or unit is valid.
  if (!$self->units_by->{name}->{ $object->unit }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Unit missing or invalid');
    return 0;
  }

  return 1;
}

sub set_various_fields {
  my ($self, $entry) = @_;

  $entry->{object}->priceupdate(DateTime->now_local);
}

sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;
  delete $profile->{type};

  $::lxdebug->dump(0, "prof", $profile);

  return $profile;
}


# TODO:
#  priceupdate aus Profil raus
#  CVARs ins Profil rein

1;
