package SL::Presenter::PriceRule;

use strict;
use utf8;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag link_tag);
use SL::Presenter::CustomerVendor qw();
use SL::Presenter::Business qw();
use SL::Presenter::PartsGroup qw();
use SL::Presenter::Pricegroup qw();

use SL::MoreCommon qw(listify);
use SL::Locale::String qw(t8);

use List::UtilsBy qw(sort_by nsort_by);
use List::Util qw(first uniq);

use Exporter qw(import);
our @EXPORT_OK = qw(price_rule_type_summary);

use Carp;

my %op_to_symbol = (
  lt => '<',
  le => '≤',
  eq => '=',
  ge => '≥',
  gt => '>',
);

my %date_op_to_prefix = (
  lt => t8('before (date)'),
  le => t8('until (date)'),
  eq => t8('on (date)'),
  ge => t8('from (date)'),
  gt => t8('after (date)'),
);

my %op_sort = do { my $i = 0; map { $_ => ++$i } qw(lt le eq ge gt) };
my %inf_ops = map { $_ => 1 } qw(eq ge gt);
my %sup_ops = map { $_ => 1 } qw(lt le eq);
my %incl_ops = map { $_ => 1 } qw(ge eq le);

sub price_rule_type_summary {
  my ($price_rule, $type) = @_;

  my @items = grep { $_->type eq $type } $price_rule->items;

  return '' if !@items;

  for ($type) {
    # qty-like terms
    m/ ^ ( qty | ve ) $ /x && do {
      my @range = @items > 1 ? grep defined, _value_range('value_num', @items) : @items;

      die 'should never happen' if !@range;

      if (@range == 1) {
        return $range[0]->op eq 'eq' ? escape($range[0]->value_num_as_number)
             : escape($op_to_symbol{$range[0]->op} . ' ' . $range[0]->value_num_as_number)
      } elsif (_bad_range('value_num', @range)) {
        return escape(t8('will never match'))
      } else {
        return sprintf "%s%s … %s%s",
        ($incl_ops{$range[0]->op} ? '' : '>'), $range[0]->value_num_as_number,
        ($incl_ops{$range[1]->op} ? '' : '<'), $range[1]->value_num_as_number,
      }
    };

    # qty-like terms
    m/date/x && do {
      my @range = @items > 1 ? grep defined, _value_range('value_date', @items) : @items;

      die 'should never happen' if !@range;

      if (@range == 1) {
        return $range[0]->op eq 'eq' ? escape($range[0]->value_date_as_date)
             : escape($date_op_to_prefix{$range[0]->op} . ' ' . $range[0]->value_date_as_date)
      } elsif (_bad_range('value_date', @range)) {
        return escape(t8('will never match'))
      } else {
        return sprintf "%s %s %s %s %s",
        $date_op_to_prefix{$range[0]->op}, $range[0]->value_date_as_date,
        t8('to (date)'),
        $date_op_to_prefix{$range[1]->op}, $range[1]->value_date_as_date,
      }
    };

    # id-like terms can only have one of them anyway
    if (@items > 1 && 1 < uniq map { $_->value_int } @items) {
      return t8('will never match');
    }
    my $obj = $items[0]->value_object;
    return '' if !$obj;
    return $obj->full_description if $obj->can('full_description');
    return $obj->displayable_name if $obj->can('displayable_name');
    die "don't know how to render onject of type @{ $obj->type }";
  }
}

# takes an arbitrary number of items and computes the effective range
sub _value_range {
  my ($value_slot, @items) = @_;

  my @sorted_items = sort {
    $a->$value_slot  <=> $b->$value_slot ||
    $op_sort{$a->op} <=> $op_sort{$b->op}
  } @items;

  my $sup = first { $sup_ops{$_->op} } @sorted_items;
  my $inf = first { $inf_ops{$_->op} } reverse @sorted_items;

  return ($inf, $sup);
}

sub _bad_range {
  my ($value_slot, $inf, $sup) = @_;
  $inf->$value_slot == $sup->$value_slot
    ? !$incl_ops{$inf->op} && !$incl_ops{$sup->op}
    : $inf->$value_slot > $sup->$value_slot;
}

sub type_summary { goto &price_rule_type_summary }
