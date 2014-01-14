package SL::DB::Translation;

use strict;

use SL::DB::MetaSetup::Translation;
use SL::DB::Helper::AttrHTML;

__PACKAGE__->meta->initialize;

__PACKAGE__->meta->make_manager_class;

__PACKAGE__->attr_html('longdescription');

1;
