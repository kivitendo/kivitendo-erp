#!/usr/bin/perl

BEGIN {
  if (! -d "bin" || ! -d "SL") {
    print("This tool must be run from the Lx-Office ERP base directory.\n");
    exit(1);
  }

  push(@INC, "modules");
}

use English '-no_match_vars';

use DBI;
use Data::Dumper;
use Getopt::Long;

use SL::LXDebug;

$lxdebug = LXDebug->new();

use SL::Form;
use SL::User;
use SL::Locale;
use SL::DBUpgrade2;
use SL::DBUtils;

#######
#######
#######

my ($opt_list, $opt_tree, $opt_rtree, $opt_nodeps, $opt_graphviz, $opt_help);
my ($opt_user, $opt_apply);

our (%myconfig, $form, $user);

sub show_help {
  print("dbupgrade2_tool.pl [--list] [--tree] [--rtree] [--graphviz]\n" .
        "                   [--nodepds] [--user=name --apply=tag] [--help]\n");
}

sub error {
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

sub apply_upgrade {
  my $name = shift;

  my (@order, %tags, @all_tags);

  if ($name eq "ALL") {
    calc_rev_depends();
    @all_tags = map { $_->{"tag"} } grep { !@{$_->{"rev_depends"}} } values %{$controls};

  } else {
    $form->error("Unknown dbupgrade tag '$name'") if (!$controls->{$name});
    @all_tags = ($name);
  }

  foreach my $tag (@all_tags) {
    build_upgrade_order($tag, \@order, \%tags);
  }

  my @upgradescripts = map { $controls->{$_}->{"applied"} = 0; $controls->{$_} } @order;

  my $dbh = $form->dbconnect_noauto(\%myconfig);

  $dbh->{PrintWarn}  = 0;
  $dbh->{PrintError} = 0;

  $user->create_schema_info_table($form, $dbh);

  my $query = qq|SELECT tag FROM schema_info|;
  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  while (($tag) = $sth->fetchrow_array()) {
    $controls->{$tag}->{"applied"} = 1 if defined $controls->{$tag};
  }
  $sth->finish();

  @upgradescripts = sort { $a->{"priority"} <=> $b->{"priority"} } grep { !$_->{"applied"} } @upgradescripts;
  if (!@upgradescripts) {
    print "The upgrade has already been applied.\n";
    exit 0;
  }

  foreach my $control (@upgradescripts) {
    $control->{"file"} =~ /\.(sql|pl)$/;
    my $file_type = $1;

    # apply upgrade
    print "Applying upgrade $control->{file}\n";

    if ($file_type eq "sql") {
      $user->process_query($form, $dbh, "sql/$form->{dbdriver}-upgrade2/$control->{file}", $control);
    } else {
      $user->process_perl_script($form, $dbh, "sql/$form->{dbdriver}-upgrade2/$control->{file}", $control);
    }
  }

  $dbh->disconnect();
}

sub build_upgrade_order {
  my $name  = shift;
  my $order = shift;
  my $tag   = shift;

  my $control = $controls->{$name};

  foreach my $dependency (@{ $control->{"depends"} }) {
    next if $tags->{$dependency};
    $tags->{$dependency} = 1;
    build_upgrade_order($dependency, $order, $tag);
  }

  push @{ $order }, $name;
  $tags->{$name} = 1;
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

GetOptions("list" => \$opt_list,
           "tree" => \$opt_tree,
           "rtree" => \$opt_rtree,
           "nodeps" => \$opt_nodeps,
           "graphviz" => \$opt_graphviz,
           "user=s" => \$opt_user,
           "apply=s" => \$opt_apply,
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

if ($opt_user) {
  my $file_name = "users/${opt_user}.conf";

  eval { require($file_name); };
  $form->error("File '$file_name' was not found") if $@;
  $locale = new Locale($myconfig{countrycode}, "all");
  $user = new User("users/members", $opt_user);
  map { $form->{$_} = $myconfig{$_} } keys %myconfig;
}

if ($opt_apply) {
  $form->error("--apply used but no configuration file given with --user.") if (!$user);
  apply_upgrade($opt_apply);
}
