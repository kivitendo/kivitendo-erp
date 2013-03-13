use Test::More;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use Data::Dumper;
use Support::TestSetup;

eval {
  require 'SL::DB::RequirementSpec';
  require 'SL::DB::RequirementSpecItem';
  require 'SL::DB::RequirementSpecTextBlock';
  1;
} or my $skip = 'RequirementSpec is not available for this test';

if ($skip) {
  plan skip_all => $skip;
} else {
  plan tests => 48;
}

sub reset_state {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(RequirementSpecTextBlock RequirementSpecItem RequirementSpec);

  SL::DB::RequirementSpec->new(id => 2, type_id => 1, status_id => 1, customer_id => 12395, hourly_rate => 42.24,  title => "Azumbo")->save;

  SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, parent_id => undef, id => 1, position => 1, fb_number => "A01",    title => "Mühköh",   description => "The Kuh.")->save;
  SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, parent_id => undef, id => 2, position => 2, fb_number => "A02",    title => "Geheim",   description => "Kofferkombination")->save;
  SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, parent_id => 1,     id => 3, position => 1, fb_number => "FB0001", title => "Yäääh",    description => "Und so")->save;
  SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, parent_id => 1,     id => 4, position => 2, fb_number => "FB0012", title => "Blubb",    description => "blabb")->save;
  SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, parent_id => 1,     id => 5, position => 3, fb_number => "FB0022", title => "Fingo",    description => "fungo")->save;
  SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, parent_id => 4,     id => 6, position => 1, fb_number => "UFB002", title => "Suppi",    description => "Suppa")->save;
  SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, parent_id => 4,     id => 7, position => 2, fb_number => "UFB000", title => "Suppa",    description => "Suppi")->save;
  SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, parent_id => 2,     id => 8, position => 1, fb_number => "FB0018", title => "Neuneins", description => "Eins")->save;

  SL::DB::RequirementSpec->new->db->dbh->do(qq|SELECT pg_catalog.setval('| . $_->[0] . qq|', | . $_->[1] . qq|, true)|) for (['requirement_spec_items_id_seq', 8], [ 'requirement_specs_id_seq', 2 ]);
}

sub values_eq {
  my ($val1, $val2) = @_;
  return (defined($val1) == defined($val2))
      && (!defined($val1) || ($val1 == $val2));
}

sub test_positions {
  my ($message, @positions) = @_;

  my $failures =
    join ' ',
    map  { join ':', map { $_ // 'undef' } @{ $_ } }
    grep { !values_eq($_->[1], $_->[3]) || !values_eq($_->[2], $_->[4]) }
    map  { my $item = SL::DB::RequirementSpecItem->new(id => $_->[0])->load; [ @{ $_ }, $item->parent_id, $item->position ] }
    @positions;

  is($failures, '', $message);
}

sub new_item {
  return SL::DB::RequirementSpecItem->new(requirement_spec_id => 2, fb_number => 'dummy', title => 'dummy', @_);
}

sub get_item {
  return SL::DB::RequirementSpecItem->new(id => $_[0])->load;
}

Support::TestSetup::login();
my $item;

# 1
# `+- 3
#  +- 4
#  |  `+- 6
#  |   `- 7
#  `- 5
# 2
# `- 8

reset_state();
test_positions "reset_state", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

# Einfügen neuer Objekte: "set_position"
new_item(parent_id => 1)->save;
test_positions "set_position via new with parent_id NOT NULL", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ], [ 9, 1, 4 ];

reset_state();
new_item()->save;
test_positions "set_position via new with parent_id IS NULL",  [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ], [ 9, undef, 3 ];

# Löschen von Objekten: "remove_position"
reset_state();
get_item(3)->delete;
test_positions "remove_position via delete with parent_id NOT NULL",  [ 1, undef, 1 ], [ 2, undef, 2 ], [ 4, 1, 1 ], [ 5, 1, 2 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(1)->delete;
test_positions "remove_position via delete with parent_id IS NULL 1",  [ 2, undef, 1 ], [ 8, 2, 1 ];

reset_state();
get_item(2)->delete;
test_positions "remove_position via delete with parent_id IS NULL 2",  [ 1, undef, 1 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ];

# Hoch schieben
reset_state();
get_item(3)->move_position_up;
test_positions "move_position_up when at top of sub-list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(4)->move_position_up;
test_positions "move_position_up when in middle of sub-list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 4, 1, 1 ], [ 3, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(5)->move_position_up;
test_positions "move_position_up when at end of sub-list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 5, 1, 2 ], [ 4, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(8)->move_position_up;
test_positions "move_position_up when only element in sub-list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

# Herunter schieben
reset_state();
get_item(3)->move_position_down;
test_positions "move_position_down when at top of sub-list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 4, 1, 1 ], [ 3, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(4)->move_position_down;
test_positions "move_position_down when in middle of sub-list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 5, 1, 2 ], [ 4, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(5)->move_position_down;
test_positions "move_position_down when at bottom of sub-list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(8)->move_position_down;
test_positions "move_position_down when only element in sub-list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

# Listen neu anordnen
reset_state();
get_item(8)->reorder_list(4, 5, 3);
test_positions "reoder_list called as instance method", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 4, 1, 1 ], [ 5, 1, 2 ], [ 3, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
SL::DB::RequirementSpecItem->reorder_list(4, 5, 3);
test_positions "reoder_list called as class method", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 4, 1, 1 ], [ 5, 1, 2 ], [ 3, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

# Aus Liste entfernen
reset_state();
get_item(3)->remove_from_list;
test_positions "remove_from_list on top", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, -1 ], [ 4, 1, 1 ], [ 5, 1, 2 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(4)->remove_from_list;
test_positions "remove_from_list on middle", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, -1 ], [ 5, 1, 2 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(5)->remove_from_list;
test_positions "remove_from_list on bottom", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, -1 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
get_item(8)->remove_from_list;
test_positions "remove_from_list on only item in list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, -1 ];

reset_state();
$item = get_item(3); $item->remove_from_list; $item->delete;
test_positions "remove_from_list and delete afterwards", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 4, 1, 1 ], [ 5, 1, 2 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

# Zu Liste hinzufügen
reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'last');
test_positions "add_to_list position 'last'", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 4 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'first');
test_positions "add_to_list position 'first'", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 2 ], [ 4, 1, 3 ], [ 5, 1, 4 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 1 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'before', reference => 3);
test_positions "add_to_list position 'before' first by ID", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 2 ], [ 4, 1, 3 ], [ 5, 1, 4 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 1 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'before', reference => get_item(3));
test_positions "add_to_list position 'before' first by reference", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 2 ], [ 4, 1, 3 ], [ 5, 1, 4 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 1 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'before', reference => 4);
test_positions "add_to_list position 'before' middle by ID", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 3 ], [ 5, 1, 4 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 2 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'before', reference => get_item(4));
test_positions "add_to_list position 'before' middle by reference", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 3 ], [ 5, 1, 4 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 2 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'after', reference => 5);
test_positions "add_to_list position 'after' last by ID", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 4 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'after', reference => get_item(5));
test_positions "add_to_list position 'after' last by reference", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 4 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'after', reference => 4);
test_positions "add_to_list position 'after' middle by ID", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 4 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 3 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(1); $item->add_to_list(position => 'after', reference => get_item(4));
test_positions "add_to_list position 'after' middle by reference", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 4 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 1, 3 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(3); $item->add_to_list(position => 'last');
test_positions "add_to_list position 'last' in empty", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 3, 1 ];

