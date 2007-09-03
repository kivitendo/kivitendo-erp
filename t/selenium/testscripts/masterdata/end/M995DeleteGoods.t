if(!defined $sel) {
  require "t/selenium/AllTests.t";
  init_server("singlefileonly",$0);
  exit(0);
}
diag("Delete good");
SKIP: {
  start_login();
  
  $sel->click_ok("link=Erzeugnisse");
  $sel->wait_for_page_to_load_ok($lxtest->{timeout});
  $sel->select_frame_ok("main_window");
};

# an dieser Stelle muss noch überleegt werdne, wie der Zusaamenhang zwischen Lagerbestand und "Löschen" vernünftigt gehandhabt werdne kann

1;