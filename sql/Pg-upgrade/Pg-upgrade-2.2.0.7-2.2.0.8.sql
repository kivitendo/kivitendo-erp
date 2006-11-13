CREATE TABLE "printers" (
	"id" integer DEFAULT nextval('id'::text) PRIMARY KEY,
	"printer_description" text NOT NULL,
	"printer_command" text,
	"template_code" text
);