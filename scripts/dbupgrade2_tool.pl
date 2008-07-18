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
use Text::Iconv;

use SL::LXDebug;

$lxdebug = LXDebug->new();

use SL::Auth;
use SL::Form;
use SL::User;
use SL::Locale;
use SL::DBUpgrade2;
use SL::DBUtils;

#######
#######
#######

my ($opt_list, $opt_tree, $opt_rtree, $opt_nodeps, $opt_graphviz, $opt_help);
my ($opt_user, $opt_apply, $opt_applied, $opt_format, $opt_test_utf8);
my ($opt_dbhost, $opt_dbport, $opt_dbname, $opt_dbuser, $opt_dbpassword);

our (%myconfig, $form, $user, $auth);

sub show_help {
  my $help_text = <<"END_HELP"
dbupgrade2_tool.pl [options]

  A validation and information tool for the database upgrade scripts
  in \'sql/Pg-upgrade2\'.

  At startup dbupgrade2_tool.pl will always check the consistency
  of all database upgrade scripts (e.g. circular references, invalid
  formats, missing meta information). You can but don\'t have to specifiy
  additional actions.

  Actions:
    --list               Lists all database upgrade tags
    --tree               Lists all database upgrades in tree form
    --rtree              Lists all database upgrades in reverse tree form
    --graphviz[=file]    Create a Postscript document showing a tree of
                         all database upgrades and their dependencies.
                         If no file name is given then the output is
                         written to \'db_dependencies.png\'.
    --format=...         Format for the graphviz output. Defaults to
                         \'png\'. All values that the command \'dot\' accepts
                         for it\'s option \'-T\' are acceptable.
    --nodeps             List all database upgrades that no other upgrade
                         depends on
    --apply=tag          Applies the database upgrades \'tag\' and all
                         upgrades it depends on. If \'--apply\' is used
                         then the option \'--user\' must be used as well.
    --applied            List the applied database upgrades for the
                         database that the user given with \'--user\' uses.
    --test-utf8          Tests a PostgreSQL cluster for proper UTF-8 support.
                         You have to specify the database to test with the
                         parameters --dbname, --dbhost, --dbport, --dbuser
                         and --dbpassword.
    --help               Show this help and exit.

  Options:
    --user=name          The name of the user configuration to use for
                         database connectivity.
    --dbname=name        Database connection options for the UTF-8
    --dbhost=host        handling test.
    --dbport=port
    --dbuser=user
    --dbpassword=pw

END_HELP
;

  print $help_text;

  exit 0;
}

sub error {
}

sub calc_rev_depends {
  map { $_->{rev_depends} = []; } values %{ $controls };

  foreach my $control (values %{ $controls }) {
    map { push @{ $controls->{$_}->{rev_depends} }, $control->{tag} } @{ $control->{depends} };
  }
}

sub dump_list {
  my @sorted_controls = sort_dbupdate_controls($controls);

  print "LIST VIEW\n\n" .
    "number tag depth priority\n";

  $i = 0;
  foreach (@sorted_controls) {
    print "$i $_->{tag} $_->{depth} $_->{priority}\n";
    $i++;
  }

  print "\n";
}

sub dump_node {
  my ($tag, $depth) = @_;

  print " " x $depth . $tag . "\n";

  foreach my $dep_tag (@{ $controls->{$tag}->{depends} }) {
    dump_node($dep_tag, $depth + 1);
  }
}

sub dump_tree {
  print "TREE VIEW\n\n";

  calc_rev_depends();

  my @sorted_controls = sort_dbupdate_controls($controls);

  foreach my $control (@sorted_controls) {
    dump_node($control->{tag}, "") unless (@{ $control->{rev_depends} });
  }

  print "\n";
}

sub dump_node_reverse {
  my ($tag, $depth) = @_;

  print " " x $depth . $tag . "\n";

  foreach my $dep_tag (@{ $controls->{$tag}->{rev_depends} }) {
    dump_node_reverse($dep_tag, $depth + 1);
  }
}

sub dump_tree_reverse {
  print "REVERSE TREE VIEW\n\n";

  calc_rev_depends();

  my @sorted_controls = sort_dbupdate_controls($controls);

  foreach my $control (@sorted_controls) {
    last if ($control->{depth} > 1);
    dump_node_reverse($control->{tag}, "");
  }

  print "\n";
}

