package SL::Presenter;

use strict;

use parent qw(Rose::Object);

use Carp;
use Template;
use List::Util qw(first);

use SL::Presenter::EscapedText qw(is_escaped);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(need_reinit_widgets) ],
);

sub get {
  return $::request->presenter;
}

sub render {
  my $self               = shift;
  my $template           = shift;
  my ($options, %locals) = (@_ && ref($_[0])) ? @_ : ({ }, @_);

  # Set defaults for all available options.
  my %defaults = (
    type       => 'html',
    process    => 1,
  );
  $options->{$_} //= $defaults{$_} for keys %defaults;
  $options->{type} = lc $options->{type};

  # Check supplied options for validity.
  foreach (keys %{ $options }) {
    croak "Unsupported option: $_" unless $defaults{$_};
  }

  # Only certain types are supported.
  croak "Unsupported type: " . $options->{type} unless $options->{type} =~ m/^(?:html|js|json|text)$/;

  # The "template" argument must be a string or a reference to one.
  $template = ${ $template }                                       if ((ref($template) || '') eq 'REF') && (ref(${ $template }) eq 'SL::Presenter::EscapedText');
  croak "Unsupported 'template' reference type: " . ref($template) if ref($template) && (ref($template) !~ m/^(?:SCALAR|SL::Presenter::EscapedText)$/);

  # Look for the file given by $template if $template is not a reference.
  my $source = resolve_template($template, $options->{type});

  # If no processing is requested then return the content.
  if (!$options->{process}) {
    # If $template is a reference then don't try to read a file.
    my $ref = ref $template;
    return $template                  if $ref eq 'SL::Presenter::EscapedText';
    return is_escaped(${ $template }) if $ref eq 'SCALAR';

    # Otherwise return the file's content.
    my $file    = IO::File->new($source, "r") || croak("Template file ${source} could not be read");
    my $content = do { local $/ = ''; <$file> };
    $file->close;

    return is_escaped($content);
  }

  # Processing was requested. Set up all variables.
  my %params = ( %locals,
                 AUTH          => $::auth,
                 FLASH         => $::form->{FLASH},
                 FORM          => $::form,
                 INSTANCE_CONF => $::instance_conf,
                 LOCALE        => $::locale,
                 LXCONFIG      => \%::lx_office_conf,
                 LXDEBUG       => $::lxdebug,
                 MYCONFIG      => \%::myconfig,
                 PRESENTER     => $self,
               );

  my $output;
  my $parser = $self->get_template;
  $parser->process($source, \%params, \$output) || croak $parser->error;

  return is_escaped($output);
}

sub resolve_template {
  my ($template, $type) = @_;
  $type //= 'html';


  my $source;
  if (!ref $template) {
    my $webpages_path     = $::request->layout->webpages_path;
    my $webpages_fallback = $::request->layout->webpages_fallback_path;

    my $ext = $type eq 'text' ? 'txt' : $type;

    $source = first { -f } map { "${_}/${template}.${ext}" } grep { defined } $webpages_path, $webpages_fallback;

    croak "Template file ${template} not found" unless $source;

  } elsif (ref($template) eq 'SCALAR') {
    # Normal scalar reference: hand over to Template
    $source = $template;

  } else {
    # Instance of SL::Presenter::EscapedText. Get reference to its content.
    $source = \$template->{text};
  }

  return $source;
}

sub get_template {
  my ($self) = @_;

  my $webpages_path     = $::request->layout->webpages_path;
  my $webpages_fallback = $::request->layout->webpages_fallback_path;

  my $include_path = join ':', grep defined, $webpages_path, $webpages_fallback;

  # Make locales.pl parse generic/exception.html, too:
  # $::form->parse_html_template("generic/exception")
  $self->{template} ||=
    Template->new({ INTERPOLATE  => 0,
                    EVAL_PERL    => 0,
                    ABSOLUTE     => 1,
                    CACHE_SIZE   => 0,
                    PLUGIN_BASE  => 'SL::Template::Plugin',
                    INCLUDE_PATH => ".:$include_path",
                    COMPILE_EXT  => '.tcc',
                    COMPILE_DIR  => $::lx_office_conf{paths}->{userspath} . '/templates-cache',
                    ERROR        => "${webpages_path}/generic/exception.html",
                    ENCODING     => 'utf8',
                  }) || croak;

  return $self->{template};
}

