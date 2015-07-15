#!/usr/bin/perl

use strict;
use SL::Dispatcher;
use SL::Inifile;
use SL::LXDebug;
use Data::Dumper;
use JSON;
use YAML;
use Cwd;

$::lxdebug = LXDebug->new;

my %menu_files = (
  'menus/erp.ini'   => 'menus/user/00-erp.yaml',
  'menus/crm.ini'   => 'menus/user/10-crm.yaml',
  'menus/admin.ini' => 'menus/admin/00-admin.yaml',
);

my %known_arguments = (
  ICON    => 'icon',
  ACCESS  => 'access',
  INSTANCE_CONF => 'INSTANCE_CONF',
  module  => 'module',
  submenu => 'submenu',
  target  => 'target',
  href    => 'href',
);

sub translate_to_yaml {
  my ($menu_file, $new_file) = @_;

  my %counter;

  my $menu       = Inifile->new($menu_file);
  my @menu_items = map { +{ %{ $menu->{$_} }, ID => $_ } } @{ delete $menu->{ORDER} };

  for my $item (@menu_items) {
    # parse id
    my @tokens = split /--/, delete $item->{ID};
    my $name   = pop @tokens;
    my $parent = join '_', map { lc $_ } @tokens;
    my $id     = join '_', grep $_, $parent, lc $name;

    # move unknown arguments to param subhash
    my @keys = keys %$item;
    my %params;
    for (@keys) {
      next if $known_arguments{$_};
      $params{$_} = delete $item->{$_};
    }

    $item->{params} = \%params if keys %params;

    # sanitize keys
    for (keys %known_arguments) {
      next unless exists $item->{$_};
      my $val = delete $item->{$_};
      $item->{ $known_arguments{$_} } = $val;
    }

    # sanitize submenu
    if ($item->{submenu}) {
      delete $item->{submenu};
    }

    # sanitize INSTANCE_CONF
    if ($item->{INSTANCE_CONF}) {
      my $instance_conf = delete $item->{INSTANCE_CONF};
      if ($item->{access}) {
        if ($item->{access} =~ /\W/) {
          $item->{access} = "client/$instance_conf & ( $item->{access} )";
        } else {
          $item->{access} = "client/$instance_conf & $item->{access}";
        }
      } else {
        $item->{access} = "client/$instance_conf";
      }
    }

    # make controller.pl implicit
    if ($item->{module} && $item->{module} eq 'controller.pl') {
      delete $item->{module};
    }

    # add id
    $item->{id} = $id;
    $item->{id} =~ s/[^\w]+/_/g;

    # add to name
    $item->{name} = $name;

    # add parent
    if ($parent) {
      $item->{parent} = $parent;
      $item->{parent} =~ s/[^\w]+/_/g if $item->{parent};
    }

    # add order
    $item->{order} = 100 * ++$counter{ $item->{parent} };
  }

  if ($menu_file =~ /crm/) {
    $menu_items[0]{order} = 50; # crm first
  }

  open my $out_file, '>:utf8', $new_file or die $!;
  print $out_file yaml_dump(\@menu_items);
}

sub yaml_dump {
  my ($ary_ref) = @_;
  # YAML dumps keys lexically sorted, which isn't what we want.
  # we want this order:
  my @order = qw(
    parent
    id
    name
    icon
    order
    access
    href
    module
    target
    params
  );

  # ...oh and we want action in params first
  #
  # why this? because:
  # 1. parent is what is used to anchor. one could argue that id should be
  #    first, but parent is easier for understanding structure.
  # 2. after parent the logical structure is
  #    1. id
  #    2. stuff related to vidual presentation (name/icon)
  #    3. stuff needed for logical presentaion (order/access)
  #    4. stuff related to the action after clicking it
  # 3. without parent and href (the second is pretty rare) the keys are nicely
  #    ascending in length, which is very easy to parse visually.

  my $yaml = "---\n";
  for my $node (@$ary_ref) {
    my $first = 0;
    for my $key (@order) {
      next unless exists $node->{$key};
      $yaml .= ($first++ ? '  ' : '- ') . $key . ": ";
      if (!ref $node->{$key}) {
        $yaml .= $node->{$key} . "\n";
      } else {
        $yaml .= "\n";
        for ('action', grep !/^action$/, keys %{ $node->{$key} }) {
          next unless exists $node->{$key}{$_};
          $yaml .= "    $_: $node->{$key}{$_}\n";
        }
      }

    }
  }

  $yaml;
}

while (my ($in, $out) = each(%menu_files)) {
  translate_to_yaml($in, $out);
}

