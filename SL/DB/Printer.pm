package SL::DB::Printer;

use strict;

use SL::DB::MetaSetup::Printer;

__PACKAGE__->meta->make_manager_class;

sub description {
  goto &printer_description;
}

1;
