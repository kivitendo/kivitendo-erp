# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PriceRuleMacro;

use strict;

use SL::DB::MetaSetup::PriceRuleMacro;
use SL::DB::Manager::PriceRuleMacro;
use SL::MoreCommon;
use SL::Locale::String;

# use SL::Presenter::CustomerVendor;
# use SL::Presenter::Part;
# use SL::Presenter::Business;
# use SL::Presenter::PartsGroup;
# use SL::Presenter::Pricegroup;

use SL::DB::Helper::Attr;
use SL::DBUtils qw(selectfirst_array_query);

use List::Util ();
use List::UtilsBy ();

__PACKAGE__->meta->add_relationship(
  price_rules => {
    type         => 'one to many',
    class        => 'SL::DB::PriceRule',
    column_map   => { 'id' => 'price_rule_macro_id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_set_format_version');

# attributes that are both in price_rule_macros, the json definition and the
# price_rules and need to be copied between them
my @dual_attributes = qw(name priority obsolete type notes);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(parsed_definition) ],
);

my @version_upgrades = (
  sub { }, # 0: ensure that v1 is always set
  sub {
    # 1: "qty" in condition qty was changed to "num" sometime during development.
     _upgrade_node($_[0], sub { $_[0]->{type} eq 'qty' }, sub { $_[0]->{num} = delete $_[0]->{qty} if $_[0]->{qty} });
  },
  sub {
    # 2: "simple action" was not roundtrip safe and changed later
    #    change the early versions to typed inputs
     _upgrade_node($_[0], sub {
       $_[0]->{type} eq 'simple_action' && !$_[0]->{price_or_discount}
     },
     sub {
       my ($node) = @_;
       if ($node->{price}) {
         $node->{type} = 'price_action';
         delete $node->{discount};
         delete $node->{reduction};
       }
       if ($node->{discount}) {
         $node->{type} = 'discount_action';
         delete $node->{price};
         delete $node->{reduction};
       }
       if ($node->{reduction}) {
         $node->{type} = 'reduction_action';
         delete $node->{price};
         delete $node->{discount};
       }
     });
  },
  sub {
    # 3: date conditions changed to use epoch as internal representation
    _upgrade_node($_[0],
      sub { $_[0]->{type} =~ /date/ },
      sub {
        $_[0]->{date_as_iso} = delete $_[0]->{date} if $_[0]->{date};
      });
  },
  sub {
    # 4: migration script mistakenly uses transdate/reqdate in those conditions
    _upgrade_node($_[0],
      sub { $_[0]->{type} =~ /reqdate/ },
      sub { $_[0]->{date} = delete $_[0]->{reqdate} if $_[0]->{reqdate}; },
    );
    _upgrade_node($_[0],
      sub { $_[0]->{type} =~ /transdate/ },
      sub { $_[0]->{date} = delete $_[0]->{transdate} if $_[0]->{transdate}; },
    );

  },
  sub {
    # 5: update simple_action to distinct slots again
    _upgrade_node($_[0],
      sub { $_[0]->{type} eq 'simple_action' && exists $_[0]->{price_or_discount} },
      sub {
        my $price_or_discount = delete $_[0]->{price_or_discount};
        $_[0]->{price}     = $price_or_discount if $_[0]->{price_type} == SL::DB::Manager::PriceRule::PRICE_NEW();
        $_[0]->{discount}  = $price_or_discount if $_[0]->{price_type} == SL::DB::Manager::PriceRule::PRICE_DISCOUNT();
        $_[0]->{reduction} = $price_or_discount if $_[0]->{price_type} == SL::DB::Manager::PriceRule::PRICE_REDUCED_MASTER_DATA();
      },
    );
  },
);

sub priority_as_text {
  my ($self) = @_;

  return t8('Override') if $self->priority == 4;
  t8('Normal');
}

sub validate {
  my ($self) = @_;

  $self->parsed_definition->validate;
}

sub definition {
  my ($self, $data) = @_;

  if (defined $data) {
    $self->json_definition(SL::JSON::to_json($data));
    $self->parsed_definition(undef);
  }
  if (defined wantarray) {
    eval {
      SL::JSON::from_json($self->json_definition);
    } or do {
      die "json error: $@ in @{[ $self->json_definition ]}";
    }
  }
}

sub update_definition {
  my ($self) = @_;
  $self->definition($self->parsed_definition->as_tree);
  $self->definition->{$_} = $self->$_ for @dual_attributes;

  $self->definition;
}

sub update_from_definition {
  my ($self) = @_;
  $self->$_($self->definition->{$_}) for @dual_attributes;
}

sub copy_attributes_to_price_rules {
  my ($self, @price_rules) = @_;

  for my $price_rule (@price_rules) {
    $price_rule->assign_attributes($_ => $self->$_) for @dual_attributes;
  }
}

