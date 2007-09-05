require "t/selenium/AllTests.t";

init_server("administration/begin", "system/begin", "masterdata/begin", "selling/begin", "purchase/begin", 
            "accounting/begin", "payments/begin", "reports/begin", "programm/begin", 
            "programm/end", "reports/end", "payments/end", "accounting/end", "purchase/end", "selling/end",
            "masterdata/end", "system/end", "administration/end");

1;