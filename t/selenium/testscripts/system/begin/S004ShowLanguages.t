if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Show languages");

$sel->select_frame_ok("relative=up");
$sel->click_ok("link=Sprachen anzeigen");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->click_ok("link=elbisch");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->click_ok("action");
$sel->wait_for_page_to_load($lxtest->{timeout});
1;