if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Create invoice");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Rechnung erfassen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->select_ok("customer", "label=TestFrau3");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->type_ok("partnumber_1", "1");
  $sel->click_ok("update_button");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->type_ok("partnumber_2", "991");
  $sel->click_ok("update_button");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->type_ok("invnumber", "1");
  $sel->click_ok("trigger3");
  $sel->click_ok("trigger_orddate");
  $sel->type_ok("quonumber", "2");
  $sel->click_ok("trigger_quodate");
  $sel->select_ok("payment_id", "label=Schnellzahler/Skonto");
  $sel->click_ok("update_button");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("document.invoice.action[6]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;