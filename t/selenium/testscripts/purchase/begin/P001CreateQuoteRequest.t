if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Create quote request");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Neue Preisanfrage");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->click_ok("partnumber_1");
  $sel->type_ok("partnumber_1", "1");
  $sel->click_ok("update_button");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("quonumber");
  $sel->type_ok("quonumber", "1");
  $sel->click_ok("cp_id");
  $sel->select_ok("cp_id", "label=Baumann von Clausen (Vertrieb)");
  $sel->click_ok("//option[\@value='905']");
  $sel->click_ok("shipto_id");
  $sel->click_ok("shipto_id");
  $sel->click_ok("taxzone_id");
  $sel->click_ok("taxzone_id");
  $sel->click_ok("cb_show_details");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("payment_id");
  $sel->select_ok("payment_id", "label=Schnellzahler/Skonto");
  $sel->click_ok("//option[\@value='886']");
  $sel->click_ok("//tr[5]/td/table/tbody/tr/td[3]");
  $sel->click_ok("taxincluded");
  $sel->click_ok("qty_1");
  $sel->type_ok("qty_1", "21");
  $sel->click_ok("update_button");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.oe.action[6]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;