sub init_parsed_definition {
  die 'definition does not seem to be a json object' unless 'HASH' eq ref($_[0]->definition);
  $_[0]->upgrade_version;

  my %params = %{ $_[0]->definition };

  # do not save id in definition, makes it easier to clone
  delete $params{id};

  SL::PriceRuleMacro::Definition->new(%params);
}

sub in_use {
  my ($self) = @_;
  # too slow, 3x number of compiled price rules Rose calls, 13s for 400 rules
  #   List::Util::any { $_->in_use } $_[0]->price_rules

  # get all active_price_rule specs
  my $query = <<"SQL";
  WITH sources(source) AS (
      SELECT active_price_source FROM orderitems
      UNION ALL
      SELECT active_discount_source FROM orderitems
      UNION ALL
      SELECT active_price_source FROM delivery_order_items
      UNION ALL
      SELECT active_discount_source FROM delivery_order_items
      UNION ALL
      SELECT active_price_source FROM invoice
      UNION ALL
      SELECT active_discount_source FROM invoice
  ),
  active_price_rules(id) AS (
    SELECT distinct substr(source, 13)::integer FROM sources WHERE source like 'price_rules/%'
  )
  SELECT COUNT(*) FROM price_rules
  INNER JOIN active_price_rules ON (price_rules.id = active_price_rules.id)
  WHERE price_rule_macro_id = ?
SQL

  my ($in_use) = selectfirst_array_query($::form, $self->db->dbh, $query, $self->id);
  $in_use;
}

sub upgrade_version {
  my ($self) = @_;

  my $definition = $self->definition;

  for ($definition->{format_version} .. $#version_upgrades) {
    $version_upgrades[$_]->($definition);
  }

  # save upgraded back to json
  $definition->{format_version} = $self->latest_version;
  $self->definition($definition);
  $self;
}

sub latest_version {
  $#version_upgrades + 1;
}


sub _before_save_set_format_version {
  my ($self) = @_;
  if ($self->definition->{format_version} != $self->latest_version) {
    $self->definition->{format_version} = $self->latest_version;
    $self->definition($self->definition);
  }

  1;
}

# used for version_upgrades
sub _upgrade_node {
  my ($definition, $search_code, $apply_code) = @_;

  die "not a hashref" unless 'HASH' eq ref $definition;

  if ($search_code->($definition)) {
    $apply_code->($definition);
  }

  for my $key (keys %$definition) {
    if ('HASH' eq ref $definition->{$key}) {
      _upgrade_node($definition->{$key}, $search_code, $apply_code);
    }

    if ('ARRAY' eq ref $definition->{$key}) {
      for (@{ $definition->{$key} }) {
        _upgrade_node($_, $search_code, $apply_code) if 'HASH' eq ref $_;
      }
    }
  }
}

# some helper classes, maybe put them into their own files later
my %classes = (
  definition            => 'SL::PriceRuleMacro::Definition',
  condition             => 'SL::PriceRuleMacro::Condition',
  container_and         => 'SL::PriceRuleMacro::Condition::ContainerAnd',
  container_or          => 'SL::PriceRuleMacro::Condition::ContainerOr',
  customer              => 'SL::PriceRuleMacro::Condition::Customer',
  vendor                => 'SL::PriceRuleMacro::Condition::Vendor',
  business              => 'SL::PriceRuleMacro::Condition::Business',
  part                  => 'SL::PriceRuleMacro::Condition::Part',
  partsgroup            => 'SL::PriceRuleMacro::Condition::Partsgroup',
  pricegroup            => 'SL::PriceRuleMacro::Condition::Pricegroup',
  ve                    => 'SL::PriceRuleMacro::Condition::Ve',
  qty                   => 'SL::PriceRuleMacro::Condition::Qty',
  qty_range             => 'SL::PriceRuleMacro::Condition::QtyRange',
  reqdate               => 'SL::PriceRuleMacro::Condition::Reqdate',
  transdate             => 'SL::PriceRuleMacro::Condition::Transdate',
  action                => 'SL::PriceRuleMacro::Action',
  conditional_action    => 'SL::PriceRuleMacro::ConditionalAction',
  action_container_and  => 'SL::PriceRuleMacro::Action::ContainerAnd',
  simple_action         => 'SL::PriceRuleMacro::Action::Simple',
  price_action          => 'SL::PriceRuleMacro::Action::Price',
  discount_action       => 'SL::PriceRuleMacro::Action::Discount',
  reduction_action      => 'SL::PriceRuleMacro::Action::Reduction',
  price_scale_action    => 'SL::PriceRuleMacro::Action::PriceScale',
  price_scale_action_line => 'SL::PriceRuleMacro::Action::PriceScaleLine',
  parts_price_list_action => 'SL::PriceRuleMacro::Action::PartsPriceList',
  parts_price_list_action_line => 'SL::PriceRuleMacro::Action::PartsPriceListLine',
  list_template_action  => 'SL::PriceRuleMacro::Action::ListTemplate',
  list_template_action_line => 'SL::PriceRuleMacro::Action::ListTemplateLine',
);
my %r_classes = reverse %classes;

