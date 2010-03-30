#!/bin/bash

echo reset lx-office-erp/admin-password-conf | debconf-communicate 
echo fset lx-office-erp/admin-password seen false | debconf-communicate 
echo fset lx-office-erp/admin-password seen false | debconf-communicate 
echo reset lx-office-erp/admin-password  | debconf-communicate 
echo reset lx-office-erp/admin-password2 | debconf-communicate 
echo reset lx-office-erp/lx-office-erp-user-postgresql-password | debconf-communicate  
echo reset lx-office-erp/lx-office-erp-user-postgresql-password2 | debconf-communicate  
echo fset lx-office-erp/lx-office-erp-user-postgresql-password seen false | debconf-communicate  
echo fset lx-office-erp/lx-office-erp-user-postgresql-password2 seen false | debconf-communicate  
echo fset lx-office-erp/password-empty seen false | debconf-communicate
echo fset lx-office-erp/password-mismatch seen false | debconf-communicate
debconf-show lx-office-erp

