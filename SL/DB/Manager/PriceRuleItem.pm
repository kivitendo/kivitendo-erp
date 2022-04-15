# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::PriceRuleItem;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::PriceRuleItem' }

__PACKAGE__->make_manager_methods;

use SL::Locale::String qw(t8);
use List::Util qw(first);

use SL::DB::CustomVariableConfig;

my %ops = (
  'num'  => { eq => '=', le => '<=', ge => '>=' },
  'date' => { eq => '=', lt => '<', gt => '>' },
);

my @types = (
  { type => 'customer',   description => t8('Customer'),           customer => 1, vendor => 0, data_type => 'int',  data => sub { $_[0]->customer->id }, },
  { type => 'vendor',     description => t8('Vendor'),             customer => 0, vendor => 1, data_type => 'int',  data => sub { $_[0]->vendor->id }, },
  { type => 'business',   description => t8('Type of Business'),   customer => 1, vendor => 1, data_type => 'int',  data => sub { $_[0]->customervendor->business_id }, exclude_nulls => 1 },
  { type => 'reqdate',    description => t8('Reqdate'),            customer => 1, vendor => 1, data_type => 'date', data => sub { $_[0]->reqdate }, ops => 'date' },
  { type => 'transdate',  description => t8('Transdate'),          customer => 1, vendor => 1, data_type => 'date', data => sub { $_[0]->transdate }, ops => 'date' },
  { type => 'part',       description => t8('Part'),               customer => 1, vendor => 1, data_type => 'int',  data => sub { $_[1]->part->id }, },
  { type => 'pricegroup', description => t8('Pricegroup'),         customer => 1, vendor => 1, data_type => 'int',  data => sub { $_[1]->pricegroup_id }, exclude_nulls => 1 },
  { type => 'partsgroup', description => t8('Partsgroup'),         customer => 1, vendor => 1, data_type => 'int',  data => sub { $_[1]->part->partsgroup_id }, exclude_nulls => 1 },
  { type => 'qty',        description => t8('Qty'),                customer => 1, vendor => 1, data_type => 'num',  data => sub { $_[1]->qty }, ops => 'num' },
);

sub not_matching_sql_and_values {
  my ($class, %params) = @_;

  die 'must be called with a customer/vendor type' unless $params{type};
  my @args = @params{'record', 'record_item'};

  my (@tokens, @values);

  for my $def (@types, cached_cvar_types()) {
    my $type = $def->{type};
    next unless $def->{$params{type}};

    my $value = $def->{data}->(@args);

    my $type_token = $def->{cvar_config} ? "custom_variable_configs_id = '$def->{cvar_config}'" : "type = '$type'";

    if ($def->{exclude_nulls} && !defined $value) {
      push @tokens, $type_token;
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

      push @tokens, "$type_token AND (@{[ join(' OR ', map qq|($_)|, @sub_tokens) ]})";
    }
  }

  return join(' OR ', map "($_)", @tokens), @values;
}

sub cached_cvar_types {
  my $cache = $::request->cache("SL::DB::PriceRuleItem::cvar_types", []);

  @$cache = generate_cvar_types() if !@$cache;
  @$cache
}

# we only generate cvar types for cvar price_rules that are actually used to keep the query smaller
# these are cached per request
sub generate_cvar_types {
  my $cvar_configs = SL::DB::Manager::CustomVariableConfig->get_all(query => [
    id => [ \"(select distinct custom_variable_configs_id from price_rule_items where custom_variable_configs_id is not null)" ]
  ]);

  my @types;

  for my $config (@$cvar_configs) {

    push @types, {
      type          => "cvar_" . $config->id,
      description   => $config->description,
      customer      => 1,
      vendor        => 1,
      data_type     => 'text',
      data          => sub {
        $config->processed_flags->{editable}
          ? $_[1]->cvar_by_name($config->name)->value
          : $_[1]->part->cvar_by_name($config->name)->value
      },
      exclude_nulls => 1,
      cvar_config   => $config->id,
    } if $config->module eq 'IC' && $config->type eq 'select';

  }

  @types;
}

sub get_all_types {
  my ($class, $vc) = @_;

  $vc
  ? [ map { [ $_->{type}, $_->{description} ] } grep { $_->{$vc} } @types ]
  : [ map { [ $_->{type}, $_->{description} ] } @types ]
}

sub get_type {
  grep { $_->{type} eq $_[1] } @types
}

sub filter_match {
  my ($self, $type, $value) = @_;

  my $type_def = first { $_->{type} eq $type } @types;

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
