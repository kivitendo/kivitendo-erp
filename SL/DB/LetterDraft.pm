package SL::DB::LetterDraft;

use strict;

use SL::DB::Helper::AttrHTML;
use SL::DB::MetaSetup::LetterDraft;

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('body');

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub new_from_letter {
  my ($class, $letter) = @_;

  my $self = $class->new;

  if (!ref $letter) {
    require SL::DB::Draft;
    $letter = SL::DB::Draft->new(id => $letter)->load;
  }

  $self->assign_attributes(map { $_ => $letter->$_ } $letter->meta->columns);

  $self->id(undef);

  $self;
}

1;
