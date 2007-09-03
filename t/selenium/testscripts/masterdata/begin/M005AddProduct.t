if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Add product");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Erzeugnis erfassen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->type_ok("partnumber", "991");
  $sel->type_ok("description", "Handykarten");
  $sel->select_ok("partsgroup", "label=TestSeleniumWarengruppe2");
  $sel->select_ok("buchungsgruppen_id", "label=Standard 16%/19%");
  $sel->click_ok("trigger1");
  $sel->type_ok("listprice", "3,00");
  $sel->type_ok("sellprice", "30,00");
  $sel->select_ok("unit", "label=Stck");
  $sel->type_ok("stock", "100");
  $sel->type_ok("rop", "10");
  $sel->type_ok("bin", "991");
  $sel->click_ok("not_discountable");
  $sel->click_ok("shop");
  $sel->type_ok("price_1", "30,00");
  $sel->type_ok("price_2", "30,00");
  $sel->type_ok("make_1", "TCom");
  $sel->type_ok("model_1", "standard");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.ic.action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;