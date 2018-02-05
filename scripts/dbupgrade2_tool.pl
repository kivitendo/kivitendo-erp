#!/usr/bin/perl

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');
  push   (@INC, $FindBin::Bin . '/../modules/fallback'); # Only use our own versions of modules if there's no system version.
}

use strict;
use warnings;

use utf8;
use English '-no_match_vars';

use Config::Std;
use DBI;
use Data::Dumper;
use Getopt::Long;
use Text::Iconv;

use SL::LXDebug;
use SL::LxOfficeConf;

SL::LxOfficeConf->read;
our $lxdebug = LXDebug->new();

use SL::Auth;
use SL::Form;
use SL::User;
use SL::Locale;
use SL::DBUpgrade2;
use SL::DBUtils;
use SL::Dispatcher;

#######
#######
#######

my ($opt_list, $opt_tree, $opt_rtree, $opt_nodeps, $opt_graphviz, $opt_help);
my ($opt_user, $opt_client, $opt_apply, $opt_applied, $opt_unapplied, $opt_format, $opt_test_utf8);
my ($opt_dbhost, $opt_dbport, $opt_dbname, $opt_dbuser, $opt_dbpassword, $opt_create, $opt_type);
my ($opt_description, @opt_depends, $opt_auth_db);

our (%myconfig, $form, $user, $auth, $locale, $controls, $dbupgrader);

