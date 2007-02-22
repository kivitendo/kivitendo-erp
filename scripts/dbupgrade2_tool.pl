#!/usr/bin/perl

BEGIN {
  if (! -d "bin" || ! -d "SL") {
    print("This tool must be run from the Lx-Office ERP base directory.\n");
    exit(1);
  }

  push(@INC, "modules");
}

use DBI;
use Data::Dumper;
use Getopt::Long;

use SL::LXDebug;

$lxdebug = LXDebug->new();

use SL::Form;
use SL::Locale;
use SL::DBUpgrade2;

#######
#######
#######

sub show_help {
  print("dbupgrade2_tool.pl [--list] [--tree] [--rtree] [--graphviz]\n" .
        "                   [--nodepds] [--help]\n");
}

sub calc_rev_depends {
  map({ $_->{"rev_depends"} = []; } values(%{$controls}));
  foreach my $control (values(%{$controls})) {
    map({ push(@{$controls->{$_}{"rev_depends"}}, $control->{"tag"}) }
        @{$control->{"depends"}});
  }
}

sub dump_list {
  my @sorted_controls = sort_dbupdate_controls($controls);

  print("LIST VIEW\n\n");
  print("number tag depth priority\n");
  $i = 0;
  foreach (@sorted_controls) {
    print("$i $_->{tag} $_->{depth} $_->{priority}\n");
    $i++;
  }

  print("\n");
}

sub dump_node {
  my ($tag, $depth) = @_;

  print(" " x $depth . $tag . "\n");

  my $c = $controls->{$tag};
  my $num = scalar(@{$c->{"depends"}});
  for (my $i = 0; $i < $num; $i++) {
    dump_node($c->{"depends"}[$i], $depth + 1);
  }
}

sub dump_tree {
  print("TREE VIEW\n\n");

  calc_rev_depends();

  my @sorted_controls = sort_dbupdate_controls($controls);

  foreach my $control (@sorted_controls) {
    dump_node($control->{"tag"}, "") unless (@{$control->{"rev_depends"}});
  }

  print("\n");
}

sub dump_node_reverse {
  my ($tag, $depth) = @_;

  print(" " x $depth . $tag . "\n");

  my $c = $controls->{$tag};
  my $num = scalar(@{$c->{"rev_depends"}});
  for (my $i = 0; $i < $num; $i++) {
    dump_node_reverse($c->{"rev_depends"}[$i], $depth + 1);
  }
}

sub dump_tree_reverse {
  print("REVERSE TREE VIEW\n\n");

  calc_rev_depends();

  my @sorted_controls = sort_dbupdate_controls($controls);

  foreach my $control (@sorted_controls) {
    last if ($control->{"depth"} > 1);
    dump_node_reverse($control->{"tag"}, "");
  }

  print("\n");
}

sub dump_graphviz {
  print("GRAPHVIZ POSTCRIPT\n\n");
  print("Output will be written to db_dependencies.ps\n");
  $dot = "|dot -Tps ";
  open(OUT, "${dot}> db_dependencies.ps");
  print(OUT
        "digraph db_dependencies {\n" .
        "node [shape=box];\n");
  my %ranks;
  foreach my $c (values(%{$controls})) {
    $ranks{$c->{"depth"}} = [] unless ($ranks{$c->{"depth"}});
    push(@{$ranks{$c->{"depth"}}}, $c->{"tag"});
  }
  foreach (sort(keys(%ranks))) {
    print(OUT "{ rank = same; " .
          join("", map({ '"' . $_ . '"; ' } @{$ranks{$_}})) .
          " }\n");
  }
  foreach my $c (values(%{$controls})) {
    print(OUT "$c->{tag};\n");
    foreach my $d (@{$c->{"depends"}}) {
      print(OUT "$c->{tag} -> $d;\n");
    }
  }
  print(OUT "}\n");
  close(OUT);
}

sub dump_nodeps {
  calc_rev_depends();

  print("SCRIPTS NO OTHER SCRIPTS DEPEND ON\n\n" .
        join("\n",
             map({ $_->{"tag"} }
                 grep({ !@{$_->{"rev_depends"}} }
                      values(%{$controls})))) .
        "\n\n");
}

#######
#######
#######

eval { require "lx-erp.conf"; };

$form = Form->new();
$locale = Locale->new("de", "login");

#######
#######
#######

my ($opt_list, $opt_tree, $opt_rtree, $opt_nodeps, $opt_graphviz, $opt_help);

GetOptions("list" => \$opt_list,
           "tree" => \$opt_tree,
           "rtree" => \$opt_rtree,
           "nodeps" => \$opt_nodeps,
           "graphviz" => \$opt_graphviz,
           "help" => \$opt_help,
  );

if ($opt_help) {
  show_help();
  exit(0);
}

$controls = parse_dbupdate_controls($form, "Pg");

if ($opt_list) {
  dump_list();
}

if ($opt_tree) {
  dump_tree();
}

if ($opt_rtree) {
  dump_tree_reverse();
}

if ($opt_graphviz) {
  dump_graphviz();
}

if ($opt_nodeps) {
  dump_nodeps();
}
