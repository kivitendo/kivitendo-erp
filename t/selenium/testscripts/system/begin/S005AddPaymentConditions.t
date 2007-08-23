diag("Add payment conditions");

$sel->select_frame_ok("relative=up");
$sel->click_ok("link=Zahlungskonditionen hinzufügen");
$sel->wait_for_page_to_load($lxtest->{timeout});
$sel->select_frame_ok("main_window");
$sel->type_ok("description", "Schnellzahler/Skonto");
$sel->type_ok("description_long", "Schnellzahler bekommen sofort ein Skonto von 3% gewährleistet");
$sel->type_ok("description_long_" . $lxtest->{lang_id}, "This is a test in elbisch");
$sel->type_ok("terms_netto", "100");
$sel->type_ok("percent_skonto", "3");
$sel->type_ok("terms_skonto", "97");
$sel->click_ok("action");
$sel->wait_for_page_to_load($lxtest->{timeout});
