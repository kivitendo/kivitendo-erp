package SL::X;

use strict;

use Exception::Lite qw(declareExceptionClass);

declareExceptionClass('SL::X::FormError');
declareExceptionClass('SL::X::DBHookError', [ '%s hook \'%s\' failed', qw(when hook object) ]);

1;