sub dump_graphviz {
  my %params    = @_;

  my $format    = $params{format}    || "png";
  my $file_name = $params{file_name} || "db_dependencies.${format}";

  print "GRAPHVIZ OUTPUT -- format: ${format}\n\n";
  print "Output will be written to '${file_name}'\n";

  calc_rev_depends();

  $dot = "|dot -T${format} ";
  open OUT, "${dot}> \"${file_name}\"" || die;

  print OUT
    "digraph db_dependencies {\n" .
    "graph [size=\"16.53,11.69!\"];\n" .
    "node [shape=box style=filled fillcolor=white];\n";

  my %ranks;
  foreach my $c (values %{ $controls }) {
    $ranks{$c->{depth}} ||= [];

    my ($pre, $post) = ('node [fillcolor=lightgray] ', 'node [fillcolor=white] ') if (!scalar @{ $c->{rev_depends} });

    push @{ $ranks{$c->{"depth"}} }, qq|${pre}"$c->{tag}"; ${post}|;
  }

  foreach (sort keys %ranks) {
    print OUT "{ rank = same; ", join("", @{ $ranks{$_} }), " }\n";
  }

  foreach my $c (values %{ $controls }) {
    print OUT "$c->{tag};\n";

    foreach my $d (@{ $c->{depends} }) {
      print OUT "$c->{tag} -> $d;\n";
    }
  }

  print OUT "}\n";
  close OUT;
}

sub dump_nodeps {
  calc_rev_depends();

  print "SCRIPTS NO OTHER SCRIPTS DEPEND ON\n\n" .
    join("\n", map { $_->{tag} } grep { !scalar @{ $_->{rev_depends} } } values %{ $controls }) .
    "\n\n";
}

