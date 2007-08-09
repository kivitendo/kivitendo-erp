### Login

diag("Login");

$sel->open_ok($lxtest->{lxbaseurl}."/login.pl");

$sel->wait_for_page_to_load_ok($lxtest->{timeout}); 
$sel->title_is("Lx-Office Version ".$lxtest->{version});
$sel->type_ok("login", $lxtest->{testuserlogin});
$sel->type_ok("password", $lxtest->{testuserpasswd});
$sel->click_ok("//input[(\@name=\"action\") and (\@value=\"Anmeldung\")]");

$sel->wait_for_page_to_load_ok($lxtest->{timeout});
if($sel->title_is("Datenbankaktualisierung - Lx-Office Version 2.4.3 - -")) {
  $sel->click_ok("//input[(\@name=\"dummy\") and (\@value=\"Weiter\")]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeoutlong}); 
  $sel->click_ok("//input[(\@type=\"submit\") and (\@value=\"Weiter\")]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout}); 
}

$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