my $meta_cache;
sub create_definition_meta {
  $meta_cache //= +{
    map {
      my $type = $_;
      $type => {
        has_elements => {
          map {
            $_ => {
              type => $classes{$_} ? $_ : undef,
              can_be_array => $classes{$type}->can_array($_),
            }
          } $classes{$type}->safe_elements
        },
        can_be => [
          grep { $classes{$_} ne $classes{$type} && $classes{$_}->isa($classes{$type}) } keys %classes
        ],
        abstract => $classes{$type}->abstract ? 1 : 0,
        internal_class => $classes{$type},
        name => $classes{$type}->description,
      }
    } keys %classes
  }
}

package SL::PriceRuleMacro::Element {
  sub new {
    my $class = shift;
    my %args  = @_;

    if ($args{type}) {
      if ($classes{$args{type}} && $classes{$args{type}}->isa($class)) {
        my $new_class = $classes{delete $args{type}};
        return $new_class->new(%args);
      } else {
        die "type $args{type} not allowed in $class";
      }
    }

    my $self = bless {}, $class;
    $self->init(@_);
    $self;
  }

  sub init {
    my $self = shift;
    while (@_) {
      my $method = shift;
      my $value  = shift;
      if ($self->can($method)) {
        my $type = $classes{$method};
        if ($type) {
          if ('ARRAY' eq ref $value) {
            $self->$method([ map { 'HASH' eq ref $_ ? $type->new(%$_) : $_ } @$value ]);
          } else {
            $self->$method('HASH' eq ref $value ? $type->new(%$value) : $value);
          }
        } else {
          $self->$method($value);
        }
      } else {
        die "format error: $method is not accepted in @{[ ref $self ]}";
      }
    }
  }

  sub elements {
    die 'needs to be implemented';
  }

  sub abstract {
    ! eval { $_[0]->elements; 1 }
  }

  sub safe_elements {
    $_[0]->abstract ? () : $_[0]->elements
  }

  sub array_elements {}

  sub can_array {
    for ($_[0]->array_elements) {
      return 1 if $_ eq $_[1]
    }
    return 0
  }

  sub is_array {
    return if List::Util::none { $_ eq $_[1] } $_[0]->array_elements;
    return unless $_[0]->{ $_[1] };
    return 'ARRAY' eq ref $_[0]->{ $_[1] };
  }

  sub validate {
    my ($self) = @_;

    for ($self->elements) {
      if ($classes{$_} && $self->$_) {
        $_->validate for SL::MoreCommon::listify($self->$_);
      }
    }
  }

  sub as_tree {
    my ($self, $slot) = @_;

    my $obj = {};

    for my $method ($self->elements) {
      my $val = $self->$method;
      my $ref;

      next unless defined $val;

      if ($classes{$method}) {
        if ('ARRAY' eq ref $val) {
          $ref = [ map { $_->as_tree($method) } @$val ];
        } elsif (ref $val) {
          $ref = $val->as_tree($method);
        } else {
          die "encountered non-blessed, non-ref value for class method '$method' in @{[ ref $self ]}";
        }
      } else {
        $ref = $val;
      }
      $obj->{$method} = $ref;
    }

    if ($slot && $slot ne $self->type) {
      $obj->{type} = $self->type;
    }

    $obj;
  }

  sub allowed_elements {
    my ($element) = @_;

    my $all_meta = SL::DB::PriceRuleMacro->create_definition_meta;

    # todo: make this work for condition
    return [] unless my $meta = $all_meta->{$element->type};

    my @elements = List::UtilsBy::nsort_by {
      $all_meta->{$_}{internal_class}->order
    } grep {
      $all_meta->{$_}{internal_class}->order > 0
    } map {
      $all_meta->{$_}{abstract}
        ? @{ $all_meta->{$_}{can_be} }
        : $_
    } $element->type;

    @elements
  }

  sub description {
    SL::Locale::String::t8('Element')
  }

  sub hidden {
    # overwrite truish to hide an element from selection
  }

  sub order {
    0
  }
}

