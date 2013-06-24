-- @tag: payment_terms_translation2
-- @description: Eingliederung von payment_terms_translation in generic_translations
-- @depends: release_2_6_1
INSERT INTO generic_translations (language_id, translation_type, translation_id, translation)
  SELECT language_id, 'SL::DB::PaymentTerm/description_long', payment_terms_id, description_long
  FROM translation_payment_terms;

DROP TABLE translation_payment_terms;
