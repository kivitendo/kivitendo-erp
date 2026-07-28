-- @tag: defaults_add_email_paragraph_styles
-- @description: CSS styles for <p> tags within HTML emails
-- @depends: release_4_0_0

ALTER TABLE defaults
ADD COLUMN email_paragraph_style_body               text NOT NULL DEFAULT '',
ADD COLUMN email_paragraph_style_employee_signature text NOT NULL DEFAULT '',
ADD COLUMN email_paragraph_style_company_signature  text NOT NULL DEFAULT '';
