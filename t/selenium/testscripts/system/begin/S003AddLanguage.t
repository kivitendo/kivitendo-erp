if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Add languages");

$sel->select_frame_ok("relative=up");
$sel->click_ok("link=Sprache hinzufügen");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->type_ok("description", "elbisch");
$sel->type_ok("template_code", "elb");
$sel->type_ok("article_code", "elb");
$sel->select_ok("output_numberformat", "label=1.000,00");
$sel->select_ok("output_dateformat", "label=yyyy-mm-dd");
$sel->click_ok("action");
$sel->wait_for_page_to_load($lxtest->{timeout});

use DBI;
$lxtest->{dsn} = 'dbi:Pg:dbname=' . $lxtest->{db} . ';host=' . $lxtest->{dbhost} . ';port=' . $lxtest->{dbport};
my $dbh = DBI->connect( $lxtest->{dsn}, $lxtest->{dbuser}, $lxtest->{dbpasswd} ) or die "Cannot connect to database!\n $DBI::errstr";
my $sth = $dbh->prepare("SELECT id FROM language WHERE description ILIKE 'elbisch'") or die "Error while preparing sql statement!\n $DBI::errstr\n";
$sth->execute() or die "Error while excecuting sql statement!\n $DBI::errstr";
$lxtest->{lang_id} = $sth->fetchrow_array() or die "Nothing to fetch!\n$DBI::errstr";
$sth->finish();
$dbh->disconnect();

1;