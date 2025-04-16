# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::TSETransaction;

use strict;
use MIME::Base64;

use SL::DB::MetaSetup::TSETransaction;
use SL::DB::Manager::TSETransaction;

__PACKAGE__->meta->initialize;

sub decoded_process_data {
  my ($self) = @_;

  return MIME::Base64::decode_base64($self->process_data);
}

sub formatted_start_time {
  _format_timestamp($_[0]->start_timestamp);
}

sub formatted_finish_time {
  _format_timestamp($_[0]->finish_timestamp);
}

sub _format_timestamp {
  $_[0]->iso8601 . "Z";
}

1;
