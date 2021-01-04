package SL::Controller::TopQuickSearch;

use strict;
use parent qw(SL::Controller::Base);

use SL::ClientJS;
use SL::JSON;
use SL::Locale::String qw(t8);
use SL::Helper::UserPreferences;

use Rose::Object::MakeMethods::Generic (
 'scalar --get_set_init' => [ qw(module js) ],
);

my @available_modules = (
  'SL::Controller::TopQuickSearch::Article',
  'SL::Controller::TopQuickSearch::Part',
  'SL::Controller::TopQuickSearch::Service',
  'SL::Controller::TopQuickSearch::Assembly',
  'SL::Controller::TopQuickSearch::Assortment',
  'SL::Controller::TopQuickSearch::Contact',
  'SL::Controller::TopQuickSearch::SalesQuotation',
  'SL::Controller::TopQuickSearch::SalesOrder',
  'SL::Controller::TopQuickSearch::SalesDeliveryOrder',
  'SL::Controller::TopQuickSearch::RequestForQuotation',
  'SL::Controller::TopQuickSearch::PurchaseOrder',
  'SL::Controller::TopQuickSearch::PurchaseDeliveryOrder',
  'SL::Controller::TopQuickSearch::GLTransaction',
  'SL::Controller::TopQuickSearch::Customer',
  'SL::Controller::TopQuickSearch::Vendor',
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

sub enabled_modules {
  my $user_prefs = SL::Helper::UserPreferences->new(
    namespace         => 'TopQuickSearch',
  );

  my @quick_search_modules;
  if (my $prefs_val = $user_prefs->get('quick_search_modules')) {
    @quick_search_modules = split ',', $prefs_val;
  } else {
    @quick_search_modules = @{ $::instance_conf->get_quick_search_modules };
  }

  my %enabled_names = map { $_ => 1 } @quick_search_modules;

  grep {
    $enabled_names{$_->name}
  } $_[0]->available_modules
}

sub active_modules {
  grep {
    !$_->auth || $::auth->assert($_->auth, 1)
  } $_[0]->enabled_modules
}

sub init_module {
  my ($self) = @_;

  $self->require_modules;

  die 'Need module' unless $::form->{module};

  die 'Unknown module ' . $::form->{module} unless my $class = $modules_by_name{$::form->{module}};

  $::auth->assert($class->auth) if $class->auth;

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
  $::request->layout->add_javascripts('kivi.QuickSearch.js');

  # in template
  [%- FOREACH module = search.enabled_modules %]
  <input type='text' id='top-search-[% module.name %]'>
  [%- END %]

=head1 DESCRIPTION

This controller provides abstraction for different search plugins, and ensures
that all follow a common useability scheme.

Modules should be configurable per user, but currently are not. Disabling
modules can be done by removing them from available_modules or in client_config.

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

=item *

By design the search must not try to guess C<exact matches>.

=back

=head1 INTERFACE

The full interface is described in L<SL::Controller::TopQuickSeach::Base>

=head1 TODO

  * user configuration

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
