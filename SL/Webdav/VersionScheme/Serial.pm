package SL::Webdav::VersionScheme::Serial;

use strict;
use parent qw(Rose::Object);

use DateTime;

sub separator { "-" }

sub extract_regexp { qr/\d+/ }

sub cmp { sub { $_[0]->version <=> $_[1]->version } }

sub first_version { }

sub next_version { $_[1]->version + 1 }

sub keep_last_version {
  my ($self, $last) = @_;

  if ($::lx_office_conf->{webdav}{new_version_after_minutes}) {
    return DateTime->now <= $last->mtime + DateTime::Duration->new(minutes => $::lx_office_conf{webdav}{new_version_after_minutes});
  } else {
    return 0;
  }
}

1;
