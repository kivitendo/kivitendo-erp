diag("Add customer/vendor types");

$sel->select_frame_ok("relative=up");
$sel->title_is("Lx-Office Version 2.4.3 - Selenium - " . $lxtest->{db});
$sel->click_ok("link=Kunden-/Lieferantentyp erfassen");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->type_ok("description", "Großabnehmer");
$sel->type_ok("discount", "3");
$sel->type_ok("customernumberinit", "100");
$sel->click_ok("action");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->type_ok("description", "Kleinkäufer");
$sel->type_ok("customernumberinit", "200");
$sel->click_ok("action");
$sel->wait_for_page_to_load($lxtest->{timeout});
