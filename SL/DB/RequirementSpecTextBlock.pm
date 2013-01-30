package SL::DB::RequirementSpecTextBlock;

use strict;

use SL::DB::MetaSetup::RequirementSpecTextBlock;
use SL::DB::Manager::RequirementSpecTextBlock;
# ActsAsList does not support position arguments grouped by other
# columns, e.g. by the requirement_spec_id in this case. So we cannot
# use it yet.
# use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->title;

  return @errors;
}

1;