reset_state();
$item = get_item(8); $item->remove_from_list; $item->parent_id(3); $item->add_to_list(position => 'first');
test_positions "add_to_list position 'first' in empty", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 4, 1, 2 ], [ 5, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 3, 1 ];

reset_state();
$item = get_item(5); $item->add_to_list(position => 'after', reference => 3);
test_positions "add_to_list without prior remove_from_list", [ 1, undef, 1 ], [ 2, undef, 2 ], [ 3, 1, 1 ], [ 5, 1, 2 ], [ 4, 1, 3 ], [ 6, 4, 1 ], [ 7, 4, 2 ], [ 8, 2, 1 ];

reset_state();
$item = get_item(4);
is($item->get_next_in_list->id,                           5, 'Next of 4 is 5');
is($item->get_previous_in_list->id,                       3, 'Previous of 4 is 5');
is($item->get_next_in_list->get_previous_in_list->id,     4, 'Previous of Next of 4 is 4');
is($item->get_previous_in_list->get_next_in_list->id,     4, 'Next of Previous of 4 is 4');
is($item->get_next_in_list->get_next_in_list,         undef, 'Next of Next of 4 is undef');
is($item->get_previous_in_list->get_previous_in_list, undef, 'Previous of Previous of 4 is undef');

# Parametervalidierung
throws_ok { new_item()->move_position_up   } qr/not.*been.*saved/i, 'move up not saved yet';
throws_ok { new_item()->move_position_down } qr/not.*been.*saved/i, 'move down not saved yet';

throws_ok { $item = get_item(8); $item->position(undef); $item->move_position_up   } qr/no.*position.*set.*yet/i, 'move up no position set';
throws_ok { $item = get_item(8); $item->position(undef); $item->move_position_down } qr/no.*position.*set.*yet/i, 'move down no position set';

throws_ok { get_item(8)->add_to_list;                      } qr/invalid.*parameter.*position/i,  'missing position';
throws_ok { get_item(8)->add_to_list(position => 'gonzo')  } qr/invalid.*parameter.*position/i,  'invalid position';
throws_ok { get_item(8)->add_to_list(position => 'before') } qr/missing.*parameter.*reference/i, 'missing reference for position "before"';
throws_ok { get_item(8)->add_to_list(position => 'after')  } qr/missing.*parameter.*reference/i, 'missing reference for position "after"';

done_testing();
