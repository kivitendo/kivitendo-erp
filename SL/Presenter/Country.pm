package SL::Presenter::Country;

use strict;

use SL::DB::Manager::Country;

use Exporter qw(import);
our @EXPORT_OK = qw(country_picker);

use Carp;
use Data::Dumper;
use SL::Presenter::EscapedText qw(is_escaped);
use SL::Presenter::Tag qw(select_tag);

sub country_picker {
  my ($country, $value, %params) = @_;

  my $text = select_tag($country, SL::DB::Manager::Country->get_all_sorted, value_key => 'id', title_key => 'description', default => $value, %params);
  is_escaped($text);
}

sub picker { goto &country_picker }

1;
