if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Delete Account");

$sel->select_frame_ok("relative=up");
$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
$sel->click_ok("link=Konten anzeigen");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->click_ok("link=000000000001");
$sel->wait_for_page_to_load_ok("30000");
$sel->click_ok("document.EditAccount.action[1]");
$sel->wait_for_page_to_load_ok("30000");
isnt($sel->is_element_present("link=000000000001"),1,"Tests whether link for created acc is present");
isnt($sel->is_text_present("TestSeleniumKonto"),1,"Tests wheter text of created acc is present");
1;