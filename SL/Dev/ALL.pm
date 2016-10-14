package SL::Dev::ALL;

use strict;

use SL::Dev::Part;
use SL::Dev::CustomerVendor;
use SL::Dev::Inventory;

1;

__END__

=pod

=head1 NAME

SL::Dev::ALL: Dependency-only package for all SL::Dev::* modules

=head1 SYNOPSIS

  use SL::Dev::ALL;

=head1 DESCRIPTION

This module depends on all modules in SL/Dev/*.pm for the convenience of being
able to write a simple C<use SL::Dev::ALL> and having everything loaded. This
is supposed to be used only for test cases or in the kivitendo console. Normal
modules should C<use> only the modules they actually need.

To automatically include it in the console, add a line in the client section of
the kivitendo.config, e.g.

[console]
autorun = require "bin/mozilla/common.pl";
        = use SL::DB::Helper::ALL;
        = use SL::Dev::ALL;

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
