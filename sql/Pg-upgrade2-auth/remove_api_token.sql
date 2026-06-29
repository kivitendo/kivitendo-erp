-- @tag: remove_api_token
-- @description: Automatische Authentifizierung bestehender Sessions über Session-ID + API-Token für längst entferntes CRM-Menü ebenfalls entfernen
-- @depends: release_4_0_0
ALTER TABLE auth.session DROP COLUMN api_token;
