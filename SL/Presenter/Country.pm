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

  my $title_key = 'description_'.$::myconfig{countrycode};

  my $text = select_tag($country, SL::DB::Manager::Country->get_all_sorted, value_key => 'id', title_key => $title_key, default => $value, %params);
  is_escaped($text);
}

sub picker { goto &country_picker }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Presenter::Country - Countries related presenter

=head1 DESCRIPTION

see L<SL::Presenter>

=head1 FUNCTIONS

=over 2

=item C<picker $object, %params>

Returns a rendered HTML select tag to choose one country from the
collection of all available L<SL::DB::Country> objects.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::select_tag>.

=back

=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
