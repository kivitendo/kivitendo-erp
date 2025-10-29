-- @tag: income_statement_ch_detailed_views
-- @description: Kategorien für die Schweizer Erfolgsrechnung (Detailliert) in der Datenbank speichern (als View)
-- @depends: release_3_9_2

-- NOTE: this is similar to how it is done for the german BWA/EUR (Betriebswirtschaftliche Abrechnung/Einnahmen-Ueberschuss Rechnung)

CREATE OR REPLACE VIEW "income_statement_ch_detailed_groups" (id, description) AS VALUES
(1, 'Betrieblicher Ertrag aus Lieferungen und Leistungen'),
(2, 'Bruttoergebnis nach Material- und Warenaufwand'),
(3, 'Bruttoergebnis nach Personalaufwand'),
(4, 'Betriebliches Ergebnis vor Abschreibungen und Wertberichtigungen, Finanzerfolg und Steuern (EBITDA)'),
(5, 'Betriebliches Ergebnis vor Finanzerfolg und Steuern (EBIT)'),
(6, 'Betriebliches Ergebnis vor Steuern (EBT)'),
(7, 'Jahresgewinn oder Jahresverlust vor Steuern'),
(8, 'Jahresgewinn oder Jahresverlust');

-- NOTE: group_id is referencing the ids from above table, we don't have any foreign key checks,
-- but we think this is okay in this case because it is rarely supposed to change, take care when changing the group_id
CREATE OR REPLACE VIEW "income_statement_ch_detailed_categories" (id, description, account_range, group_id) AS VALUES
( 1, 'Nettoerlöse aus Lieferungen und Leistungen', '30-38', 1),
( 2, 'Bestandesänderungen an unfertigen und fertigen Erzeugnissen sowie an nicht fakturierten Dienstleistungen', '39', 1),
( 3, 'Material- und Warenaufwand', '4', 2),
( 4, 'Personalaufwand', '5', 3),
( 5, 'Übriger betrieblicher Aufwand', '60-67', 4),
( 6, 'Abschreibungen und Wertberichtigungen auf Positionen des Anlagevermögens', '68', 5),
( 7, 'Finanzaufwand', '690', 6),
( 8, 'Finanzertrag', '695', 6),
( 9, 'Betrieblicher Nebenerfolg', '7', 7),
(10, 'Betriebsfremder Aufwand', '800', 7),
(11, 'Betriebsfremder Ertrag', '810', 7),
(12, 'Ausserordentlicher, einmaliger oder periodenfremder Aufwand', '850', 7),
(13, 'Ausserordentlicher, einmaliger oder periodenfremder Ertrag', '851', 7),
(14, 'Direkte Steuern', '89', 8);
