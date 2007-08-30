if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}

$sel->open_ok($lxtest->{lxadmin});

$sel->title_is("Lx-Office ERP Administration -");

diag('Lock the system');
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"System sperren\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});

$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Datenbankadministration\")]");
diag("Delete test database '$lxtest->{db}'");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP / Datenbankadministration -");
$sel->type_ok("dbhost", $lxtest->{dbhost});
$sel->type_ok("dbport", $lxtest->{dbport});
$sel->type_ok("dbuser", $lxtest->{dbuser});
$sel->type_ok("dbpasswd", $lxtest->{dbpasswd});
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Datenbank löschen\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeoutlong});
$sel->title_is("Lx-Office ERP Datenbankadministration / Datenbank löschen -");

$sel->select_ok("db", "label=" . $lxtest->{db});

$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Weiter\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->body_text_is("Lx-Office ERP Datenbankadministration / Datenbank löschen Die Datenbank $lxtest->{db} wurde erfolgreich gelöscht.");
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Weiter\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP Administration -");

diag('Unlock the system');
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"System entsperren\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP Administration -");
1;