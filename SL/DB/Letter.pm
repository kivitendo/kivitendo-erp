# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Letter;

use strict;

use SL::DB::MetaSetup::Letter;
use SL::DB::Manager::Letter;

__PACKAGE__->meta->add_relationships(
  customer  => {
    type                   => 'many to one',
    class                  => 'SL::DB::Customer',
    column_map             => { vc_id => 'id' },
  },

);

__PACKAGE__->meta->initialize;

sub new_from_draft {
  my ($class, $draft) = @_;

  my $self = $class->new;

  if (!ref $draft) {
    require SL::DB::LetterDraft;
    $draft = SL::DB::LetterDraft->new(id => $draft)->load;
  }

  $self->assign_attributes(map { $_ => $draft->$_ } $draft->meta->columns);

  $self->id(undef);

  $self;
}

1;