package SL::PriceRuleMacro::Definition {
  our @ISA      = ('SL::PriceRuleMacro::Element');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->init(@_);
    $self;
  }

  sub elements {
    qw(condition action name notes priority obsolete format_version type itime mtime)
  }

  sub array_elements {
    qw(condition action)
  }

  sub cross (&\@\@) {
    no warnings 'once';
    my ($code, $x, $y) = @_;
    map {
      my $s = $_;
      map {
        $code->(local $a = $_, local $b = $s);
      } @$x
    } @$y;
  }

  sub price_rules {
    my ($self) = @_;
    my @price_rules = map { $_->price_rules } SL::MoreCommon::listify($self->action // []);
    my @items       = map { $_->price_rule_items } SL::MoreCommon::listify($self->condition // []);

    return @price_rules if !@items;

    cross {
      my ($price_rule, $item_set) = @_;
      my $new_rule = $_->clone_and_reset;
      my @items = map { $_->clone_and_reset } $_->items, @$item_set;
      $new_rule->{items} = \@items;
      $new_rule;
    } @price_rules, @items;
  }

  sub description {
    SL::Locale::String::t8('Price Rule')
  }
}

package SL::PriceRuleMacro::Condition {
  our @ISA      = ('SL::PriceRuleMacro::Element');

  sub type {
    'condition'
  }

  sub description {
    SL::Locale::String::t8('Condition')
  }
}

package SL::PriceRuleMacro::Condition::ContainerAnd {
  require List::Util;
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(condition)
  }

  sub array_elements {
    qw(condition)
  }

  sub type {
    'container_and'
  }

  sub cross (&$$) {
    my ($code, $x, $y) = @_;
    map {
      my $first = $_;
      map {
        $code->(local $a = $first, local $b = $_);
      } @$x
    } @$y;
  }

  sub description {
    SL::Locale::String::t8('Container And (PriceRules)')
  }

  sub price_rule_items {
    return unless my @conditions = grep defined, SL::MoreCommon::listify($_[0]->condition);

    my $reduced = List::Util::reduce {
      [
        cross {
          [ map { $_->clone_and_reset } @$a, @$b ]
        } $a, $b
      ]
    } map {
      [ $_->price_rule_items ]
    } @conditions;
    @$reduced;
  }

  sub order {
    -1
  }
}

package SL::PriceRuleMacro::Condition::ContainerOr {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(condition)
  }

  sub array_elements {
    qw(condition)
  }

  sub type {
    'container_or'
  }

  sub description {
    SL::Locale::String::t8('Container Or (PriceRules)')
  }

  sub price_rule_items {
    map { $_->price_rule_items } @{ $_[0]->condition // [] }
  }

  sub order {
    -1
  }
}

package SL::PriceRuleMacro::IdCondition {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(id)
  }

  sub validate {
    die "condition of type '@{[ $_[0]->type ]}' needs an id" unless $_[0]->id;

    # automatically purge invalid ids
    if ('ARRAY' eq ref $_[0]->id) {
      $_[0]->id([ grep { $_ * 1 > 0 } @{ $_[0]->id } ])
    }
  }

  sub array_elements {
    qw(id)
  }

  sub price_rule_items {
    map { [ SL::DB::PriceRuleItem->new(value_int => $_, type => $_[0]->type) ] } SL::MoreCommon::listify($_[0]->id);
  }
}

package SL::PriceRuleMacro::Condition::Customer {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'customer'
  }

  sub description {
    SL::Locale::String::t8('Customer')
  }

  sub order {
    200
  }
}

package SL::PriceRuleMacro::Condition::Vendor {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'vendor'
  }

  sub description {
    SL::Locale::String::t8('Vendor')
  }

  sub order {
    201
  }
}

package SL::PriceRuleMacro::Condition::Business {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'business'
  }

  sub description {
    SL::Locale::String::t8('Business')
  }

  sub order {
    202
  }
}

package SL::PriceRuleMacro::Condition::Part {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'part'
  }

  sub description {
    SL::Locale::String::t8('Part')
  }

  sub order {
    210
  }
}

package SL::PriceRuleMacro::Condition::Partsgroup {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'partsgroup'
  }

  sub description {
    SL::Locale::String::t8('Partsgroup')
  }

  sub order {
    211
  }
}

package SL::PriceRuleMacro::Condition::Pricegroup {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'pricegroup'
  }

  sub description {
    SL::Locale::String::t8('Pricegroup')
  }

  sub order {
    212
  }
}

package SL::PriceRuleMacro::Condition::Ve {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, 'num', 'numeric');

  sub elements {
    qw(num op)
  }

  sub type {
    've'
  }

  sub description {
    SL::Locale::String::t8('Ve')
  }

  sub validate {
    die "condition of type '@{[ $_[0]->type ]}' needs an op" unless $_[0]->op;
    die "condition of type '@{[ $_[0]->type ]}' needs a num" unless defined $_[0]->num;
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_num => $_[0]->num, op => $_[0]->op, type => $_[0]->type) ];
  }

  sub order {
    213
  }
}

