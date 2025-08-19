package SL::DB::Helper::DisplayableNamePreferences;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(displayable_name displayable_name_prefs displayable_name_specs specify_displayable_name_prefs);

use Carp;
use List::Util qw(first);

use SL::Helper::UserPreferences::DisplayableName;


my %prefs_specs;
my %prefs;

sub import {
  my ($class, %params) = @_;
  my $importing = caller();

  $params{title} && $params{options}  or croak 'need params title and options';

  $prefs_specs{$importing} = \%params;

  # Don't 'goto' to Exporters import, it would try to parse @params
  __PACKAGE__->export_to_level(1, $class, @EXPORT);
}

sub displayable_name {
  my ($self) = @_;

  my $specs = $self->displayable_name_specs;
  my $prefs = $self->displayable_name_prefs;

  my @names = $prefs->get =~ m{<\%(.+?)\%>}g;
  my $display_string = $prefs->get;
  foreach my $name (@names) {
    my $opt = first { $name eq $_->{name} } @{$specs->{options}};
    next unless $opt;
    my $val         = $opt->{sub}       ? $opt->{sub}($self)
                    : $self->can($name) ? $self->$name // ''
                    : '';
    $display_string =~ s{<\%$name\%>}{$val}g;
  }

  return $display_string;
}

sub displayable_name_prefs {
  my $class_or_self = shift;
  my $class         = ref($class_or_self) || $class_or_self;

  return SL::Helper::UserPreferences::DisplayableName->new(module => $class);
}

sub displayable_name_specs {
  my $class_or_self = shift;
  my $class         = ref($class_or_self) || $class_or_self;

  return $prefs_specs{$class};
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::DisplayableNamePreferences - Mixin for managing displayable
names configured via user preferences

=head1 SYNOPSIS

  # DB object
  package SL::DB::SomeObject;
  use SL::DB::Helper::DisplayableNamePreferences(
    title   => t8('Some Object'),
    options => [ {name => 'some_attribute_1', title => t8('Some Attribute One') },
                 {name => 'some_attribute_2,  title => t8('Some Attribute Two') },

  );

  # Controller using displayable_name
  package SL::Controller::SomeController;
  $obj       = SL::DB::SomeObject->get_first;
  my $output = $obj->displayable_name;

  # Controller configuring a displayable name
  # can get specs to display title and options
  # and the user prefs to read and set them
  my specs = SL::DB::SomeObject->displayable_name_specs;
  my prefs = SL::DB::SomeObject->displayable_name_prefs;


This mixin provides a method C<displayable_name> for the calling module
which returns a string depending on the settings of the
C<UserPreferences> (see also L<SL::Helper::UserPrefernces::DisplayableName>).
The value in the user preferences is scanned for a pattern like
E<lt>%name%E<gt>, which will be replaced by the value of C<$object-E<gt>name>.

=head1 CONFIGURATION

The mixin must be configured on import giving a hash with the following keys
in the C<use> statement. This is stored in the specs an can be used
in a controller setting the preferences to display them.

=over 4

=item C<title>

The (translated) title of the object.

=item C<options>

The C<options> are an array ref of hash refs with the keys C<name>,
C<title> and optionally, C<sub>. The C<name> is the method called to get
the needed information from the object for which the displayable name is
configured, unless C<sub> is defined.  The C<sub> is a function reference
that is called to get the information from the object. This is helpful
if the object has no suitable getter function. The C<title> can be used
to display a (translated) text in a controller setting the preferences.

=back

=head1 CLASS FUNCTIONS

=over 4

=item C<displayable_name_specs>

Returns the specification given on importing this helper. This can be used
in a controller setting the preferences to display the information to the
user.

=item C<displayable_name_prefs>

This returns an instance of the L<SL::Helper::UserPreferences::DisplayableName>
(see there) for the calling class. This can be used to read and set the
preferences.

=back

=head1 INSTANCE FUNCTIONS

=over 4

=item C<displayable_name>

Displays the name of the object depending on the settings in the
user preferences.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
