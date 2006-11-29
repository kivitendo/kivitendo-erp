### Create Database

diag("Create test database '$lxtest->{db}'");

$sel->open_ok($lxtest->{lxadmin});
$sel->title_is("Lx-Office ERP Administration -");

$sel->open_ok($lxtest->{lxadmin});
$sel->title_is("Lx-Office ERP Administration -");
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Datenbankadministration\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP / Datenbankadministration -");
$sel->type_ok("dbuser", $lxtest->{dbuser});

$sel->type_ok("dbpasswd", $lxtest->{dbpasswd});
$sel->type_ok("dbuser", $lxtest->{dbuser});
$sel->type_ok("dbhost", $lxtest->{dbhost});
$sel->type_ok("dbport", $lxtest->{dbport});
$sel->type_ok("dbdefault", $lxtest->{dbdefault});

$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Datenbank anlegen\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP Datenbankadministration / Datenbank anlegen -");
$sel->type_ok("db", $lxtest->{db});
$sel->select_ok("encoding", "label=ISO 8859-1");
$sel->click_ok("//input[(\@name=\"chart\") and (\@value=\"Germany-DATEV-SKR03EU\")]");
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Weiter\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeoutlong});
$sel->title_is("Lx-Office ERP Datenbankadministration / Datenbank anlegen -");
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Weiter\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP Administration -");
