package SL::DB::EmailJournal;

use strict;

use SL::DB::MetaSetup::EmailJournal;
use SL::DB::Manager::EmailJournal;
use SL::DB::Helper::AttrSorted;

__PACKAGE__->meta->add_relationship(
  attachments  => {
    type       => 'one to many',
    class      => 'SL::DB::EmailJournalAttachment',
    column_map => { id => 'email_journal_id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_sorted('attachments');

sub compare_to {
  my ($self, $other) = @_;

  return -1 if  $self->sent_on && !$other->sent_on;
  return  1 if !$self->sent_on &&  $other->sent_on;

  my $result = 0;
  $result    = $other->sent_on <=> $self->sent_on;
  return $result || ($self->id <=> $other->id);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::EmailJournal - RDBO model for email journal

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 METHODS

=over 4

=item C<compare_to $self, $other>

Compares C<$self> with C<$other> and returns the newer entry.

=back

=cut