package SL::PriceRuleMacro::Condition::Qty {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, 'num', 'numeric');

  sub elements {
    qw(num op)
  }

  sub type {
    'qty'
  }

  sub description {
    SL::Locale::String::t8('Qty')
  }

  sub validate {
    die "condition of type '@{[ $_[0]->type ]}' needs an op" unless $_[0]->op;
    die "condition of type '@{[ $_[0]->type ]}' needs a num" unless defined $_[0]->num;
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_num => $_[0]->num, op => $_[0]->op, type => $_[0]->type) ];
  }

  sub order {
    220
  }
}

package SL::PriceRuleMacro::Condition::QtyRange {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'numeric') for qw(min max);

  sub elements {
    qw(min max)
  }

  sub type {
    'qty_range'
  }

  sub description {
    SL::Locale::String::t8('Qty Range')
  }

  sub validate {
    die "condition of type '@{[ $_[0]->type ]}' needs at least min or max" if !defined $_[0]->min && !defined $_[0]->max;
  }

  sub price_rule_items {
    [
      SL::DB::PriceRuleItem->new(value_num => $_[0]->min, op => 'ge', type => 'qty'),
      SL::DB::PriceRuleItem->new(value_num => $_[0]->max, op => 'le', type => 'qty'),
    ];
  }

  sub order {
    221
  }
}

package SL::PriceRuleMacro::DateCondition {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, 'date', 'date');


  sub elements {
    qw(date op)
  }

  sub as_tree {
    my ($self) = @_;
    {
      type          => $self->type,
      date_as_epoch => $self->date->epoch,
      op            => $self->op,
    }
  }

  sub validate {
    die "condition of type '@{[ $_[0]->type ]}' needs an op" unless $_[0]->op;
    die "condition of type '@{[ $_[0]->type ]}' needs a date" unless defined $_[0]->date;
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_date => $_[0]->date, op => $_[0]->op, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Condition::Reqdate {
  our @ISA = ('SL::PriceRuleMacro::DateCondition');

  sub type {
    'reqdate'
  }

  sub description {
    SL::Locale::String::t8('Reqdate')
  }

  sub order {
    231
  }
}

package SL::PriceRuleMacro::Condition::Transdate {
  our @ISA = ('SL::PriceRuleMacro::DateCondition');

  sub type {
    'transdate'
  }

  sub description {
    SL::Locale::String::t8('Transdate')
  }

  sub order {
    232
  }
}

package SL::PriceRuleMacro::Action {
  our @ISA = ('SL::PriceRuleMacro::Element');

  sub type {
    'action'
  }

  sub price_rules {
    die 'needs to be implemented';
  }

  sub description {
    SL::Locale::String::t8('Action (PriceRules)')
  }
}


package SL::PriceRuleMacro::Action::ContainerAnd {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(action)
  }

  sub array_elements {
    qw(action)
  }

  sub type {
    'action_container_and'
  }

  sub description {
    SL::Locale::String::t8('Action Container And (PriceRules)')
  }

  sub validate {
    die "action of type '@{[ $_[0]->type ]}' needs at least one action"    unless SL::MoreCommon::listify($_[0]->action);

    $_[0]->SUPER::validate;
  }

  sub price_rules {
    map { $_->price_rules } SL::MoreCommon::listify($_[0]->action)
  }

  sub order {
    -1
  }
}

package SL::PriceRuleMacro::ConditionalAction {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(condition action)
  }

  sub array_elements {
    qw(condition action)
  }

  sub type {
    'conditional_action'
  }

  sub description {
    SL::Locale::String::t8('Conditional Action (PriceRules)')
  }

  sub validate {
    die "action of type '@{[ $_[0]->type ]}' needs at least one condition" unless SL::MoreCommon::listify($_[0]->condition);
    die "action of type '@{[ $_[0]->type ]}' needs at least one action"    unless SL::MoreCommon::listify($_[0]->action);

    $_[0]->SUPER::validate;
  }

  sub price_rules {
    my ($self) = @_;

    # conditions are semantically AND-ed
    my @items = SL::PriceRuleMacro::Condition::ContainerAnd->new(condition => $_[0]->condition)->price_rule_items;

    # actions ar OR-ed
    my @price_rules = map { $_->price_rules } SL::MoreCommon::listify($_[0]->action);

    my @rules = map {
      my $rule = $_;
      my $old_items = $rule->items;
      map {
        my $new_rule = $rule->clone_and_reset;
        my @items = map { $_->clone_and_reset } @$old_items, @$_;
        $new_rule->{items} = \@items;
        $new_rule;
      } @items;
    } @price_rules;

    @rules;
  }

  sub order {
    500
  }
}

