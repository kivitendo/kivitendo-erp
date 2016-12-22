
package SL::DB::PartClassification;

use strict;

use SL::DB::MetaSetup::PartClassification;
use SL::DB::Manager::PartClassification;

__PACKAGE__->meta->initialize;

# check if the description and abbreviation is present
#
sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')  if !$self->description;
  push @errors, $::locale->text('The abbreviation is missing.') if !$self->abbreviation;

  return @errors;
}



1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::PartClassification

=head1 SYNOPSIS

Additional to the article types "part", "assembly", "service" and "assortement"
the parts classification specifies other ortogonal attributes

=head1 DESCRIPTION

The primary attributes are the rule
of the article as "used_for_sales" or "used_for_purchase".

Additional other attributes may follow

To see this attributes in a short way there are shortcuts of one (or two characters, if needed for compare )
which may be translated in the specified language

The type of the article is also as shortcut available, so this combined type and classification shortcut
is used short as "Type"

English type shortcuts are 'P','A','S'
German  type shortcuts are 'W','E','D'
The can set in the language-files

To get the localized abbreviations you can use L<SL::Presenter::Part> .

=head1 METHODS

=head2 validate

 $self->validate();

check if the description and abbreviation is present


=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.deE<gt>


=cut
