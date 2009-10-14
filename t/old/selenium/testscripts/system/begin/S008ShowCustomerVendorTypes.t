if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Show customer/vendor types");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Kunden\-\/Lieferantentypen\ anzeigen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->click_ok("link=Großabnehmer");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("link=Kleinkäufer");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;