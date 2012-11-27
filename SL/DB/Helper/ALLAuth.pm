package SL::DB::Helper::ALLAuth;

use strict;

use SL::DB::AuthGroup;
use SL::DB::AuthGroupRight;
use SL::DB::AuthUserConfig;
use SL::DB::AuthUser;

1;

__END__

=pod

=head1 NAME

SL::DB::Helper::ALLAuth: Dependency-only package for all SL::DB::Auth* modules

=head1 SYNOPSIS

  use SL::DB::Helper::ALLAuth;

=head1 DESCRIPTION

This module depends on all modules in SL/DB/Auth*.pm for the
convenience of being able to write a simple \C<use
SL::DB::Helper::ALLAuth> and having everything loaded. This is
supposed to be used only in the kivitendo console. Normal modules
should C<use> only the modules they actually need.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
