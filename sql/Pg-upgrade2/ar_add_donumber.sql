-- @tag: ar_add_donumber
-- @description: Die Lieferscheinnummer wird bei Rechnungen bisher nicht uebernommen. Das aendert sich mit diesem Update. Hierfuer muss allerdings die Rechnungstabelle ar um einen entsprechenden Eintrag erweitert werden. (donumber in ar)
-- @depends: COA_Account_Settings001 USTVA_abstraction COA_Account_Settings002 chart_category_to_sgn employee_no_limits dunning_invoices_per_dunning_level gl_storno oe_is_salesman transaction_description tax_description_without_percentage_skr04 dunning_dunning_id ar_ap_storno_id dunning_config_interest_rate invalid_taxkeys_2 chart_names2 history_erp_snumbers marge_initial USTVA_at tax_report_table_name
alter table ar add column donumber text;

