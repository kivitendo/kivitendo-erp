diag("CreateProductGroups");

if(!$sel->get_title("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db})){
  require_ok("../../begin/B004Login.t");
}

$sel->select_frame_ok("relative=up");
$sel->click_ok("link=Warengruppe erfassen");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->type_ok("partsgroup", "TestSeleniumWarengruppe1");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->type_ok("partsgroup", "TestSeleniumWarengruppe2");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->select_frame_ok("relative=up");
$sel->click_ok("link=Warengruppen anzeigen");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("link=TestSeleniumWarengruppe1");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("link=TestSeleniumWarengruppe2");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->type_ok("partsgroup", "TestSeleniumWarengruppe3");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("link=TestSeleniumWarengruppe3");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});