package SL::PriceRuleMacro::Action::Simple {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'numeric') for qw(price discount reduction);

  sub elements {
    qw(price_type price discount reduction)
  }

  sub type {
    'simple_action'
  }

  sub description {
    SL::Locale::String::t8('Simple Action (PriceRules)')
  }

  sub validate {
    die "action of type '@{[ $_[0]->type ]}' needs at least price"
      if $_[0]->price_type == SL::DB::Manager::PriceRule::PRICE_NEW() && !defined $_[0]->price;
    die "action of type '@{[ $_[0]->type ]}' needs at least discount"
      if $_[0]->price_type == SL::DB::Manager::PriceRule::PRICE_DISCOUNT() && !defined $_[0]->discount;
    die "action of type '@{[ $_[0]->type ]}' needs at least reduction"
      if $_[0]->price_type == SL::DB::Manager::PriceRule::PRICE_REDUCED_MASTER_DATA() && !defined $_[0]->reduction;
  }

  sub price_rules {
    my ($self) = @_;

    return SL::DB::PriceRule->new(price     => $self->price)     if $self->price_type == SL::DB::Manager::PriceRule::PRICE_NEW();
    return SL::DB::PriceRule->new(discount  => $self->discount)  if $self->price_type == SL::DB::Manager::PriceRule::PRICE_DISCOUNT();
    return SL::DB::PriceRule->new(reduction => $self->reduction) if $self->price_type == SL::DB::Manager::PriceRule::PRICE_REDUCED_MASTER_DATA();
  }

  sub hidden {
    # for legacy only
    1
  }

  sub order {
    104
  }
}

package SL::PriceRuleMacro::Action::Price {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'numeric') for __PACKAGE__->elements;

  sub elements {
    qw(price)
  }

  sub type {
    'price_action'
  }

  sub description {
    SL::Locale::String::t8('Price Action (PriceRules)')
  }

  sub validate {
    die "action of type '@{[ $_[0]->type ]}' needs at least price"
      if !defined $_[0]->price;
  }

  sub price_rules {
    SL::DB::PriceRule->new(price => $_[0]->price);
  }

  sub order {
    100
  }
}

package SL::PriceRuleMacro::Action::Discount {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'numeric') for __PACKAGE__->elements;

  sub elements {
    qw(discount)
  }

  sub type {
    'discount_action'
  }

  sub description {
    SL::Locale::String::t8('Discount Action (PriceRules)')
  }

  sub validate {
    die "action of type '@{[ $_[0]->type ]}' needs at least discount"
      if !defined $_[0]->discount;
  }

  sub price_rules {
    SL::DB::PriceRule->new(discount => $_[0]->discount);
  }

  sub order {
    101
  }
}

package SL::PriceRuleMacro::Action::Reduction {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'numeric') for __PACKAGE__->elements;

  sub elements {
    qw(reduction)
  }

  sub type {
    'reduction_action'
  }

  sub description {
    SL::Locale::String::t8('Reduction Action (PriceRules)')
  }

  sub validate {
    die "action of type '@{[ $_[0]->type ]}' needs at least reduction"
      if !defined $_[0]->reduction;
  }

  sub price_rules {
    SL::DB::PriceRule->new(reduction => $_[0]->reduction);
  }

  sub order {
    102
  }
}

package SL::PriceRuleMacro::Action::PriceScale {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(price_scale_action_line)
  }

  sub array_elements {
    qw(price_scale_action_line)
  }

  sub price_rules {
    my ($self) = @_;

    my @scales = reverse List::UtilsBy::nsort_by { $_->min } SL::MoreCommon::listify($self->price_scale_action_line);

    my $last_max = undef;
    map {
      my @items = grep { defined $_->value_num }
        SL::DB::PriceRuleItem->new(type => 'qty', op => 'ge', value_num => $_->min),
        SL::DB::PriceRuleItem->new(type => 'qty', op => 'lt', value_num => $last_max);

      $last_max = $_->min;

      my @rules;
      push @rules, SL::DB::PriceRule->new(price    => $_->price)    if $_->price;
      push @rules, SL::DB::PriceRule->new(discount => $_->discount) if $_->discount;

      $_->{items} = \@items for @rules;

      @rules
    } @scales;
  }

  sub type {
    'price_scale_action'
  }

  sub description {
    SL::Locale::String::t8('Price Scale Action (PriceRules)')
  }

  sub order {
    -1
  }
}

package SL::PriceRuleMacro::Action::PriceScaleLine {
  our @ISA = ('SL::PriceRuleMacro::Element');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'numeric') for __PACKAGE__->elements;

  sub elements {
    qw(min price discount)
  }

  sub type {
    'price_scale_action_line'
  }

  sub description {
    SL::Locale::String::t8('Price Scale Action Line (PriceRules)')
  }
}

