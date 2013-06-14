package Rose::DBx::Cache::Anywhere;
use strict;
use warnings;
use Carp;
use base qw( Rose::DB::Cache );

=head1 NAME

Rose::DBx::Cache::Anywhere - get Apache::DBI behaviour without Apache

=head1 DESCRIPTION

This class is used by Rose::DBx::AutoReconnect.
The author uses
Rose::DB with Catalyst under both the Catalyst dev server and
FastCGI and found that the standard Rose::DB::Cache behaviour
did not work well with those environments.

=head1 METHODS

=head2 prepare_db( I<rose_db>, I<entry> )

Overrides default method to always ping() dbh if not running
under mod_perl.

=cut

sub prepare_db {
    my ( $self, $db, $entry ) = @_;

    if ( Rose::DB::Cache::MOD_PERL_1 || Rose::DB::Cache::MOD_PERL_2 ) {
        return $self->SUPER::prepare_db( $db, $entry );
    }

    if ( !$entry->is_prepared ) {
        if ( $entry->created_during_apache_startup ) {
            if ( $db->has_dbh ) {
                eval { $db->dbh->disconnect };    # will probably fail!
                $db->dbh(undef);
            }

            $entry->created_during_apache_startup(0);
            return;
        }

        # if this a dummy kivitendo dbh, don't try to actually prepare this.
        if ($db->type =~ /KIVITENDO_EMPTY/) {
          return;
        }

        $entry->prepared(1);
    }

    if ( !$db->dbh->ping ) {
        $db->dbh(undef);
    }
}

1;

__END__

=head1 AUTHOR

Peter Karman, C<< <karman at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-rose-dbx-autoreconnect at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Rose-DBx-AutoReconnect>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Rose::DBx::AutoReconnect

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Rose-DBx-AutoReconnect>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Rose-DBx-AutoReconnect>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Rose-DBx-AutoReconnect>

=item * Search CPAN

L<http://search.cpan.org/dist/Rose-DBx-AutoReconnect>

=back

=head1 ACKNOWLEDGEMENTS

The Minnesota Supercomputing Institute C<< http://www.msi.umn.edu/ >>
sponsored the development of this software.

=head1 COPYRIGHT

Copyright 2008 by the Regents of the University of Minnesota.
All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
