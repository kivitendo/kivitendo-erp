# $Id: oscom.sql,v 1.2 2004/07/01 20:50:34 hli Exp $
# Zusatztabelle Kundenbeziehung ERP - osCommerce
#
CREATE TABLE customers_number (
  cid int(6) NOT NULL auto_increment,
  customers_id int(3) NOT NULL default '0',
  kdnr int(3) NOT NULL default '0',
  PRIMARY KEY  (cid)
) TYPE=MyISAM;
