diag("Create price brackets");

$sel->select_frame_ok("relative=up");
$sel->click_ok("link=Preisgruppe erfassen");
$sel->wait_for_page_to_load($lxtest->{timeout});

$sel->select_frame_ok("main_window");
$sel->type_ok("pricegroup", "SeleniumTestPreisgruppe1");
$sel->click_ok("action","value=Speichern");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});
$sel->type_ok("pricegroup", "SeleniumTestPreisgruppe2");
$sel->click_ok("action","value=Speichern");
$sel->wait_for_page_to_load_ok($lxtest->{timeout});

