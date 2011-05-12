package SL::X;

use strict;

use Exception::Lite qw(declareExceptionClass);

declareExceptionClass('SL::X::FormError');
declareExceptionClass('SL::X::DBHookError');

1;
