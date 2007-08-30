if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Delete project");

if(!$sel->get_title("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db})){
  require_ok("M000Login.t");
}

$sel->select_frame_ok("relative=up");
$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
$sel->click_ok("link=Projekte");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->click_ok("action");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->text_is("link=1001", "1001");
$sel->click_ok("link=1001");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
TODO: {
  local $TODO= "Benutzte Projekte können nicht gelöscht werden!";
  $sel->click_ok("document.forms[0].action[1]");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
}

1;