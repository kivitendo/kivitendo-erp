if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Add service");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Dienstleistung erfassen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->type_ok("partnumber", "999");
  $sel->type_ok("description", "Programmierstunde");
  $sel->select_ok("partsgroup", "label=TestSeleniumWarengruppe3");
  $sel->select_ok("buchungsgruppen_id", "label=Standard 16%/19%");
  $sel->type_ok("notes", "Eine Programmierstunde wird immer besser bezahlt");
  $sel->type_ok("listprice", "50,00");
  $sel->type_ok("sellprice", "100");
  $sel->type_ok("lastcost", "45");
  $sel->select_ok("unit", "label=Std");
  $sel->select_ok("payment_id", "label=Schnellzahler/Skonto");
  $sel->type_ok("price_1", "100");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.ic.action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->type_ok("partnumber", "998");
  $sel->type_ok("description", "Telefonstunde");
  $sel->select_ok("partsgroup", "label=TestSeleniumWarengruppe3");
  $sel->select_ok("buchungsgruppen_id", "label=Standard 16%/19%");
  $sel->type_ok("notes", "gibt's beim Telekomunikator");
  $sel->type_ok("listprice", "0,05");
  $sel->type_ok("sellprice", "0,10");
  $sel->type_ok("lastcost", "0,02");
  $sel->select_ok("unit", "label=psch");
  $sel->select_ok("payment_id", "label=Schnellzahler/Skonto");
  $sel->type_ok("price_1", "0,02");
  $sel->type_ok("price_2", "0,1");
  $sel->type_ok("price_1", "0,1");
  $sel->click_ok("document.ic.action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;