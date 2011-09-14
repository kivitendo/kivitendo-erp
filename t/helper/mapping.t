use Test::More tests => 2;

use_ok 'SL::DB::Helper::ALL';
use_ok 'SL::DB::Helper::Mappings';

__END__

is db('part'), 'SL::DB::Part';
is db('parts'), 'SL::DB::Manager::Part';

is db('order'), 'SL::DB::Order';
is db('orders'), 'SL::DB::Manager::Order';

is db('gl'), 'SL::DB::GLTransaction';
is db('gls'), 'SL::DB::Manager::GLTransaction';

is db('ar'), 'SL::DB::Invoice';
is db('ars'), 'SL::DB::Manager::Invoice';

is db('Unit'), 'SL::DB::Unit';
is db('Units'), 'SL::DB::Manager::Unit';
