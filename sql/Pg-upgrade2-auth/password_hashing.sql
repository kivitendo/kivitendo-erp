-- @tag: password_hashing
-- @description: Explicitely set a password hashing algorithm
-- @depends:
UPDATE auth."user"
  SET password = '{CRYPT}' || password
  WHERE NOT (password IS NULL)
    AND (password <> '')
    AND NOT (password LIKE '{%}%');
