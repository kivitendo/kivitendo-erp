package SL::X;

use strict;

use Exception::Lite qw(declareExceptionClass);

declareExceptionClass('SL::X::FormError');
declareExceptionClass('SL::X::DBError',                        [ '%s %s', qw(error msg) ]);
declareExceptionClass('SL::X::DBHookError',  'SL::X::DBError', [ '%s hook \'%s\' for object type \'%s\' failed', qw(when hook object_type object) ]);
declareExceptionClass('SL::X::DBRoseError',  'SL::X::DBError', [ '\'%s\' in object of type \'%s\' occured', qw(error class) ]);
declareExceptionClass('SL::X::DBUtilsError', 'SL::X::DBError', [ '%s: %s', qw(msg error) ]);

1;
