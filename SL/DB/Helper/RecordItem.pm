package SL::DB::Helper::RecordItem;

use strict;
use parent qw(Exporter);

our @EXPORT = qw(base_sellprice unit_multiplier);

sub base_sellprice {
  $_[0]->sellprice / $_[0]->unit_multiplier;
}

sub unit_multiplier {
  $_[0]->unit_obj->convert_to(1, $_[0]->part->unit_obj)
}


1;
