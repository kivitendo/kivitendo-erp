-- @tag: add_master_rights
-- @description: Rechte in die Datenbank migrieren
-- @depends: release_3_2_0
-- @locales: Master Data
-- @locales: Create customers and vendors. Edit all vendors. Edit only customers where salesman equals employee (login)
-- @locales: Create customers and vendors. Edit all vendors. Edit all customers
-- @locales: Create and edit parts, services, assemblies
-- @locales: Show details and reports of parts, services, assemblies
-- @locales: Create and edit projects
-- @locales: AR
-- @locales: Create and edit requirement specs
-- @locales: Create and edit sales quotations
-- @locales: Create and edit sales orders
-- @locales: Create and edit sales delivery orders
-- @locales: Create and edit invoices and credit notes
-- @locales: Create and edit dunnings
-- @locales: Edit sales letters
-- @locales: View/edit all employees sales documents
-- @locales: Edit prices and discount (if not used, textfield is ONLY set readonly)
-- @locales: Show AR transactions as part of AR invoice report
-- @locales: Show delivery plan
-- @locales: Show delivery value report
-- @locales: Show sales letters report
-- @locales: AP
-- @locales: Create and edit RFQs
-- @locales: Create and edit purchase orders
-- @locales: Create and edit purchase delivery orders
-- @locales: Create and edit vendor invoices
-- @locales: Show AP transactions as part of AP invoice report
-- @locales: Warehouse management
-- @locales: View warehouse content
-- @locales: Warehouse management
-- @locales: General ledger and cash
-- @locales: Transactions, AR transactions, AP transactions
-- @locales: DATEV Export
-- @locales: Receipt, payment, reconciliation
-- @locales: Bank transactions
-- @locales: Reports
-- @locales: All reports
-- @locales: Advance turnover tax return
-- @locales: Batch Printing
-- @locales: Batch Printing
-- @locales: Configuration
-- @locales: Change kivitendo installation settings (most entries in the 'System' menu)
-- @locales: Client administration: configuration, editing templates, task server control, background jobs (remaining entries in the 'System' menu)
-- @locales: Others
-- @locales: May set the BCC field when sending emails
-- @locales: Productivity
-- @locales: Show administration link

CREATE TABLE auth.master_rights (
  id          SERIAL PRIMARY KEY,
  position    INTEGER NOT NULL,
  name        TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  category    BOOLEAN NOT NULL DEFAULT FALSE
);


