if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Create goods");

if(!$sel->get_title("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db})){
  require_ok("../../begin/B004Login.t");
}

$sel->select_frame_ok("relative=up");
$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
$sel->click_ok("link=Ware erfassen");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->type_ok("partnumber", "1");
$sel->type_ok("description", "TestWare1");
$sel->select_ok("partsgroup", "label=TestSeleniumWarengruppe1");
$sel->select_ok("buchungsgruppen_id", "label=Standard 16%/19%");
$sel->click_ok("trigger1");
$sel->type_ok("listprice", "100,00");
$sel->type_ok("sellprice", "150,00");
$sel->type_ok("lastcost", "50,00");
$sel->select_ok("price_factor_id", "label=pro 10");
$sel->type_ok("notes", "Zu dieser Testware existiert keine Bemerkung");
$sel->select_ok("unit", "label=kg");
$sel->type_ok("weight", "10");
$sel->type_ok("rop", "10");
$sel->type_ok("bin", "1");
$sel->type_ok("ve", "10");
$sel->click_ok("shop");
$sel->type_ok("microfiche", "27 drei 4tel");
$sel->select_ok("payment_id", "label=Schnellzahler/Skonto");
# Spracheinstellungen müssen überarbeitet werden, bevor der Test laufen kann!
# $sel->click_ok("//button[\@type='button']");
# $sel->wait_for_pop_up_ok("_new_generic", $lxtest->{timeout});
# $sel->click_ok("//button[\@type='button']");
# $sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->type_ok("price_1", "115,00");
$sel->type_ok("price_2", "150,00");
$sel->type_ok("make_1", "TestFabrikant1");
$sel->type_ok("model_1", "TestWare1");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("document.ic.action[1]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->type_ok("partnumber", "2");
$sel->type_ok("description", "TestWareSelenium2");
$sel->type_ok("listprice", "0,50");
$sel->type_ok("sellprice", "1,00");
$sel->type_ok("lastcost", ",25");
$sel->select_ok("unit", "label=kg");
$sel->type_ok("weight", "0,5");
$sel->type_ok("rop", "2");
$sel->type_ok("bin", "2");
$sel->click_ok("not_discountable");
$sel->type_ok("ve", "1");
$sel->type_ok("notes", "Die ist Brot");
# Spracheinstellungen müssen überarbeitet werden, bevor der Test laufen kann!
# $sel->click_ok("//button[\@type='button']");
# $sel->wait_for_pop_up_ok("_new_generic", $lxtest->{timeout});
# $sel->click_ok("//button[\@type='button']");
# $sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->select_ok("payment_id", "label=Schnellzahler/Skonto");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("document.ic.action[1]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
1;