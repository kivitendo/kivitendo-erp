package SL::DB::RequirementSpecTextBlock;

use strict;

use SL::DB::MetaSetup::RequirementSpecTextBlock;
# ActsAsList does not support position arguments grouped by other
# columns, e.g. by the requirement_spec_id in this case. So we cannot
# use it yet.
# use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->title;

  return @errors;
}

1;
