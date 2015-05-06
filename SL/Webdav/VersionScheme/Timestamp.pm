package SL::Webdav::VersionScheme::Timestamp;

use strict;
use parent qw(Rose::Object);

use POSIX ();

sub separator { "_" }

sub extract_regexp { qr/\d{8}_\d{6}/ }

sub cmp { sub { $_[0]->version cmp $_[1]->version } }

sub first_version { goto &get_current_formatted_time }

sub next_version { goto &get_current_formatted_time }

sub keep_last_version {
  0;
}

sub get_current_formatted_time {
  return POSIX::strftime('%Y%m%d_%H%M%S', localtime());
}

1;