package SL::PriceRuleMacro::Action::PartsPriceList {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub type {
    'parts_price_list_action'
  }

  sub elements {
    qw(parts_price_list_action_line)
  }

  sub array_elements {
    qw(parts_price_list_action_line)
  }

  sub description {
    SL::Locale::String::t8('Parts Price List Action (PriceRules)')
  }

  sub price_rules {
    my ($self) = @_;

    map {
      my $item = SL::DB::PriceRuleItem->new(type => 'part', value_int => $_->id),

      my @rules;
      push @rules, SL::DB::PriceRule->new(price    => $_->price)    if $_->price;
      push @rules, SL::DB::PriceRule->new(discount => $_->discount) if $_->discount;

      $_->{items} = [ $item ] for @rules;

      @rules
    } SL::MoreCommon::listify($self->parts_price_list_action_line);
  }

  sub order {
    -1
  }
}

package SL::PriceRuleMacro::Action::PartsPriceListLine {
  our @ISA = ('SL::PriceRuleMacro::Element');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'numeric') for qw(price discount);

  sub elements {
    qw(id price discount)
  }

  sub type {
    'parts_price_list_action_line'
  }

  sub description {
    SL::Locale::String::t8('Parts Price List Action Line (PriceRules)')
  }
}

package SL::PriceRuleMacro::Action::ListTemplate {
  our @ISA = ('SL::PriceRuleMacro::Action');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  my %descriptions_by_type = (
    ''         => SL::Locale::String::t8('List Template Action (PriceRules)'),
    part       => SL::Locale::String::t8('Parts Price List Action (PriceRules)'),
    customer   => SL::Locale::String::t8('Customer Price List Action (PriceRules)'),
    vendor     => SL::Locale::String::t8('Vendor Price List Action (PriceRules)'),
    business   => SL::Locale::String::t8('Business Price List Action (PriceRules)'),
    partsgroup => SL::Locale::String::t8('Partsgroup Price List Action (PriceRules)'),
    pricegroup => SL::Locale::String::t8('Pricegroup Price List Action (PriceRules)'),
    qty        => SL::Locale::String::t8('Price Scale Action (PriceRules)'),
    ve         => SL::Locale::String::t8('Ve Scale List Action (PriceRules)'),
    transdate  => SL::Locale::String::t8('Transdate Scale Action (PriceRules)'),
    reqdate    => SL::Locale::String::t8('Reqdate Scale Action (PriceRules)'),
  );

  # when creating an empty element, init action flags to price
  sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->action_type([ 'price' ]) unless $self->action_type;
  }

  sub elements {
    qw(condition_type action_type list_template_action_line)
  }

  sub array_elements {
    qw(list_template_action_line action_type)
  }

  sub has_action_type {
    my ($self, $type) = @_;
    scalar grep { $_ eq $type } SL::MoreCommon::listify($self->action_type);
  }

  sub action_type_from_lines {
    my ($self) = @_;
    return unless $self->list_template_action_line;

    my %actions;
    for my $line (SL::MoreCommon::listify($self->list_template_action_line)) {
      defined($line->$_) and $actions{$_} //= 1 for qw(price discount reduction);
    }

    [ grep { $actions{$_} } qw(price discount reduction) ];
  }

  sub validate {
    my ($self) = @_;

    if ($self->condition_type =~ /^( qty | ve | reqdate | transdate )$/x) {
      my $items = $self->list_template_action_line;

      my @items = List::UtilsBy::nsort_by {
        $_->min
      } grep {
        defined $_->min && $_->min ne ''
      } @$items;

      $self->list_template_action_line(\@items);
    } else {
      my $items = $self->list_template_action_line;

      my @items = grep {
        $_->id
      } @$items;

      $self->list_template_action_line(\@items);
    }

    die "action of type '@{[ $_[0]->type ]}' needs a condition_type " unless $_[0]->condition_type;
    die "action of type '@{[ $_[0]->type ]}' needs an action_type " unless SL::MoreCommon::listify($_[0]->action_type);
  }

  sub price_rules {
    my ($self) = @_;

    return unless $self->condition_type;

    if ($self->condition_type =~ /^( part | customer | vendor | business | partsgroup | pricegroup )$/x) {
      return $self->price_rules_id_like;
    }

    if ($self->condition_type =~ /^( qty | ve )$/x) {
      return $self->price_rules_scale_like('value_num');
    }

    if ($self->condition_type =~ /^( reqdate | transdate )$/x) {
      return $self->price_rules_scale_like('value_date');
    }
  }

  sub price_rules_id_like {
    my ($self) = @_;

    map {
      my $item  = SL::DB::PriceRuleItem->new(type => $self->condition_type, value_int => $_->id),
      my @rules = $_->action_rules;

      $_->{items} = [ $item ] for @rules;

      @rules
    } SL::MoreCommon::listify($self->list_template_action_line);
  }

  sub price_rules_scale_like {
    my ($self, $accessor) = @_;

    my @scales = reverse List::UtilsBy::nsort_by { $_->min } SL::MoreCommon::listify($self->list_template_action_line);

    my $last_max = undef;
    map {
      my @items = grep { defined $_->$accessor }
        SL::DB::PriceRuleItem->new(type => $self->condition_type, op => 'ge', $accessor => $_->min),
        SL::DB::PriceRuleItem->new(type => $self->condition_type, op => 'lt', $accessor => $last_max);

      $last_max = $_->min;
      my @rules = $_->action_rules;

      $_->{items} = \@items for @rules;

      @rules
    } @scales;
  }

  sub type {
    'list_template_action'
  }

  sub description {
    return $descriptions_by_type{''} if !ref $_[0]; # foe meta class access
    return $descriptions_by_type{$_[0]->condition_type};
  }

  sub order {
    600
  }
}

