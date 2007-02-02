-- @tag: payment_terms_translation
-- @description: &Uuml;bersetzungen von Zahlungskonditionen
-- @depends: release_2_4_1
CREATE TABLE translation_payment_terms (
  payment_terms_id integer NOT NULL,
  language_id integer NOT NULL,
  description_long text,

  FOREIGN KEY (payment_terms_id) REFERENCES payment_terms (id),
  FOREIGN KEY (language_id) REFERENCES language (id)
);
