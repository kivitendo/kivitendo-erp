package SL::Controller::TopQuickSearch;

use strict;
use parent qw(SL::Controller::Base);

use SL::ClientJS;
use SL::JSON;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic (
 'scalar --get_set_init' => [ qw(module js) ],
);

my @available_modules = qw(
  SL::Controller::TopQuickSearch::Article
  SL::Controller::TopQuickSearch::Part
  SL::Controller::TopQuickSearch::Service
  SL::Controller::TopQuickSearch::Assembly
  SL::Controller::TopQuickSearch::Contact
  SL::Controller::TopQuickSearch::GLTransaction
);
my %modules_by_name;

sub action_query_autocomplete {
  my ($self) = @_;

  my $hashes = $self->module->query_autocomplete;

  $self->render(\ SL::JSON::to_json($hashes), { layout => 0, type => 'json', process => 0 });
}

sub action_select_autocomplete {
  my ($self) = @_;

  my $redirect_url = $self->module->select_autocomplete;

  $self->js->redirect_to($redirect_url)->render;
}

sub action_do_search {
  my ($self) = @_;

  my $redirect_url = $self->module->do_search;

  if ($redirect_url) {
    $self->js->redirect_to($redirect_url)
  }

  $self->js->render;
}

sub available_modules {
  my ($self) = @_;

  $self->require_modules;

  map { $_->new } @available_modules;
}

sub active_modules {
  grep {
    $::auth->assert($_->auth, 1)
  } $_[0]->available_modules
}

sub init_module {
  my ($self) = @_;

  $self->require_modules;

  die t8('Need module') unless $::form->{module};

  $::lxdebug->dump(0,  "modules", \%modules_by_name);

  die t8('Unknown module #1', $::form->{module}) unless my $class = $modules_by_name{$::form->{module}};

  $::lxdebug->dump(0,  "auth:", $class->auth);

  $::auth->assert($class->auth);

  return $class->new;
}

sub init_js {
  SL::ClientJS->new(controller => $_[0])
}

sub require_modules {
  my ($self) = @_;

  if (!$self->{__modules_required}) {
    for my $class (@available_modules) {
      eval "require $class" or die $@;
      $modules_by_name{ $class->name } = $class;
    }
    $self->{__modules_required} = 1;
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::TopQuickSearch - Framework for pluggable quicksearch fields in the layout top header.

=head1 SYNOPSIS

use SL::Controller::TopQuickSearch;
my $search = SL::Controller::TopQuickSearch->new;

# in layout
[%- FOREACH module = search.available_modules %]
<input type='text' id='top-search-[% module.name %]'>
[%- END %]

=head1 DESCRIPTION

This controller provides abstraction for different search plugins, and ensures
that all follow a common useability scheme.

Modules should be configurable, but currently are not. Diabling modules can be
done by removing them from available_modules.

=head1 BEHAVIOUR REQUIREMENTS

=over 4

=item *

A single text input field with the html5 placeholder containing a small
description of the target will be rendered from the plugin information.

=item *

On typing, the autocompletion must be enabled.

=item *

On C<Enter>, the search should redirect to an appropriate listing of matching
results.

If only one item matches the result, the plugin should instead redirect
directly to the matched item.

=item *

Search terms should accept the broadest possible matching, and if possible with
C<multi> parsing.

=item *

In case nothing is found, a visual indicator should be given, but no actual
redirect should occur.

=item *

Each search must check rights and must not present a backdoor into data that
the user should not see.

=back

=head1 INTERFACE

Plugins need to provide:

 - name
 - localized description for config
 - localized description for textfield
 - autocomplete callback
 - redirect callback

the frontend will only generate urls of the forms:
  action=TopQuickSearch/autocomplete&module=<module>&term=<term>
  action=TopQuickSearch/search&module=<module>&term=<term>

=head1 TODO

 - filter available searches with auth
 - toggling with cofiguration doesn't work yet

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
