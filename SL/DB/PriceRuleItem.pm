# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PriceRuleItem;

use strict;

use SL::DB::MetaSetup::PriceRuleItem;
use SL::DB::Manager::PriceRuleItem;
use SL::Locale::String qw(t8);

__PACKAGE__->meta->initialize;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(object operator) ],
);

sub digest {
  join $;,
    $_[0]->type,
    $_[0]->op // '',
    ($_[0]->value_date ? $_[0]->value_date->ymd : '-'),
    ($_[0]->value_int // '-'),
    ($_[0]->value_num // '-'),
    ($_[0]->value_text // '');
}

sub match {
  my ($self, %params) = @_;

  die 'need record'      unless $params{record};
  die 'need record_item' unless $params{record_item};

  $self->${\ "match_" . $self->type }(%params);
}

sub match_customer {
  $_[0]->value_int == $_[1]{record}->customer_id;
}
sub match_vendor {
  $_[0]->value_int == $_[1]{record}->vendor_id;
}
sub match_business {
  $_[0]->value_int == $_[1]{record}->customervendor->business_id;
}
sub match_partsgroup {
  $_[0]->value_int == $_[1]{record_item}->parts->partsgroup_id;
}
sub match_part {
  $_[0]->value_int == $_[1]{record_item}->parts_id;
}
sub match_qty {
  if ($_[0]->op eq 'eq') {
    return $_[0]->value_num == $_[1]{record_item}->qty
  } elsif ($_[0]->op eq 'le') {
    return $_[0]->value_num <  $_[1]{record_item}->qty;
  } elsif ($_[0]->op eq 'ge') {
    return $_[0]->value_num >  $_[1]{record_item}->qty;
  }
}
sub match_ve {
  if ($_[0]->op eq 'eq') {
    return $_[0]->value_num == $_[1]{record_item}->part->ve;
  } elsif ($_[0]->op eq 'le') {
    return $_[0]->value_num <  $_[1]{record_item}->part->ve;
  } elsif ($_[0]->op eq 'ge') {
    return $_[0]->value_num >  $_[1]{record_item}->part->ve;
  }
}
sub match_reqdate {
  if ($_[0]->op eq 'eq') {
    return $_[0]->value_date == $_[1]{record}->reqdate;
  } elsif ($_[0]->op eq 'lt') {
    return $_[0]->value_date <  $_[1]{record}->reqdate;
  } elsif ($_[0]->op eq 'gt') {
    return $_[0]->value_date >  $_[1]{record}->reqdate;
  }
}
sub match_transdate {
  if ($_[0]->op eq 'eq') {
    return $_[0]->value_date == $_[1]{record}->transdate;
  } elsif ($_[0]->op eq 'lt') {
    return $_[0]->value_date <  $_[1]{record}->transdate;
  } elsif ($_[0]->op eq 'gt') {
    return $_[0]->value_date >  $_[1]{record}->transdate;
  }
}
sub match_pricegroup {
  $_[0]->value_int == $_[1]{record_item}->customervendor->pricegroup_id;
}

sub part {
  require SL::DB::Part;
  SL::DB::Part->load_cached($_[0]->value_int);
}
sub customer {
  require SL::DB::Customer;
  SL::DB::Customer->load_cached($_[0]->value_int);
}

sub vendor {
  require SL::DB::Vendor;
  SL::DB::Vendor->load_cached($_[0]->value_int);
}

sub business {
  require SL::DB::Business;
  SL::DB::Business->load_cached($_[0]->value_int);
}

sub partsgroup {
  require SL::DB::PartsGroup;
  SL::DB::PartsGroup->load_cached($_[0]->value_int);
}

sub pricegroup {
  require SL::DB::Pricegroup;
  SL::DB::Pricegroup->load_cached($_[0]->value_int);
}

sub cvar_config {
  die "not a cvar price rule item" unless $_[0]->type eq 'cvar';
  &custom_variable_configs
}

sub full_description {
  my ($self) = @_;

  my $type = $self->type;
  my $op   = $self->op;

    $type eq 'customer'   ? t8('Customer')         . ' ' . $self->customer->displayable_name
  : $type eq 'vendor'     ? t8('Vendor')           . ' ' . $self->vendor->displayable_name
  : $type eq 'business'   ? t8('Type of Business') . ' ' . $self->business->displayable_name
  : $type eq 'partsgroup' ? t8('Partsgroup')       . ' ' . $self->partsgroup->displayable_name
  : $type eq 'pricegroup' ? t8('Pricegroup')       . ' ' . $self->pricegroup->displayable_name
  : $type eq 'part'       ? t8('Part')             . ' ' . $self->part->displayable_name
  : $type eq 'qty' ? (
       $op eq 'eq' ? t8('Qty equals #1',             $self->value_num_as_number)
     : $op eq 'lt' ? t8('Qty less than #1',          $self->value_num_as_number)
     : $op eq 'gt' ? t8('Qty more than #1',          $self->value_num_as_number)
     : $op eq 'le' ? t8('Qty equal or less than #1', $self->value_num_as_number)
     : $op eq 'ge' ? t8('Qty equal or more than #1', $self->value_num_as_number)
     : do { die "unknown op $op for type $type" } )
  : $type eq 've' ? (
       $op eq 'eq' ? t8('Ve equals #1',             $self->value_num_as_number)
     : $op eq 'lt' ? t8('Ve less than #1',          $self->value_num_as_number)
     : $op eq 'gt' ? t8('Ve more than #1',          $self->value_num_as_number)
     : $op eq 'le' ? t8('Ve equal or less than #1', $self->value_num_as_number)
     : $op eq 'ge' ? t8('Ve equal or more than #1', $self->value_num_as_number)
     : do { die "unknown op $op for type $type" } )
  : $type eq 'reqdate' ? (
       $op eq 'eq' ? t8('Reqdate is #1',        $self->value_date_as_date)
     : $op eq 'lt' ? t8('Reqdate is before #1', $self->value_date_as_date)
     : $op eq 'gt' ? t8('Reqdate is after #1',  $self->value_date_as_date)
     : do { die "unknown op $op for type $type" } )
  : $type eq 'transdate' ? (
       $op eq 'eq' ? t8('Transdate is #1',        $self->value_date_as_date)
     : $op eq 'lt' ? t8('Transdate is before #1', $self->value_date_as_date)
     : $op eq 'gt' ? t8('Transdate is after #1',  $self->value_date_as_date)
     : do { die "unknown op $op for type $type" } )
  : $type eq 'cvar' ? $self->cvar_rule_description($type, $op)
  : do { die "unknown type $type" }
}

sub cvar_rule_description {
  my ($self, $type, $op) = @_;
  my $config      = $self->cvar_config;
  my $description = $config->description;

  t8('Custom Variables (Abbreviation)') . ' ' . (
      $config->type eq 'select'   ? t8("#1 is #2", $description, $self->value_text)
    : $config->type eq 'customer' ? t8("#1 is #2", $description, $self->customer->displayable_name)
    : $config->type eq 'vendor'   ? t8("#1 is #2", $description, $self->vendor->displayable_name)
    : $config->type eq 'part'     ? t8("#1 is #2", $description, $self->part->displayable_name)
    : $config->type eq 'number'   ? (
          $op eq 'eq' ? t8('#1 equals #2',             $description, $self->value_num_as_number)
        : $op eq 'lt' ? t8('#1 less than #2',          $description, $self->value_num_as_number)
        : $op eq 'gt' ? t8('#1 more than #2',          $description, $self->value_num_as_number)
        : $op eq 'le' ? t8('#1 equal or less than #2', $description, $self->value_num_as_number)
        : $op eq 'ge' ? t8('#1 equal or more than #2', $description, $self->value_num_as_number)
        : do { die "unknown op $op for type ", $config->type }
      )
     : $config->type eq 'date'     ? (
           $op eq 'eq' ? t8('#1 is #2',        $description, $self->value_date_as_date)
         : $op eq 'lt' ? t8('#1 is before #2', $description, $self->value_date_as_date)
         : $op eq 'gt' ? t8('#1 is after #2',  $description, $self->value_date_as_date)
         : do { die "unknown op $op for type ", $config->type }
       )
    : do { die "unknown type " . $config->type }
  );
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('Rule for part must not be empty')     if $self->type eq 'part'     && !$self->value_int;
  push @errors, t8('Rule for customer must not be empty') if $self->type eq 'customer' && !$self->value_int;
  push @errors, t8('Rule for vendor must not be empty')   if $self->type eq 'vendor'   && !$self->value_int;

  return @errors;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::PriceRuleItem - Rule element for price rules

=head1 SYNOPSIS

  my @errors      = $price_rule_item->validate;
  my $is_match    = $price_rule_item->match(record => $record, record_item => $record_item);

  # localized description of the rule
  my $description = $price_rule_item->full_description;

  # unique representation used to implement value equality between objects within a price_rule
  my $digest      = $price_rule_item->digest;

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@opendynamic.deE<gt>

=cut
