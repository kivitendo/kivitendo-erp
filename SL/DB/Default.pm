package SL::DB::Default;

use strict;

use SL::DB::MetaSetup::Default;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub get_default_currency {
  my $self = _selfify(@_);
  my @currencies = grep { $_ } split(/:/, $self->curr || '');
  return $currencies[0] || '';
}

sub _selfify {
  my ($class_or_self) = @_;
  return $class_or_self if ref($class_or_self);
  return SL::DB::Manager::Default->get_all(limit => 1)->[0];
}

1;
