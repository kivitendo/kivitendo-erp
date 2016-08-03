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

sub is_sales {
  die 'not an accessor' if @_ > 1;
  $_[0]{customer_id} * 1;
}

sub has_customer_vendor {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  return $self->is_sales
    ? ($self->customer_id && $self->customer)
    : ($self->vendor_id   && $self->vendor);
}

sub customer_vendor {
  die 'not an accessor' if @_ > 1;
  $_[0]->is_sales ? $_[0]->customer : $_[0]->vendor;
}

sub customer_vendor_id {
  die 'not an accessor' if @_ > 1;
  $_[0]->customer_id || $_[0]->vendor_id;
}

1;