sub apply_upgrade {
  my $name = shift;

  my (@order, %tags, @all_tags);

  if ($name eq "ALL") {
    calc_rev_depends();
    @all_tags = map { $_->{tag} } grep { !@{$_->{rev_depends}} } values %{ $controls };

  } else {
    $form->error("Unknown dbupgrade tag '$name'") if (!$controls->{$name});
    @all_tags = ($name);
  }

  foreach my $tag (@all_tags) {
    build_upgrade_order($tag, \@order, \%tags);
  }

  my @upgradescripts = map { $controls->{$_}->{applied} = 0; $controls->{$_} } @order;

  my $dbh = $form->dbconnect_noauto(\%myconfig);

  $dbh->{PrintWarn}  = 0;
  $dbh->{PrintError} = 0;

  $user->create_schema_info_table($form, $dbh);

  my $query = qq|SELECT tag FROM schema_info|;
  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  while (($tag) = $sth->fetchrow_array()) {
    $controls->{$tag}->{applied} = 1 if defined $controls->{$tag};
  }
  $sth->finish();

  @upgradescripts = sort { $a->{priority} <=> $b->{priority} } grep { !$_->{applied} } @upgradescripts;
  if (!@upgradescripts) {
    print "The upgrade has already been applied.\n";
    exit 0;
  }

  foreach my $control (@upgradescripts) {
    $control->{file} =~ /\.(sql|pl)$/;
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

sub dump_sql_result {
  my ($results, $column_order) = @_;

  my %column_lengths = map { $_, length $_ } keys %{ $results->[0] };

  foreach my $row (@{ $results }) {
    map { $column_lengths{$_} = length $row->{$_} if (length $row->{$_} > $column_lengths{$_}) } keys %{ $row };
  }

  my @sorted_names;
  if ($column_order && scalar @{ $column_order }) {
    @sorted_names = @{ $column_order };
  } else {
    @sorted_names = sort keys %column_lengths;
  }

  my $format       = join('|', map { '%-' . $column_lengths{$_} . 's' } @sorted_names) . "\n";

  printf $format, @sorted_names;
  print  join('+', map { '-' x $column_lengths{$_} } @sorted_names) . "\n";

  foreach my $row (@{ $results }) {
    printf $format, map { $row->{$_} } @sorted_names;
  }
  printf "(\%d row\%s)\n", scalar @{ $results }, scalar @{ $results } > 1 ? 's' : '';
}

sub dump_applied {
  my @results;

  my $dbh = $form->dbconnect_noauto(\%myconfig);

  $dbh->{PrintWarn}  = 0;
  $dbh->{PrintError} = 0;

  $user->create_schema_info_table($form, $dbh);

  my $query = qq|SELECT tag, login, itime FROM schema_info ORDER BY itime|;
  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  while (my $ref = $sth->fetchrow_hashref()) {
    push @results, $ref;
  }
  $sth->finish();

  $dbh->disconnect();

  if (!scalar @results) {
    print "No database upgrades have been applied yet.\n";
  } else {
    dump_sql_result(\@results, [qw(tag login itime)]);
  }
}

sub build_upgrade_order {
  my $name  = shift;
  my $order = shift;
  my $tag   = shift;

  my $control = $controls->{$name};

  foreach my $dependency (@{ $control->{depends} }) {
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

eval { require "config/lx-erp.conf"; };
eval { require "config/lx-erp-local.conf"; } if (-f "config/lx-erp-local.conf");

$form = Form->new();
$locale = Locale->new("de", "login");

#######
#######
#######

GetOptions("list"         => \$opt_list,
           "tree"         => \$opt_tree,
           "rtree"        => \$opt_rtree,
           "nodeps"       => \$opt_nodeps,
           "graphviz:s"   => \$opt_graphviz,
           "format:s"     => \$opt_format,
           "user=s"       => \$opt_user,
           "apply=s"      => \$opt_apply,
           "applied"      => \$opt_applied,
           "test-utf8"    => \$opt_test_utf8,
           "dbhost:s"     => \$opt_dbhost,
           "dbport:s"     => \$opt_dbport,
           "dbname:s"     => \$opt_dbname,
           "dbuser:s"     => \$opt_dbuser,
           "dbpassword:s" => \$opt_dbpassword,
           "help"         => \$opt_help,
  );

show_help() if ($opt_help);

$controls = parse_dbupdate_controls($form, "Pg");

dump_list()                                 if ($opt_list);
dump_tree()                                 if ($opt_tree);
dump_tree_reverse()                         if ($opt_rtree);
dump_graphviz('file_name' => $opt_graphviz,
              'format'    => $opt_format)   if (defined $opt_graphviz);
dump_nodeps()                               if ($opt_nodeps);

if ($opt_user) {
  $auth = SL::Auth->new();
  if (!$auth->session_tables_present()) {
    $form->error("The session and user management tables are not present in the " .
                 "authentication database. Please use the administration web interface " .
                 "and to create them.");
  }

  %myconfig = $auth->read_user($opt_user);

  if (!$myconfig{login}) {
    $form->error($form->format_string("The user '#1' does not exist.", $opt_user));
  }

  $locale = new Locale($myconfig{countrycode}, "all");
  $user   = new User($opt_user);

  map { $form->{$_} = $myconfig{$_} } keys %myconfig;
}

if ($opt_apply) {
  $form->error("--apply used but no user name given with --user.") if (!$user);
  apply_upgrade($opt_apply);
}

if ($opt_applied) {
  $form->error("--applied used but no user name given with --user.") if (!$user);
  dump_applied();
}

if ($opt_test_utf8) {
  $form->error("--test-utf8 used but no database name given with --dbname.") if (!$opt_dbname);

  my $iconv_to_utf8      = Text::Iconv->new("ISO-8859-15", "UTF-8");
  my $iconv_from_utf8    = Text::Iconv->new("UTF-8", "ISO-8859-15");

  my $umlaut_upper       = 'Ä';
  my $umlaut_upper_utf8  = $iconv_to_utf8->convert($umlaut_upper);

  my $dbconnect          = "dbi:Pg:dbname=${opt_dbname}";
  $dbconnect            .= ";host=${opt_dbhost}" if ($opt_dbhost);
  $dbconnect            .= ";port=${opt_dbport}" if ($opt_dbport);

  my $dbh                = DBI->connect($dbconnect, $opt_dbuser, $opt_dbpassword);

  $form->error("UTF-8 test: Database connect failed (" . $DBI::errstr . ")") if (!$dbh);

  my ($umlaut_lower_utf8) = $dbh->selectrow_array(qq|SELECT lower(?)|, undef, $umlaut_upper_utf8);

  $dbh->disconnect();

  my $umlaut_lower = $iconv_from_utf8->convert($umlaut_lower_utf8);

  if ($umlaut_lower eq 'ä') {
    print "UTF-8 test was successful.\n";
  } elsif ($umlaut_lower eq 'Ä') {
    print "UTF-8 test was NOT successful: Umlauts are not modified (this might be partially ok, but you should probably not use UTF-8 on this cluster).\n";
  } else {
    print "UTF-8 test was NOT successful: Umlauts are destroyed. Do not use UTF-8 on this cluster.\n";
  }
}
