#!/usr/bin/perl

BEGIN {
  if (! -d "bin" || ! -d "SL") {
    print("This tool must be run from the Lx-Office ERP base directory.\n");
    exit(1);
  }

  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
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
  my $help_text = <<'END_HELP'
dbupgrade2_tool.pl [options]

  A validation and information tool for the database upgrade scripts
  in 'sql/Pg-upgrade2'.

  At startup dbupgrade2_tool.pl will always check the consistency
  of all database upgrade scripts (e.g. circular references, invalid
  formats, missing meta information). You can but don't have to specifiy
  additional actions.

  Actions:
    --list               Lists all database upgrade tags
    --tree               Lists all database upgrades in tree form
    --rtree              Lists all database upgrades in reverse tree form
    --graphviz[=file]    Create a Postscript document showing a tree of
                         all database upgrades and their dependencies.
                         If no file name is given then the output is
                         written to 'db_dependencies.ps'.
    --nodeps             List all database upgrades that no other upgrade
                         depends on
    --apply=tag          Applies the database upgrades 'tag' and all
                         upgrades it depends on. If '--apply' is used
                         then the option '--user' must be used as well.
    --help               Show this help and exit.

  Options:
    --user=name          The name of the user configuration to use for
                         database connectivity.
END_HELP
    ;

  # Syntax-Highlighting-Fix für Emacs: '

  print $help_text;

  exit 0;
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
  my $file_name = shift || "db_dependencies.ps";

  print("GRAPHVIZ POSTCRIPT\n\n");
  print("Output will be written to '${file_name}'\n");

  calc_rev_depends();

  $dot = "|dot -Tps ";
  open OUT, "${dot}> \"${file_name}\"" || die;

  print(OUT
        "digraph db_dependencies {\n" .
        "node [shape=box style=filled fillcolor=white];\n");
  my %ranks;
  foreach my $c (values(%{$controls})) {
    $ranks{$c->{"depth"}} ||= [];

    my ($pre, $post) = ('node [fillcolor=lightgray] ', 'node [fillcolor=white] ') if !@{ $c->{"rev_depends"} };

    push @{ $ranks{$c->{"depth"}} }, qq|${pre}"$c->{tag}"; ${post}|;
  }
  foreach (sort(keys(%ranks))) {
    print OUT "{ rank = same; ", join("", @{ $ranks{$_} }), " }\n";
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
           "graphviz:s" => \$opt_graphviz,
           "user=s" => \$opt_user,
           "apply=s" => \$opt_apply,
           "help" => \$opt_help,
  );

if ($opt_help) {
  show_help();
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

if (defined $opt_graphviz) {
  dump_graphviz($opt_graphviz);
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
