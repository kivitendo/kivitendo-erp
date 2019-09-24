# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::PriceRuleItem;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::PriceRuleItem' }

__PACKAGE__->make_manager_methods;

use SL::Locale::String qw(t8);
use List::Util qw();

use SL::DB::CustomVariableConfig;

my %ops = (
  'num'  => { eq => '=', le => '<=', ge => '>=', gt => '>', lt => '<' },
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
  { type => 've',         description => t8('Ve'),                 customer => 1, vendor => 1, data_type => 'num',  data => sub { $_[1]->part->ve }, ops => 'num' },
);

# text, textfield, htmlfield, bool are not supported
our %price_rule_type_by_cvar_type = (
  select    => 'text',
  customer  => 'int',
  vendor    => 'int',
  part      => 'int',
  number    => 'num',
  date      => 'date',
  text      => undef,
  textfield => undef,
  htmlfield => undef,
  bool      => undef,
);


# ITEM.part.cvar_by_name(var.config.name)

sub not_matching_sql_and_values {
  my ($class, %params) = @_;

  if (!$params{raw_data}) {
    die 'must be called with a customer/vendor type, record and record_item'
      unless $params{type} && $params{record} && $params{record_item};
  }

  my $raw_data = $params{raw_data};

  my (@tokens, @values);

  for my $def (@types, cached_cvar_types()) {
    my $type = $def->{type};
    if ($raw_data) {
      # raw mode: ignore filters not present, but don't care about customer/vendor split
      next if !exists $raw_data->{$type};
    } else {
      # record mode filter for everything, pay attention to customer/vendor split
      next unless $def->{$params{type}};
    }

    my $value = $raw_data ? $raw_data->{$type} : $def->{data}->(@params{'record', 'record_item'});

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
  my @supported_cvar_modules = qw(CT Contacts IC Projects ShipTo);

  my $cvar_configs = SL::DB::Manager::CustomVariableConfig->get_all(query => [ module => \@supported_cvar_modules ]);

  my @types;

  my %ops_by_cvar_type = (
    number    => 'num',
    date      => 'date',
  );

  for my $config (@$cvar_configs) {
    # cvars can be pretty complicated, but most of that luckily doesn't affect price rule filtering:
    #   - editable flags are copied to submodule entries - so those need to be preferred
    #   - cvars may be invalid - but in that case they just won't get crated so we won't find any
    #   - cvars may be restricted to partgroups, but again, in that case we simply won't find any
    #   - cvars may have different types of values () just like price_rule_items, but the ->value
    #     accessor already handles that, so we only need to set the price_rule type accordingly


    my %data_by_module = (
      IC => sub {
        raw_value(
          $config->processed_flags->{editable}
            ? $_[1]->cvar_by_name($config->name)->value
            : $_[1]->part->cvar_by_name($config->name)->value
        );
      },
      CT => sub {
        raw_value(
          $_[0]->customervendor->cvar_by_name($config->name)->value
        );
      },
      Projects => sub {
        raw_value(
          $_[1]->project ? $_[1]->project->cvar_by_name($config->name)->value :
          $_[0]->globalproject ? $_[0]->globalproject->cvar_by_name($config->name)->value : undef
        );
      },
      Contacts => sub {
        raw_value(
          $_[0]->contact ? $_[0]->contact->cvar_by_name($config->name)->value : undef
        );
      },
      ShipTo => sub {
        raw_value(
          $_[0]->custom_shipto ? $_[0]->custom_shipto->cvar_by_name($config->name)->value :
          $_[0]->can('shipto') && $_[0]->shipto ? $_[0]->shipto->cvar_by_name($config->name)->value : undef

        );
      },
    );

    my $data_type;
    if (exists $price_rule_type_by_cvar_type{$config->type}) {
      # known but undef typedefs are ignored.
      # those cvar configs are not supported and can not be used in price rules
      $data_type = $price_rule_type_by_cvar_type{$config->type} or next;
    } else {
      die "cvar type @{[$config->type]} " . $config->description . " is not supported in price rules";
    }

    my $ops = $ops_by_cvar_type{$config->type};

    push @types, {
      type          => "cvar_" . $config->id,
      description   => $config->description,
      customer      => 1,
      vendor        => 1,
      data_type     => $data_type,
      data          => $data_by_module{$config->module},
      exclude_nulls => 1,
      cvar_config   => $config->id,
      ops           => $ops,
    };
  }

  @types;
}

sub raw_value {
  my ($value) = @_;
  return if !defined $value;
  return $value->id if (ref $value) =~ /Part|Customer|Contact|Vendor|Project/;
  return $value if (ref $value) =~ /DateTime/;
  die "reference value unsupported for binding to price_rules, got ref " . ref $value if ref $value;
  $value;
}

sub get_all_types {
  my ($class, $vc) = @_;
  my @types = $class->ordered_types;

  $vc
  ? [ map { [ $_->{type}, $_->{description} ] } grep { $_->{$vc} } @types ]
  : [ map { [ $_->{type}, $_->{description} ] } @types ]
}

sub ordered_types {
  List::Util::uniq(grep({ $types{$_} } @{ $::instance_conf->get_price_rule_type_order }), @types);
}

sub get_types {
  @types;
}

sub get_type_definitions {
  \%types;
}

sub get_type {
  grep { $_->{type} eq $_[1] } @types
}

1;
