package SL::DB::BackgroundJobHistory;

use strict;

use SL::DB::MetaSetup::BackgroundJobHistory;
use SL::DB::Manager::BackgroundJobHistory;

__PACKAGE__->meta->initialize;

use constant SUCCESS => 'success';
use constant FAILURE => 'failure';

sub has_succeeded { $_[0] && (($_[0]->status || '') eq SUCCESS()) }
sub has_failed    { $_[0] && (($_[0]->status || '') eq FAILURE()) }

1;
