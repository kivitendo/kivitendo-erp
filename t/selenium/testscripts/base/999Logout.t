### Logout

if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly", "t/selenium/testscripts/base/000Login.t", $0);
  exit(0);
}

diag("Logout");
$sel->select_frame_ok("relative=top");
$sel->click_ok("link=abmelden");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->title_is("Lx-Office Version ".$lxtest->{version});
$sel->{ran_tests}{"t/selenium/testscripts/base/000Login.t"} = 0;
1;