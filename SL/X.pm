package SL::X;

use strict;
use warnings;

use SL::X::Base;

use Exception::Class (
  'SL::X::FormError'    => {
    isa                 => 'SL::X::Base',
  },
  'SL::X::DBError'      => {
    isa                 => 'SL::X::Base',
    fields              => [ qw(msg db_error) ],
    defaults            => { error_template => [ '%s: %s', qw(msg db_error) ] },
  },
  'SL::X::DBHookError'  => {
    isa                 => 'SL::X::DBError',
    fields              => [ qw(when hook object object_type) ],
    defaults            => { error_template => [ '%s hook \'%s\' for object type \'%s\' failed', qw(when hook object_type object) ] },
  },
  'SL::X::DBRoseError'  => {
    isa                 => 'SL::X::DBError',
    fields              => [ qw(class metaobject object) ],
    defaults            => { error_template => [ '\'%s\' in object of type \'%s\' occurred', qw(db_error class) ] },
  },
  'SL::X::DBUtilsError' => {
    isa                 => 'SL::X::DBError',
  },
  'SL::X::ZUGFeRDValidation' => {
    isa                 => 'SL::X::Base',
  },
  'SL::X::Inventory' => {
    isa                 => 'SL::X::Base',
    fields              => [ qw(msg error) ],
    defaults            => { error_template => [ '%s: %s', qw(msg) ] },
  },
  'SL::X::Inventory::Allocation' => {
    isa                 => 'SL::X::Base',
    fields              => [ qw(msg error) ],
    defaults            => { error_template => [ '%s: %s', qw(msg) ] },
  },
);

1;