INSERT INTO auth.master_rights (position, name, description, category) VALUES ( 1, 'master_data',                    'Master Data', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES ( 2, 'customer_vendor_edit',           'Create customers and vendors. Edit all vendors. Edit only customers where salesman equals employee (login)');
INSERT INTO auth.master_rights (position, name, description) VALUES ( 3, 'customer_vendor_all_edit',       'Create customers and vendors. Edit all vendors. Edit all customers');
INSERT INTO auth.master_rights (position, name, description) VALUES ( 4, 'part_service_assembly_edit',     'Create and edit parts, services, assemblies');
INSERT INTO auth.master_rights (position, name, description) VALUES ( 5, 'part_service_assembly_details',  'Show details and reports of parts, services, assemblies');
INSERT INTO auth.master_rights (position, name, description) VALUES ( 6, 'project_edit',                   'Create and edit projects');
INSERT INTO auth.master_rights (position, name, description, category) VALUES ( 7, 'ar',                             'AR', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES ( 8, 'requirement_spec_edit',          'Create and edit requirement specs');
INSERT INTO auth.master_rights (position, name, description) VALUES ( 9, 'sales_quotation_edit',           'Create and edit sales quotations');
INSERT INTO auth.master_rights (position, name, description) VALUES (10, 'sales_order_edit',               'Create and edit sales orders');
INSERT INTO auth.master_rights (position, name, description) VALUES (11, 'sales_delivery_order_edit',      'Create and edit sales delivery orders');
INSERT INTO auth.master_rights (position, name, description) VALUES (12, 'invoice_edit',                   'Create and edit invoices and credit notes');
INSERT INTO auth.master_rights (position, name, description) VALUES (13, 'dunning_edit',                   'Create and edit dunnings');
INSERT INTO auth.master_rights (position, name, description) VALUES (14, 'sales_letter_edit',              'Edit sales letters');
INSERT INTO auth.master_rights (position, name, description) VALUES (15, 'sales_all_edit',                 'View/edit all employees sales documents');
INSERT INTO auth.master_rights (position, name, description) VALUES (16, 'edit_prices',                    'Edit prices and discount (if not used, textfield is ONLY set readonly)');
INSERT INTO auth.master_rights (position, name, description) VALUES (17, 'show_ar_transactions',           'Show AR transactions as part of AR invoice report');
INSERT INTO auth.master_rights (position, name, description) VALUES (18, 'delivery_plan',                  'Show delivery plan');
INSERT INTO auth.master_rights (position, name, description) VALUES (19, 'delivery_value_report',          'Show delivery value report');
INSERT INTO auth.master_rights (position, name, description) VALUES (20, 'sales_letter_report',            'Show sales letters report');
INSERT INTO auth.master_rights (position, name, description, category) VALUES (21, 'ap',                             'AP', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES (22, 'request_quotation_edit',         'Create and edit RFQs');
INSERT INTO auth.master_rights (position, name, description) VALUES (23, 'purchase_order_edit',            'Create and edit purchase orders');
INSERT INTO auth.master_rights (position, name, description) VALUES (24, 'purchase_delivery_order_edit',   'Create and edit purchase delivery orders');
INSERT INTO auth.master_rights (position, name, description) VALUES (25, 'vendor_invoice_edit',            'Create and edit vendor invoices');
INSERT INTO auth.master_rights (position, name, description) VALUES (26, 'show_ap_transactions',           'Show AP transactions as part of AP invoice report');
INSERT INTO auth.master_rights (position, name, description, category) VALUES (27, 'warehouse',                      'Warehouse management', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES (28, 'warehouse_contents',             'View warehouse content');
INSERT INTO auth.master_rights (position, name, description) VALUES (29, 'warehouse_management',           'Warehouse management');
INSERT INTO auth.master_rights (position, name, description, category) VALUES (30, 'general_ledger_cash',            'General ledger and cash', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES (31, 'general_ledger',                 'Transactions, AR transactions, AP transactions');
INSERT INTO auth.master_rights (position, name, description) VALUES (32, 'datev_export',                   'DATEV Export');
INSERT INTO auth.master_rights (position, name, description) VALUES (33, 'cash',                           'Receipt, payment, reconciliation');
INSERT INTO auth.master_rights (position, name, description) VALUES (34, 'bank_transaction',               'Bank transactions');
INSERT INTO auth.master_rights (position, name, description, category) VALUES (35, 'reports',                        'Reports', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES (36, 'report',                         'All reports');
INSERT INTO auth.master_rights (position, name, description) VALUES (37, 'advance_turnover_tax_return',    'Advance turnover tax return');
INSERT INTO auth.master_rights (position, name, description, category) VALUES (38, 'batch_printing_category',                 'Batch Printing', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES (39, 'batch_printing',                 'Batch Printing');
INSERT INTO auth.master_rights (position, name, description, category) VALUES (40, 'configuration',                  'Configuration', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES (41, 'config',                         'Change kivitendo installation settings (most entries in the ''System'' menu)');
INSERT INTO auth.master_rights (position, name, description) VALUES (42, 'admin',                          'Client administration: configuration, editing templates, task server control, background jobs (remaining entries in the ''System'' menu)');
INSERT INTO auth.master_rights (position, name, description, category) VALUES (43, 'others',                         'Others', TRUE);
INSERT INTO auth.master_rights (position, name, description) VALUES (44, 'email_bcc',                      'May set the BCC field when sending emails');
INSERT INTO auth.master_rights (position, name, description) VALUES (45, 'productivity',                   'Productivity');
INSERT INTO auth.master_rights (position, name, description) VALUES (46, 'display_admin_link',             'Show administration link');
