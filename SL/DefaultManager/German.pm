package SL::DefaultManager::German;

use strict;
use parent qw(Rose::Object);

# client defaults
sub chart_of_accounts       { 'Germany-DATEV-SKR03EU' }
sub accounting_method       { 'cash' }
sub inventory_system        { 'periodic' }
sub profit_determination    { 'income' }
sub currency                { 'EUR' }
sub precision               { 0.01 }
sub feature_balance         { 1 }
sub feature_datev           { 1 }
sub feature_erfolgsrechnung { 0 }
sub feature_eurechnung      { 1 }
sub feature_ustva           { 1 }

# user defaults
sub numberformat            { '1.000,00' }
sub dateformat              { 'dd.mm.yy' }
sub timeformat              { 'hh:mm' }

# default for login/admin areas
sub country                 { 'DE' }
sub language                { 'de' }

1;
