-- @tag: requirement_specs_section_templates
-- @description: requirement_specs_section_templates
-- @depends: release_3_0_0 requirement_specs

ALTER TABLE requirement_specs ALTER COLUMN type_id     DROP NOT NULL;
ALTER TABLE requirement_specs ALTER COLUMN status_id   DROP NOT NULL;
ALTER TABLE requirement_specs ALTER COLUMN customer_id DROP NOT NULL;

ALTER TABLE requirement_specs
ADD CONSTRAINT requirement_specs_is_template_or_has_customer_status_type
CHECK (
    is_template
 OR (    (type_id     IS NOT NULL)
     AND (status_id   IS NOT NULL)
     AND (customer_id IS NOT NULL))
);
