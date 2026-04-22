package SL::Presenter::Contact;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(contact contact_picker);

use Carp;

sub contact {
  my ($contact, %params) = @_;

  return '' unless $contact;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $description = $contact->full_name;
  my $callback    = $params{callback} ?
                      '&callback=' . $::form->escape(delete $params{callback})
                    : '';

  my $text = escape($description);
  if (! delete $params{no_link}) {
    my $href = 'controller.pl?action=Contact/edit'
               . '&id=' . escape($contact->cp_id)
               . $callback;
    $text = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

sub contact_picker {
  my ($name, $value, %params) = @_;

  if ($value && !ref $value) {
    $value    = SL::DB::Manager::Contact->find_by(cp_id => $value);
  }

  my $id = delete($params{id}) || name_to_id($name);

  my @classes = $params{class} ? ($params{class}) : ();
  push @classes, 'contact_autocomplete';

  # If there is no 'onClick' parameter, set it to 'this.select()',
  # so that the user can type directly in the input field
  # to search another customer/vendor.
  if (!grep { m{onclick}i } keys %params) {
    $params{onClick} = 'this.select()';
  }

  my $ret =
    input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => "@classes", type => 'hidden', id => $id,
      'data-contact-picker-data' => JSON::to_json(\%params),
    ) .
    input_tag("", ref $value  ? $value->full_name : '', id => "${id}_name", %params);

  $::request->layout->add_javascripts('kivi.Contact.js');
  $::request->presenter->need_reinit_widgets($id);

  html_tag('span', $ret, class => 'contact_picker');
}

sub picker { goto &contact_picker };

1;
