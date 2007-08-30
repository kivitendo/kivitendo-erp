### Delete user
if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}

diag("Delete test user '$lxtest->{testuserlogin}'");
$sel->open_ok($lxtest->{lxadmin});

$sel->title_is("Lx-Office ERP Administration -");
$sel->click_ok("link=$lxtest->{testuserlogin}");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP Administration / Benutzerdaten bearbeiten -");
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Löschen\")]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
1;