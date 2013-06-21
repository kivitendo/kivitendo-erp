package SL::DB::Printer;

use strict;

use SL::DB::MetaSetup::Printer;
use SL::DB::Manager::Printer;
use SL::DB::Helper::Util;

__PACKAGE__->meta->initialize;

sub description {
  goto &printer_description;
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')    if !$self->printer_description;
  push @errors, $::locale->text('The command is missing.')        if !$self->printer_command;
  push @errors, $::locale->text('The description is not unique.') if !SL::DB::Helper::Util::is_unique($self, 'printer_description');

  return @errors;
}

1;
