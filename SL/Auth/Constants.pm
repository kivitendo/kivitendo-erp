package SL::Auth::Constants;

use strict;

use Exporter qw(import);

our %EXPORT_TAGS   = (
  OK => [ qw(
    OK
  ) ],
  ERR => [ qw(
    ERR_PASSWORD
    ERR_BACKEND
    ERR_USER
  ) ],
  SESSION => [ qw(
    SESSION_OK
    SESSION_NONE
    SESSION_EXPIRED
  ) ],
);

# add all the other ":class" tags to the ":all" class,
# deleting duplicates
{
 my %seen;
 push @{$EXPORT_TAGS{all}}, grep {!$seen{$_}++} @$_ for values %EXPORT_TAGS;
}

Exporter::export_ok_tags('all');

use constant OK              =>   0;
use constant ERR_PASSWORD    =>   1;
use constant ERR_USER        =>   2;
use constant ERR_BACKEND     => 100;

use constant SESSION_OK      =>   0;
use constant SESSION_NONE    =>   1;
use constant SESSION_EXPIRED =>   2;

1;

__END__

=encoding utf8

=head1 NAME

SL::Auth::Constants - COnstants for Auth module

=head1 SYNOPSIS

  use SL::Auth::Constants qw(:all);

  OK == $auth->authenticate($user, $pass) or die;

=head1 DESCRIPTION

This module provides status constants for authentication handling

=head1 BUGS

none yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
