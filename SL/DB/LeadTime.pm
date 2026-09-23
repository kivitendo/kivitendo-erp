# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::LeadTime;

use strict;

use SL::DB::MetaSetup::LeadTime;
use SL::DB::Manager::LeadTime;
use SL::DB::Helper::ActsAsList (column_name => 'sortkey');
use SL::DB::Helper::TranslatedAttributes;

__PACKAGE__->meta->initialize;
__PACKAGE__->before_delete('can_be_deleted');

sub can_be_deleted {
  my ($self) = @_;

  return 1 unless $self->id;

  require SL::DB::Order;

  return 0 == SL::DB::Manager::Order->get_all_count(query => [ lead_time_id => $self->id ])
}

sub save_translations {
  my ($self, $all_translations) = @_;

  $self->save() unless $self->id;

  foreach my $pair (@$all_translations) {
    my $language    = $pair->{language};
    my $translation = $pair->{translation};
    $self->save_attribute_translation('description_long', $language, $translation);
  }
}

1;