1;

__END__

=head1 NAME

SL::Presenter - presentation layer class

=head1 SYNOPSIS

  use SL::Presenter;
  my $presenter = SL::Presenter->get;

  # Lower-level template parsing:
  my $html = $presenter->render(
    'presenter/dir/template.html',
    var1 => 'value',
  );

  # Higher-level rendering of certain objects:
  use SL::DB::Customer;

  my $linked_customer_name = $customer->presenter->customer(display => 'table-cell');

  # Render a list of links to sales/purchase records:
  use SL::DB::Order;
  use SL::Presenter::Record qw(grouped_record_list);

  my $quotation = SL::DB::Manager::Order->get_first(
    where => [ or => ['record_type' => 'sales_quotation',
                      'record_type' => 'request_quotation' ]]);
  my $records   = $quotation->linked_records(direction => 'to');
  my $html      = grouped_record_list($records);

=head1 CLASS FUNCTIONS

=over 4

=item C<get>

Returns the global presenter object and creates it if it doesn't exist
already.

=back

=head1 INSTANCE FUNCTIONS

=over 4

=item C<render $template, [ $options, ] %locals>

Renders the template C<$template>. Provides other variables than
C<Form::parse_html_template> does.

C<$options>, if present, must be a hash reference. All remaining
parameters are slurped into C<%locals>.

This is the backend function that L<SL::Controller::Base/render>
calls. The big difference is that the presenter's L<render> function
always returns the input and never sends anything to the browser while
the controller's function usually sends the result to the
controller. Therefore the presenter's L<render> function does not use
all of the parameters for controlling the output that the controller's
function does.

What is rendered and how C<$template> is interpreted is determined
both by C<$template>'s reference type and by the supplied options.

If C<$template> is a normal scalar (not a reference) then it is meant
to be a template file name relative to the C<templates/design40_webpages>
directory. The file name to use is determined by the C<type> option.

If C<$template> is a reference to a scalar then the referenced
scalar's content is used as the content to process. The C<type> option
is not considered in this case.

C<$template> can also be an instance of L<SL::Presenter::EscapedText>
or a reference to such an instance. Both of these cases are handled
the same way as if C<$template> were a reference to a scalar: its
content is processed, and C<type> is not considered.

Other reference types, unknown options and unknown arguments to the
C<type> option cause the function to L<croak>.

The following options are available:

=over 2

=item C<type>

The template type. Can be C<html> (the default), C<js> for JavaScript,
C<json> for JSON and C<text> for plain text content. Affects only the
extension that's added to the file name given with a non-reference
C<$template> argument.

=item C<process>

If trueish (which is also the default) it causes the template/content
to be processed by the Template toolkit. Otherwise the
template/content is returned as-is.

=back

If template processing is requested then the template has access to
the following variables:

=over 2

=item * C<AUTH> -- C<$::auth>

=item * C<FLASH> -- the flash instance (C<$::form-E<gt>{FLASH}>)

=item * C<FORM> -- C<$::form>

=item * C<INSTANCE_CONF> -- C<$::instance_conf>

=item * C<LOCALE> -- C<$::locale>

=item * C<LXCONFIG> -- all parameters from C<config/kivitendo.conf>
with the same name they appear in the file (first level is the
section, second the actual variable, e.g. C<system.language>,
C<features.webdav> etc)

=item * C<LXDEBUG> -- C<$::lxdebug>

=item * C<MYCONFIG> -- C<%::myconfig>

=item * C<SELF> -- the controller instance

=item * C<PRESENTER> -- the presenter instance the template is
rendered with

=item * All items from C<%locals>

=back

The function will always return the output and never send anything to
the browser.

Example: Render a HTML template with a certain title and a few locals

  $presenter->render('todo/list',
                     title      => 'List TODO items',
                     TODO_ITEMS => SL::DB::Manager::Todo->get_all_sorted);

Example: Render a string and return its content for further processing
by the calling function.

  my $content = $presenter->render(\'[% USE JavaScript %][% JavaScript.replace_with("#someid", "js/something") %]');

Example: Return the content of a JSON template file without processing
it at all:

  my $template_content = $presenter->render(
    'customer/contact',
    { type => 'json', process => 0 }
  );

=item C<get_template>

Returns the global instance of L<Template> and creates it if it
doesn't exist already.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