sub connect_auth {
  return $auth if $auth;

  $auth = SL::Auth->new;
  if (!$auth->session_tables_present) {
    $form->error("The session and user management tables are not present in the authentication database. Please use the administration web interface to create them.");
  }

  return $auth;
}

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
    --create=tag         Creates a new upgrade with the supplied tag. This
                         action accepts several optional other options. See
                         the option section for those. After creating the
                         upgrade file your \$EDITOR will be called with it.
    --apply=tag          Applies the database upgrades \'tag\' and all
                         upgrades it depends on. If \'--apply\' is used
                         then the option \'--user\' must be used as well.
    --applied            List the applied database upgrades for the
                         database that the user given with \'--user\' uses.
    --unapplied          List the database upgrades that haven\'t been applied
                         yet to the database that the user given with
                         \'--user\' uses.
    --test-utf8          Tests a PostgreSQL cluster for proper UTF-8 support.
                         You have to specify the database to test with the
                         parameters --dbname, --dbhost, --dbport, --dbuser
                         and --dbpassword.
    --help               Show this help and exit.

  General Options:
    --client=id-or-name  The name (or database ID) of the client to use for
                         database connectivity. You must provide both a client
                         and a user.
    --user=name          The name of the user configuration to use for
                         database connectivity. You must provide both a client
                         and a user.
    --auth-db            Work on the authentication database instead of a
                         user database.
    --dbname=name        Database connection options for the UTF-8
    --dbhost=host        handling test.
    --dbport=port
    --dbuser=user
    --dbpassword=pw

  Options for --create:
    --type               \'sql\' or \'pl\'. Defaults to sql.
    --description        The description field of the generated upgrade.
    --depends            Tags of upgrades which this upgrade depends upon.
                         Defaults to the latest stable release upgrade.
                         Multiple values possible.

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
  my @sorted_controls = $dbupgrader->sort_dbupdate_controls;

  print "LIST VIEW\n\n" .
    "number tag depth priority\n";

  my $i = 0;
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

  my @sorted_controls = $dbupgrader->sort_dbupdate_controls;

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

  my @sorted_controls = $dbupgrader->sort_dbupdate_controls;

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

  my $dot = "|dot -T${format} ";
  open OUT, "${dot}> \"${file_name}\"" || die;

  print OUT
    "digraph db_dependencies {\n" .
    "graph [size=\"16.53,11.69!\"];\n" .
    "node [shape=box style=filled fillcolor=white];\n";

  my %ranks;
  foreach my $c (values %{ $controls }) {
    $ranks{$c->{depth}} ||= [];

    my ($pre, $post) = @{ $c->{rev_depends} } ? ('')x2 :
      (map "node [fillcolor=$_] ", qw(lightgray white));

    push @{ $ranks{$c->{"depth"}} }, qq|${pre}"$c->{tag}"; ${post}|;
  }

  foreach (sort keys %ranks) {
    print OUT "{ rank = same; ", join("", @{ $ranks{$_} }), " }\n";
  }

  foreach my $c (values %{ $controls }) {
    print OUT qq|"$c->{tag}";\n|;

    foreach my $d (@{ $c->{depends} }) {
      print OUT qq|"$c->{tag}" -> "$d";\n|;
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

sub create_upgrade {
  my (%params) = @_;

  my $filename    = $params{filename};
  my $dbupgrader  = $params{dbupgrader};
  my $type        = $params{type}        || 'sql';
  my $description = $params{description} || '';
  my @depends     = @{ $params{depends} };

  my $encoding    = 'utf-8';

  if (!@depends) {
    my @releases = grep { /^release_/ } keys %$controls;
    @depends = ((sort @releases)[-1]);
  }

  my $comment;
  if ($type eq 'sql') {
    $comment = '--';
  } elsif ($type eq 'pl') {
    $comment = '#';
  } elsif (!$type) {
    die 'Error: No --type was given but is required for --create.';
  } else {
    die 'Error: Unknown --type. Try "sql" or "pl".';
  }

  my $full_filename = $dbupgrader->path . '/' . $filename . '.' . $type;

  die "file '$full_filename' already exists, aborting" if -f $full_filename;


  open my $fh, ">:encoding($encoding)", $full_filename or die "can't open $full_filename";
  print $fh "$comment \@tag: $filename\n";
  print $fh "$comment \@description: $description\n";
  print $fh "$comment \@depends: @depends\n";

  if ($type eq 'pl') {
    print $fh "package SL::DBUpgrade2::$filename;\n";
    print $fh "\n";
    print $fh "use strict;\n";
    print $fh "use utf8;\n" if $encoding =~ /utf.?8/i;
    print $fh "\n";
    print $fh "use parent qw(SL::DBUpgrade2::Base);\n";
    print $fh "\n";
    print $fh "sub run {\n";
    print $fh "  my (\$self) = \@_;\n";
    print $fh "\n";
    print $fh "}\n";
    print $fh "\n";
    print $fh "1;\n";
  }

  close $fh;

  print "File $full_filename created.\n";

  system("\$EDITOR $full_filename");
  exit 0;
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

  my $dbh            = $opt_auth_db ? connect_auth()->dbconnect : SL::DB->client->dbh;

  $dbh->{PrintWarn}  = 0;
  $dbh->{PrintError} = 0;

  $user->create_schema_info_table($form, $dbh);

  my $query = qq|SELECT tag FROM schema_info|;
  my $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  while (my ($tag) = $sth->fetchrow_array()) {
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
    $dbupgrader->process_file($dbh, "sql/Pg-upgrade2/$control->{file}", $control);
  }

  $dbh->disconnect unless $opt_auth_db;
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

  my $dbh            = $opt_auth_db ? connect_auth()->dbconnect : SL::DB->client->dbh;
  $dbh->{AutoCommit} = 0;

  $dbh->{PrintWarn}  = 0;
  $dbh->{PrintError} = 0;

  $user->create_schema_info_table($form, $dbh);

  my $query = qq|SELECT tag, login, itime FROM schema_info ORDER BY itime|;
  my $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  while (my $ref = $sth->fetchrow_hashref()) {
    push @results, $ref;
  }
  $sth->finish();

  $dbh->disconnect unless $opt_auth_db;

  if (!scalar @results) {
    print "No database upgrades have been applied yet.\n";
  } else {
    dump_sql_result(\@results, [qw(tag login itime)]);
  }
}

sub dump_unapplied {
  my @results;

  my $dbh = $opt_auth_db ? connect_auth()->dbconnect : SL::DB->client->dbh;

  $dbh->{PrintWarn}  = 0;
  $dbh->{PrintError} = 0;

  my @unapplied = $dbupgrader->unapplied_upgrade_scripts($dbh);

  $dbh->disconnect unless $opt_auth_db;

  if (!scalar @unapplied) {
    print "All database upgrades have been applied.\n";
  } else {
    print map { $_->{tag} . "\n" } @unapplied;
  }
}

sub build_upgrade_order {
  my $name  = shift;
  my $order = shift;
  my $tags  = shift;

  my $control = $controls->{$name};

  foreach my $dependency (@{ $control->{depends} }) {
    next if $tags->{$dependency};
    $tags->{$dependency} = 1;
    build_upgrade_order($dependency, $order, $tags);
  }

  push @{ $order }, $name;
  $tags->{$name} = 1;
}

#######
#######
#######

$locale    = Locale->new;
$form      = Form->new;
$::request = SL::Request->new(
  cgi    => CGI->new({}),
  layout => SL::Layout::None->new,
);

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
           "client=s"     => \$opt_client,
           "apply=s"      => \$opt_apply,
           "applied"      => \$opt_applied,
           "create=s"     => \$opt_create,
           "type=s"       => \$opt_type,
           "description=s" => \$opt_description,
           "depends=s"    => \@opt_depends,
           "unapplied"    => \$opt_unapplied,
           "test-utf8"    => \$opt_test_utf8,
           "dbhost:s"     => \$opt_dbhost,
           "dbport:s"     => \$opt_dbport,
           "dbname:s"     => \$opt_dbname,
           "dbuser:s"     => \$opt_dbuser,
           "dbpassword:s" => \$opt_dbpassword,
           "auth-db"      => \$opt_auth_db,
           "help"         => \$opt_help,
  );

show_help() if ($opt_help);

$dbupgrader = SL::DBUpgrade2->new(form => $form, auth => $opt_auth_db);
$controls   = $dbupgrader->parse_dbupdate_controls->{all_controls};

dump_list()                                 if ($opt_list);
dump_tree()                                 if ($opt_tree);
dump_tree_reverse()                         if ($opt_rtree);
dump_graphviz('file_name' => $opt_graphviz,
              'format'    => $opt_format)   if (defined $opt_graphviz);
dump_nodeps()                               if ($opt_nodeps);
create_upgrade(filename   => $opt_create,
               dbupgrader  => $dbupgrader,
               type        => $opt_type,
               description => $opt_description,
               depends     => \@opt_depends) if ($opt_create);

if ($opt_client && !connect_auth()->set_client($opt_client)) {
  $form->error($form->format_string("The client '#1' does not exist.", $opt_client));
}

if ($opt_user) {
  $form->error("Need a client, too.") if !$auth || !$auth->client;

  %myconfig = connect_auth()->read_user(login => $opt_user);

  if (!$myconfig{login}) {
    $form->error($form->format_string("The user '#1' does not exist.", $opt_user));
  }

  $locale = new Locale($myconfig{countrycode}, "all");
  $user   = new User(login => $opt_user);

  map { $form->{$_} = $myconfig{$_} } keys %myconfig;
}

if ($opt_apply) {
  $form->error("--apply used but no user name given with --user.") if !$user && !$opt_auth_db;
  apply_upgrade($opt_apply);
}

if ($opt_applied) {
  $form->error("--applied used but no user name given with --user.") if !$user && !$opt_auth_db;
  dump_applied();
}

if ($opt_unapplied) {
  $form->error("--unapplied used but no user name given with --user.") if !$user && !$opt_auth_db;
  dump_unapplied();
}


if ($opt_test_utf8) {
  $form->error("--test-utf8 used but no database name given with --dbname.") if (!$opt_dbname);

  my $umlaut_upper       = 'Ä';

  my $dbconnect          = "dbi:Pg:dbname=${opt_dbname}";
  $dbconnect            .= ";host=${opt_dbhost}" if ($opt_dbhost);
  $dbconnect            .= ";port=${opt_dbport}" if ($opt_dbport);

  my $dbh                = DBI->connect($dbconnect, $opt_dbuser, $opt_dbpassword, { pg_enable_utf8 => 1 });

  $form->error("UTF-8 test: Database connect failed (" . $DBI::errstr . ")") if (!$dbh);

  my ($umlaut_lower) = $dbh->selectrow_array(qq|SELECT lower(?)|, undef, $umlaut_upper);

  $dbh->disconnect();

  if ($umlaut_lower eq 'ä') {
    print "UTF-8 test was successful.\n";
  } elsif ($umlaut_lower eq 'Ä') {
    print "UTF-8 test was NOT successful: Umlauts are not modified (this might be partially ok, but you should probably not use UTF-8 on this cluster).\n";
  } else {
    print "UTF-8 test was NOT successful: Umlauts are destroyed. Do not use UTF-8 on this cluster.\n";
  }
}
