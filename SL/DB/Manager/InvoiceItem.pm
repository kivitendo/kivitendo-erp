package SL::DB::Manager::InvoiceItem;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::InvoiceItem' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( columns => { position => [ 'trans_id', 'position' ], },
           default => [ 'position', 1 ],
           nulls   => { }
         );
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::InvoiceItem - Manager for models for the
'invoice' table

=head1 SYNOPSIS

This is a standard Rose::DB::Manager based model manager and can be
used as such.

=head1 FUNCTIONS

None yet.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
