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

sub full_description {
  my ($self) = @_;

  my $type = $self->type;
  my $op   = $self->op;

    $type eq 'customer'   ? t8('Customer')         . ' ' . $self->customer->displayable_name
  : $type eq 'vendor'     ? t8('Vendor')           . ' ' . $self->vendor->displayable_name
  : $type eq 'business'   ? t8('Type of Business') . ' ' . $self->business->displayable_name
  : $type eq 'partsgroup' ? t8('Group')            . ' ' . $self->partsgroup->displayable_name
  : $type eq 'pricegroup' ? t8('Pricegroup')       . ' ' . $self->pricegroup->displayable_name
  : $type eq 'part'       ? t8('Part')             . ' ' . $self->part->displayable_name
  : $type eq 'qty' ? (
       $op eq 'eq' ? t8('Qty equals #1',             $self->value_num_as_number)
     : $op eq 'lt' ? t8('Qty less than #1',          $self->value_num_as_number)
     : $op eq 'gt' ? t8('Qty more than #1',          $self->value_num_as_number)
     : $op eq 'le' ? t8('Qty equal or less than #1', $self->value_num_as_number)
     : $op eq 'ge' ? t8('Qty equal or more than #1', $self->value_num_as_number)
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
  : do { die "unknown type $type" }
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
