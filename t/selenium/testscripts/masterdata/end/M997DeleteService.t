if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Delete service");

if(!$sel->get_title("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db})){
  require_ok("M000Login.t");
}

$sel->select_frame_ok("relative=up");
$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
$sel->click_ok("link=Dienstleistungen");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->text_is("link=999", "999");
$sel->text_is("link=998", "998");
$sel->text_is("link=Programmierstunde", "Programmierstunde");
$sel->text_is("link=Telefonstunde", "Telefonstunde");
$sel->click_ok("link=999");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("document.ic.action[3]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("link=Telefonstunde");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->click_ok("document.ic.action[3]");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
1;