
### Create new user
diag("Create test user '$lxtest->{testuserlogin}'");
$sel->open_ok($lxtest->{lxadmin});

$sel->title_is("Lx-Office ERP Administration -");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP Administration / Benutzer erfassen -");
$sel->type_ok("login", $lxtest->{testuserlogin});
$sel->type_ok("password", $lxtest->{testuserpasswd});
$sel->type_ok("name", "Selenium");
$sel->type_ok("email", "selenium\@lx-office.org");
$sel->type_ok("signature", "Selenium Testuser");
$sel->type_ok("tel", "0000");
$sel->type_ok("fax", "1111");
$sel->type_ok("company", "Sel-enium");
$sel->type_ok("signature", "Selenium Testuser\nTestfirma");
$sel->type_ok("address", "Testfirma");
$sel->type_ok("taxnumber", "111-222-333-444");
$sel->type_ok("co_ustid", "1234567");
$sel->type_ok("duns", "0987654321");
#$sel->click_ok("dbdriver");
$sel->type_ok("newtemplates", "seleniumtestuser");
$sel->click_ok("menustyle");
$sel->type_ok("dbhost", $lxtest->{dbhost});
$sel->type_ok("dbname", $lxtest->{db});
$sel->type_ok("dbport", $lxtest->{dbport});
$sel->type_ok("dbuser", $lxtest->{dbuser});
$sel->type_ok("dbpasswd", $lxtest->{dbpasswd});
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office ERP Administration -");