package SL::PriceRuleMacro::Action::ListTemplateLine {
  our @ISA = ('SL::PriceRuleMacro::Element');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'numeric') for qw(min price discount reduction);
  SL::DB::Helper::Attr::_make_by_type(__PACKAGE__, $_, 'date')    for qw(min);

  sub action_rules {
    my ($self) = @_;

    my @rules;
    push @rules, SL::DB::PriceRule->new(price     => $self->price)     if $self->price;
    push @rules, SL::DB::PriceRule->new(discount  => $self->discount)  if $self->discount;
    push @rules, SL::DB::PriceRule->new(reduction => $self->reduction) if $self->reduction;

    @rules;
  }

  sub elements {
    qw(min id price discount reduction)
  }

  sub type {
    'list_template_action_line'
  }

  sub description {
    SL::Locale::String::t8('List Template Action Line (PriceRules)')
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::PriceRuleMacro - wrapper for primitive price rules

=head1 SYNOPSIS

  use SL::DB::PriceRuleMacro;

=head1 DESCRIPTION

Primitive price rules have a very strict format for efficiency reasons. They
have exactly one action, and a number of conditions that all must match:

  If qty > 10 and parts_id = 349 then set price to 10.00

In practice these are cumbersome to use, so this additional layer provides the
possibility to construct more complex rules that are then compiled into the
primitive format.

=head1 METHODS

=over 4

=item * C<json_definition>

=item * C<definition>

The first one takes and stores raw json, the second one converts to and from
that to a Perl data structure.

=item * C<parsed_definition>

Parses the definition found in L</json_definition> into a class structure
representing it. The result is cached.

=item * C<update_definition>

Copies the meta attibutes C<name>, C<priority>, C<obsolete>, C<type> from the
macro object into the definition.

=item * C<copy_attributes_to_price_rules PRICE_RULES>

Copies the meta attributes C<name>, C<priority>, C<obsolete>, C<type> from the
macro object into the given price_rules.

=item * C<create_definition_meta>

Returns a structure detailing the accepted elements for the
C<SL::PriceRuleMacro::Definition> elements.

=back

=head1 INTERNAL HELPER CLASSES

The implementation uses a parser based on the helper class
C<SL::PriceRuleMacro::Element>. This abstract class interface provides
the following methods:

=over 4

=item * C<elements>

Returns a list of fields that this element accepts. Can be used for introspection

=item * C<array_elements>

Returns a list of the fields that may be arrays instead of scalars.

=item * C<can_array FIELD>

Returns true if the field may be an array.

=item * C<abstract>

Returns ture if this element can not be filled directly. Abstract classes must
always have have alternatives.

=item * C<as_tree>

Returns a recursive hasref representation of the object tree from this point.
Used for roundtrip.

=item * C<type>

For classes that can be polymorph, C<type> provides the identification for
roundtrip safety.

=back

The actual tree structure will be a C<SL::PriceRuleMacro::Definition>,
which contains two distinct sections: C<condition> and C<action>. Condition
will be a C<SL::PriceRuleMacro::Condition> and action will be a
C<SL::PriceRuleMacro::Action>.

These three implement two additional methods:

=over 4

=item * C<price_rules>

In definition and actions. This returns the compiled L<SL::DB::PriceRule>
objects the tree represents from this point on. Note: The items will be added
in hash slot and need to be readded before saving them.

=item * C<price_rule_items>

In conditions. This returns a list of L<SL::DB::PriceRuleItem> arrays that this
subtree represents. Each array is one conjuction of rules.

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@opendynamic.deE<gt>

=cut

__END__

TODO:

- validate/parse op for qty, reqdate,
- format_version checking
