package SL::X;

use strict;
use warnings;

use SL::X::Base;


# note! the default fields "message", "error" and "show_trace" are created by
# Exception::Class if message or error are given, they are used for
# stringification, so don't use them in error_templates
#
use Exception::Class (
  'SL::X::String'    => {
    isa                 => 'SL::X::Base',
    fields              => [ qw(msg) ],
    defaults            => { error_template => [ '%s', qw(msg) ] },
  },
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
    fields              => [ qw(code) ],
  },
  'SL::X::Inventory::Allocation' => {
    isa                 => 'SL::X::Base',
    fields              => [ qw(code) ],
  },
  'SL::X::Inventory::Allocation::MissingQty' => {
    isa                 => 'SL::X::Inventory::Allocation',
    fields              => [ qw(code part_description to_allocate_qty missing_qty) ],
  },
  'SL::X::Inventory::Allocation::Multi' => {
    isa                 => 'SL::X::Inventory::Allocation',
    fields              => [ qw(errors) ],
  },
);

sub user_message {
  my ($exception) = @_;

  return if !ref $exception || !blessed($exception);
  return $exception->msg if $exception->isa('SL::X');
  return $exception->translated if $exception->isa('SL::Locale::String');
  return "$exception";
}

sub stacktrace {
  my ($exception) = @_;

  return $exception if !ref $exception || !blessed($exception);
  return "$exception" if $exception->isa('SL::X');
  return $exception->translated if $exception->isa('SL::Locale::String');
  return "$exception";
}

1;
