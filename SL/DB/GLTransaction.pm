package SL::DB::GLTransaction;

use strict;

use SL::DB::MetaSetup::GLTransaction;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub abbreviation {
  my $self = shift;

  my $abbreviation = $::locale->text('GL Transaction (abbreviation)');
  $abbreviation   .= "(" . $::locale->text('Storno (one letter abbreviation)') . ")" if $self->storno;
  return $abbreviation;

}

1;
