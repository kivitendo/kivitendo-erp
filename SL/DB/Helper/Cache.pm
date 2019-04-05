package SL::DB::Helper::Cache;

use strict;
use warnings;

use Carp;

use parent qw(Rose::DB::Cache);

sub prepare_db {
  my ($self, $db, $entry) = @_;

  if (!$entry->is_prepared) {
    # if this a dummy kivitendo dbh, don't try to actually prepare this.
    if ($db->type =~ /KIVITENDO_EMPTY/) {
      return;
    }

    $entry->prepared(1);
  }

  if (!$db->dbh->ping) {
    $db->dbh(undef);
  }
}

1;

__END__

=head1 NAME

SL::DB::Helper::Cache - database handle caching for kivitendo

=head1 DESCRIPTION

This class provides database cache handling for kivitendo running
under FastCGI. It's based on Rose::DBx::Cache::Anywhere.

=head1 METHODS

=head2 prepare_db( I<rose_db>, I<entry> )

Overrides default method to always ping() dbh.
