package SL::MenuItem;

use strict;

sub new {
  my ($class, %params) = @_;

  my $obj = bless {}, $class;
  $obj->{fullname} = $params{name};
  my $values       = $params{item};

  $obj->{ACCESS} = delete $values->{ACCESS};
  $obj->{module} = delete $values->{module} || die 'menuitem - need module';
  $obj->{action} = delete $values->{action} || die 'menuitem - need action';

  $obj->{params} = $values;
}

sub ACCESS { $_[0]{ACCESS} }
sub action { $_[0]{action} }
sub module { $_[0]{module} }
sub params { $_[0]{params} }

sub name { $_[0]{name} ||= $_[0]->_init_name }
sub _init_name { my $name = $_[0]{fullname}; $name =~ s/.*--//; $name }
sub path { @{ $_[0]{path} ||= [ $_[0]->_init_path ] } }
sub _init_path { my $name = $_[0]{fullname}; split /--/, $name }

sub children { }
sub siblings {}
sub parent {}


###### internal stuff #######



1;

__END__

=encoding utf-8

=head1 NAME

SL::MenuItem - wrapper class for menu items

=head1 SYNOPSIS

  use SL::Menu;

  for my item (Menu->new->menuitems) {
    next unless $item->access;

    make_your_own_menuentry_from(
      module => $item->module,
      action => $iten->action,
      params => $item->params,
      name   => $item->name,
      path   => $item->path,
      children => $item->children,
      parent => $item->parent,
    );
  }

=head1 DESCRIPTION

This provides some wrapper methods around the raw entries in menu.ini. It sorts through expected information like module and action, wraps access calls for you and gives you tree access to siblings, children and parent elements in the menu structure.

=head1 METHODS

=over 4

=item new

=item access

=item module

=item params

=item name

=item path

=item children

=item parent

=item siblings

=back

=head1 BUGS

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
