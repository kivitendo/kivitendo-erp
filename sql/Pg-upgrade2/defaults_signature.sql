-- @tag: defaults_signature                                                                                                                                                 
-- @description: Neues Feld in defaults für Firmensignatur                                                                                                                  
-- @depends: clients                                                                                                                                                        
-- @ignore: 0                                                                                                                                                               
                                                                                                                                                                            
ALTER TABLE defaults ADD COLUMN signature TEXT;
