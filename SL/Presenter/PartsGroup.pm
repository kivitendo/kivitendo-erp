package SL::Presenter::PartsGroup;

use strict;

use SL::DB::PartsGroup;
use SL::Locale::String qw(t8);
use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);

sub partsgroup_breadcrumb {
  my ( $partsgroup ) = @_;
  my $ancestors = $partsgroup->ancestors;
  my @ancestors = map{ $_->partsgroup } @{$ancestors};
  my $breadcrumb = "<span>" . join ('->', @ancestors) . "->" . $partsgroup->partsgroup . "</span>";
  is_escaped($breadcrumb);
}

1;
