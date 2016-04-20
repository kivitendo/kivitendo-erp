package SL::DB::Letter;

use strict;

use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::LinkedRecords;
use SL::DB::MetaSetup::Letter;
use SL::DB::Manager::Letter;

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('body');

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
