-- @tag: remove_insecurely_hashed_passwords
-- @description: Passwörter löschen, die mit unsicheren Hash-Verfahren gehasht wurden
-- @depends: release_3_3_0
UPDATE auth.user
SET password = '*'
WHERE (password IS NOT NULL)
  AND (password NOT LIKE '{PBKDF2%')
  AND (password NOT LIKE '{SHA256%');
