# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::PriceRuleItem;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::PriceRuleItem' }

__PACKAGE__->make_manager_methods;

use SL::Locale::String qw(t8);

my @types = qw(
  part customer vendor business partsgroup qty reqdate transdate pricegroup
);

my %ops = (
  'num'  => { eq => '=', le => '<=', ge => '>=' },
  'date' => { eq => '=', lt => '<', gt => '>' },
);

my %types = (
  'customer'            => { description => t8('Customer'),           customer => 1, vendor => 0, data_type => 'int',  data => sub { $_[0]->customer->id }, },
  'vendor'              => { description => t8('Vendor'),             customer => 0, vendor => 1, data_type => 'int',  data => sub { $_[0]->vendor->id }, },
  'business'            => { description => t8('Type of Business'),   customer => 1, vendor => 1, data_type => 'int',  data => sub { $_[0]->customervendor->business_id }, exclude_nulls => 1 },
  'reqdate'             => { description => t8('Reqdate'),            customer => 1, vendor => 1, data_type => 'date', data => sub { $_[0]->reqdate }, ops => 'date' },
  'transdate'           => { description => t8('Transdate'),          customer => 1, vendor => 1, data_type => 'date', data => sub { $_[0]->transdate }, ops => 'date' },
  'part'                => { description => t8('Part'),               customer => 1, vendor => 1, data_type => 'int',  data => sub { $_[1]->part->id }, },
  'pricegroup'          => { description => t8('Pricegroup'),         customer => 1, vendor => 1, data_type => 'int',  data => sub { $_[1]->pricegroup_id }, exclude_nulls => 1 },
  'partsgroup'          => { description => t8('Partsgroup'),         customer => 1, vendor => 1, data_type => 'int',  data => sub { $_[1]->part->partsgroup_id }, exclude_nulls => 1 },
  'qty'                 => { description => t8('Qty'),                customer => 1, vendor => 1, data_type => 'num',  data => sub { $_[1]->qty }, ops => 'num' },
);

sub not_matching_sql_and_values {
  my ($class, %params) = @_;

  die 'must be called with a customer/vendor type' unless $params{type};
  my @args = @params{'record', 'record_item'};

  my (@tokens, @values);

  for my $type (@types) {
    my $def = $types{$type};
    next unless $def->{$params{type}};

    my $value = $def->{data}->(@args);

    if ($def->{exclude_nulls} && !defined $value) {
      push @tokens, "type = '$type'";
    } else {
      my @sub_tokens;
      if ($def->{ops}) {
        my $ops = $ops{$def->{ops}};

        for (keys %$ops) {
          push @sub_tokens, "op = '$_' AND NOT ? $ops->{$_} value_$def->{data_type}";
          push @values, $value;
        }
      } else {
        push @sub_tokens, "NOT value_$def->{data_type} = ?";
        push @values, $value;
      }

      push @tokens, "type = '$type' AND (@{[ join(' OR ', map qq|($_)|, @sub_tokens) ]})";
    }
  }

  return join(' OR ', map "($_)", @tokens), @values;
}

sub get_all_types {
  my ($class, $vc) = @_;

  $vc
  ? [ map { [ $_, $types{$_}{description} ] } grep { $types{$_}{$vc} } map { $_ } @types ]
  : [ map { [ $_, $types{$_}{description} ] } map { $_ } @types ]
}

sub get_type {
  $types{$_[1]}
}

sub filter_match {
  my ($self, $type, $value) = @_;

  my $type_def = $types{$type};

  if (!$type_def->{ops}) {
    my $evalue   = $::form->get_standard_dbh->quote($value);
    return "value_$type_def->{data_type} = $evalue";
  } elsif ($type_def->{ops} eq 'date') {
    my $date_value   = $::form->get_standard_dbh->quote(DateTime->from_kivitendo($value));
    return "
      (value_$type_def->{data_type} > $date_value AND op = 'lt') OR
      (value_$type_def->{data_type} < $date_value AND op = 'gt') OR
      (value_$type_def->{data_type} = $date_value AND op = 'eq')
    ";
  } elsif ($type_def->{ops} eq 'num') {
    my $num_value   = $::form->get_standard_dbh->quote($::form->parse_amount(\%::myconfig, $value));
    return "
      (value_$type_def->{data_type} >= $num_value AND op = 'le') OR
      (value_$type_def->{data_type} <= $num_value AND op = 'ge') OR
      (value_$type_def->{data_type} =  $num_value AND op = 'eq')
    ";
  }
}


1;
