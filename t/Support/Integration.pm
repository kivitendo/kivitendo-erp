package Support::Integration;

use strict;
use Exporter qw(import);
use HTML::Query;

our @EXPORT = qw(make_request form_from_html);

package MockDispatcher {
  sub end_request { die "END_OF_MOCK_REQUEST" }
};

sub setup {
  no warnings 'once';
  $::dispatcher = bless { }, "MockDispatcher";
}

sub make_request {
  my ($controller, $action, %form_vars) = @_;

  my ($out, $err, @ret);

  package main {
    local $SIG{__WARN__} = sub {
      # ignore spurious warnings, TAP::Harness calls this warnings enabled
    };

    open(my $out_fh, '>', \$out) or die;
    open(my $err_fh, '>', \$err) or die;

    local *STDOUT = $out_fh;
    local *STDERR = $err_fh;

    local $::form = Form->new;
    $::form->{$_} = $form_vars{$_} for keys %form_vars;

    no strict "refs";
    eval {
      if ($controller =~ /^[a-z]/) {
        $::form->{script} = $controller.'.pl'; # usually set by dispatcher, needed for checks in update_exchangerate
        local $ENV{REQUEST_URI} = "http://localhost/$controller.pl"; # needed for Form::redirect_header
        require "bin/mozilla/$controller.pl";
        no warnings;
        @ret = &{ "::$action" }();
      } else {
        require "SL/Controller/$controller.pm";
        no warnings;
        @ret = "SL::Controller::$controller"->new->_run_action($action);
      }
      1;
    } or do { my $err = $@;
      die unless $err =~ /^END_OF_MOCK_REQUEST/;
      @ret = (1);
    }
  }
  return ($out, $err, @ret);
}

sub form_from_html {
  my ($html, $form_selector) = @_;
  $form_selector //= '#form';

  my $q = HTML::Query->new(text => $html);

  my %form;
  for my $input ($q->query("$form_selector input")->get_elements()) {
    next if !$input->attr('name') || $input->attr('disabled');
    $form{ $input->attr('name') } = $input->attr('value') // "";
  }
  for my $select ($q->query("$form_selector select")->get_elements()) {
    my $name = $select->attr('name');
    my ($selected_option) = (
      grep({ $_->tag eq 'option' && $_->attr('selected') } $select->content_list),
      grep({ $_->tag eq 'option' } $select->content_list)
    );

    $form{ $name } = $selected_option->attr('value') // $selected_option->as_text
      if $selected_option;
  }

  %form;
}

1;

__END__

=encoding utf-8

=head1 NAME

Support::Integration - helper for simple frontend integration tests

=head1 SYNOPSIS

  # in tests
  use Support::Integration qw(:all);

  # before making any requests, setup mock dispatcher
  Support::Integration::setup();
  Support::TestSetup::login();

  # then do a simple request: ar.pl?action=add&type=invoice
  # returns the generated outputs and return values
  # exceptions are bubbled through
  my ($stdout, $strderr, @ret) = make_request('ar', 'add', type => 'invoice');

  # generate form contents from html for the given form selector (defaults to '#form')
  my %form = form_from_html($stdout, '#form');

  # add values the user would enter
  $form{partnumber} = "Part 1";

  # there is no javascript emulation so you need to set ids like a picker would
  $form{customer_id} = 14392;

  # and do request again
  ($stdout, $stderr, @ret) = make_request('ar', 'update', %form);

  # also works with new controllers
  ($stdout, $stderr, @ret) = make_request('Part', 'new', %form);

=head1 DESCRIPTION

This is intended as a simple way of testing user centric journeys spanning
multiple requests.

See synopsis for the intended usage. C<make_request> emulates most of the
usual dispatching and routing and simply returns the html output of the action.
C<form_from_html> extracts what would be submitted from a <form> element in the
html.

=head1 FUNCTIONS

=over 4

=item * setup

Reigsters a mock dispatcher global so that C<$::dispatcher->end_request> works.
Needs to be called before using L</make_request>

=item * make_request CONTROLLER, ACTION, [ FORM_KEY => FORM_VALUE, .... ]

Emulates a request. Supported are both old-style and new-style controllers.
Since the routing code does not distinguish between verbs (GET/POST), this doesn't either.

Returns stdout, stderr and the return values of the action.

Exceptions are bubbled as is, with the exception of the graceful end_request.

=item * form_from_html HTML_STRING, [ FORM_SELECTOR ]

Parses the given html string into a dom, finds all inputs
and selects within the given form selector
and extracts their key values into a return hash.

If ommited, form selector defaults to C<#form>.

See L</CAVEATS> for limitations.

=back

=head1 CAVEATS

=over 4

=item * No authentication

This is not intended to emulate the login process. It is expected that
C<Support::TestSetup::login()> is called for any Requests that require user access.

=item * No Javascript emulation

This means: no pickers, no auto format, no auto update on change.
No dynamic content like added rows or autocompletion.

=item * Form extraction is stupid

This simply gets all non-disabled inputs and selects within a form selector.
The order of elements is strictly DOM order, which is important for checkbox_for_submit
and ParseFilter serialization.

=item * No network round-trips

Requests will be emulated within the same process without a network roundtrip.
This is not for full black box system tests.

=item * Warnings are suppressed

Test::Harness will sometimes enable warnings for all code, which then pollutes
stderr. so warnings are suppressed for make_request.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
