if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}

diag("Add project");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Projekt erfassen");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
  $sel->type_ok("projectnumber", "1001");
  $sel->type_ok("description", "tausend und eine Nacht");
  $sel->click_ok("action");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
};
1;