package SL::Presenter::Tag;

use strict;

use SL::HTML::Restrict;
use SL::Locale::String qw(t8);
use SL::Presenter::EscapedText qw(escape);
use Scalar::Util qw(blessed);

use Exporter qw(import);
our @EXPORT_OK = qw(
  html_tag input_tag hidden_tag javascript man_days_tag name_to_id select_tag
  checkbox_tag button_tag submit_tag ajax_submit_tag input_number_tag
  stringify_attributes textarea_tag link_tag date_tag
  div_tag radio_button_tag img_tag multi_level_select_tag input_tag_trim
  input_email_tag context_help_tag);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use Carp;

my %_valueless_attributes = map { $_ => 1 } qw(
  checked compact declare defer disabled ismap multiple noresize noshade nowrap
  readonly selected hidden
);

my %_singleton_tags = map { $_ => 1 } qw(
  area base br col command embed hr img input keygen link meta param source
  track wbr
);

sub _call_on {
  my ($object, $method, @params) = @_;
  return $object->$method(@params);
}

{ # This will give you an id for identifying html tags and such.
  # It's guaranteed to be unique unless you exceed 10 mio calls per request.
  # Do not use these id's to store information across requests.
my $_id_sequence = int rand 1e7;
sub _id {
  return ( $_id_sequence = ($_id_sequence + 1) % 1e7 );
}
}

sub _J {
  my $string = shift;
  $string    =~ s/(\"|\'|\\)/\\$1/g;
  return $string;
}

sub join_values {
  my ($name, $value) = @_;
  my $spacer = $name eq 'class' ? ' ' : ''; # join classes with spaces, everything else as is

  ref $value && 'ARRAY' eq ref $value
  ? join $spacer, map { join_values($name, $_) } @$value
  : $value
}

sub stringify_attributes {
  my (%params) = @_;

  my @result = ();
  while (my ($name, $value) = each %params) {
    next unless $name;
    next if $_valueless_attributes{$name} && !$value;
    $value = '' if !defined($value);
    $value = join_values($name, $value) if ref $value && 'ARRAY' eq ref $value;
    push @result, $_valueless_attributes{$name} ? escape($name) : escape($name) . '="' . escape($value) . '"';
  }

  return @result ? ' ' . join(' ', @result) : '';
}

sub html_tag {
  my ($tag, $content, %params) = @_;
  my $attributes = stringify_attributes(%params);

  return "<${tag}${attributes}>" if !defined($content) && $_singleton_tags{$tag};
  return "<${tag}${attributes}>${content}</${tag}>";
}

sub input_tag {
  my ($name, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $name);
  $attributes{type} ||= 'text';

  html_tag('input', undef, %attributes, name => $name, value => $value);
}

sub input_tag_trim {
  my ($name, $value, %attributes) = @_;
  $attributes{'data-validate'} .= ' trimmed_whitespaces';

  _set_id_attribute(\%attributes, $name);
  $::request->layout->add_javascripts('kivi.Validator.js');
  $::request->presenter->need_reinit_widgets($attributes{id});

  input_tag($name, $value, %attributes);
}

sub hidden_tag {
  my ($name, $value, %attributes) = @_;
  input_tag($name, $value, %attributes, type => 'hidden');
}

sub man_days_tag {
  my ($name, $object, %attributes) = @_;

  my $size           =  delete($attributes{size})   || 5;
  my $method         =  $name;
  $method            =~ s/^.*\.//;

  my $time_selection = input_tag("${name}_as_man_days_string", _call_on($object, "${method}_as_man_days_string"), %attributes, size => $size);
  my $unit_selection = select_tag("${name}_as_man_days_unit",   [[ 'h', $::locale->text('h') ], [ 'man_day', $::locale->text('MD') ]],
                                          %attributes, default => _call_on($object, "${method}_as_man_days_unit"));

  return $time_selection . $unit_selection;
}

sub name_to_id {
  my ($name) = @_;

  $name =~ s/\[\+?\]/ _id() /ge; # give constructs with [] or [+] unique ids
  $name =~ s/[^\w_]/_/g;
  $name =~ s/_+/_/g;

  return $name;
}

sub select_tag {
  my ($name, $collection, %attributes) = @_;

  _set_id_attribute(\%attributes, $name);

  $collection         = [] if defined($collection) && !ref($collection) && ($collection eq '');

  my $with_filter     = delete($attributes{with_filter});
  my $fil_placeholder = delete($attributes{filter_placeholder});
  my $value_key       = delete($attributes{value_key})   || 'id';
  my $title_key       = delete($attributes{title_key})   || $value_key;
  my $default_key     = delete($attributes{default_key}) || 'selected';
  my $default_val_key = delete($attributes{default_value_key});
  my $default_coll    = delete($attributes{default});

  my $value_title_sub = delete($attributes{value_title_sub});

  my $value_sub       = delete($attributes{value_sub});
  my $title_sub       = delete($attributes{title_sub});
  my $default_sub     = delete($attributes{default_sub});

  my $with_empty      = delete($attributes{with_empty});
  my $empty_title     = delete($attributes{empty_title});

  my $with_optgroups  = delete($attributes{with_optgroups});

  undef $default_key if $default_sub || $default_val_key;

  my $normalize_entry = sub {
    my ($type, $entry, $sub, $key) = @_;

    return $sub->($entry) if $sub;

    my $ref = ref($entry);

    if ( !$ref ) {
      return $entry if $type eq 'value' || $type eq 'title';
      return 0;
    }

    if ( $ref eq 'ARRAY' ) {
      return $entry->[ $type eq 'value' ? 0 : $type eq 'title' ? 1 : 2 ];
    }

    return $entry->{$key} if $ref  eq 'HASH';
    return $entry->$key   if $type ne 'default' || $entry->can($key);
    return undef;
  };

  my %selected;
  if (defined($default_coll) && !ref $default_coll) {
    %selected = ($default_coll => 1);

  } elsif (ref($default_coll) eq 'HASH') {
    %selected = %{ $default_coll };

  } elsif ($default_coll) {
    $default_coll = [ $default_coll ] unless 'ARRAY' eq ref $default_coll;

    %selected = $default_val_key ? map({ ($normalize_entry->('value', $_, undef, $default_val_key) => 1) } @{ $default_coll })
              :                    map({ ($_                                                       => 1) } @{ $default_coll });
  }

  my $list_to_code = sub {
    my ($sub_collection) = @_;

    if ('ARRAY' ne ref $sub_collection) {
      $sub_collection = [ $sub_collection ];
    }

    my @options;
    foreach my $entry ( @{ $sub_collection } ) {
      my $value;
      my $title;

      if ( $value_title_sub ) {
        ($value, $title) = @{ $value_title_sub->($entry) };
      } else {

        $value = $normalize_entry->('value', $entry, $value_sub, $value_key);
        $title = $normalize_entry->('title', $entry, $title_sub, $title_key);
      }

      my $default = $default_key ? $normalize_entry->('default', $entry, $default_sub, $default_key) : 0;

      push(@options, [$value, $title, $selected{$value} || $default]);
    }

    return join '', map { html_tag('option', escape($_->[1]), value => $_->[0], selected => $_->[2]) } @options;
  };

  my $code  = '';
  $code    .= html_tag('option', escape($empty_title || ''), value => '') if $with_empty;

  if (!$with_optgroups) {
    $code .= $list_to_code->($collection);

  } else {
    $code .= join '', map {
      my ($optgroup_title, $sub_collection) = @{ $_ };
      html_tag('optgroup', $list_to_code->($sub_collection), label => $optgroup_title)
    } @{ $collection };
  }

  my $select_html = html_tag('select', $code, %attributes, name => $name);

  if ($with_filter) {
    my $input_style;

    if (($attributes{style} // '') =~ m{width: *(\d+) *px}i) {
      $input_style = "width: " . ($1 - 22) . "px";
    }

    my $input_html = html_tag(
      'input', undef,
      autocomplete     => 'off',
      type             => 'text',
      id               => $attributes{id} . '_filter',
      'data-select-id' => $attributes{id},
      (placeholder     => $fil_placeholder) x !!$fil_placeholder,
      (style           => $input_style)     x !!$input_style,
    );
    $select_html = html_tag('div', $input_html . $select_html, class => "filtered_select");
  }

  return $select_html;
}

sub multi_level_select_tag {
  my ($name, $collection, $levels, %attributes) = @_;

  _set_id_attribute(\%attributes, $name);
  my $id = $attributes{id};

  $collection = [] if defined($collection) && !ref($collection) && ($collection eq '');

  my $surround_tag = delete($attributes{surround_tag});

  my $multi_level_select_tag = "";
  my %level_keys = ();

  my $base_attributes  = delete($attributes{"level_1"}) || {};

  my $base_name        = delete($base_attributes->{name});
  my $base_value_key   = $base_attributes->{value_key} || 'id';
  my $base_title_key   = $base_attributes->{title_key} || $base_value_key;
  my $base_default     = $base_attributes->{default};
  my $base_default_key = $base_attributes->{default_key};

  $level_keys{1} = {
    "value" => $base_value_key,
    "title" => $base_title_key,
  };
  $base_attributes->{id} = $id . "_level_1";
  $base_attributes->{onchange} = $id . "_on_chanche_level_1(this)";
  my $current_select = select_tag(
    $base_name,
    $collection,
    %{$base_attributes}
  );
  if ($surround_tag) {
    $multi_level_select_tag .= html_tag($surround_tag, $current_select);
  } else {
    $multi_level_select_tag .= $current_select;
  }

  my $last_object;
  if ($base_default) {
    ($last_object) = grep { $_->{$base_value_key} eq $base_default } @{$collection};
  } elsif ($base_default_key) {
    ($last_object) = grep { $_->{$base_default_key} } @{$collection};
  } else {
    $last_object = $collection->[0];
  }
  foreach my $level (2 .. $levels) {
    my $current_attributes = delete($attributes{"level_$level"}) || {};

    my $current_name          = delete($current_attributes->{name});
    my $current_value_key     = $current_attributes->{value_key} || 'id';
    my $current_title_key     = $current_attributes->{title_key} || $current_value_key;
    my $current_default       = $current_attributes->{default};
    my $current_default_key   = $current_attributes->{default_key};
    my $current_object_key    = delete($current_attributes->{object_key});
    die "need object_key in level_$level in multi_level_select_tag" unless $current_object_key;

    $level_keys{$level} = {
      "value"  => $current_value_key,
      "title"  => $current_title_key,
      "object" => $current_object_key,
    };

    $current_attributes->{id} = $id . "_level_$level";
    $current_attributes->{onchange} = $id . "_on_chanche_level_${level}(this)" unless $level eq $levels;
    my $current_collection = $last_object->{$current_object_key};
    my $current_select = select_tag(
      $current_name,
      $current_collection,
      %{$current_attributes}
    );
    if ($surround_tag) {
      $multi_level_select_tag .= html_tag($surround_tag, $current_select);
    } else {
      $multi_level_select_tag .= $current_select;
    }

    if ($current_default) {
      ($last_object) = grep { $_->{$current_value_key} eq $current_default } @{$current_collection};
    } elsif ($current_default_key) {
      ($last_object) = grep { $_->{$current_default_key} } @{$current_collection};
    } else {
      $last_object = $current_collection->[0];
    }
  }

  my $code = "";

  if ($levels > 1) {
    my $js_option_string = ""; # js hash map (level->value->{[value: 1, title: 'foo'], ...})

    my @current_collections = @{$collection};
    my @next_collections = ();
    foreach my $level (1 .. ($levels - 1)) {
      $js_option_string .= "'${level}': {";
      foreach my $option (@current_collections) {
        $js_option_string .= "'" . $option->{$level_keys{$level}{value}} . "': [";
        map { $js_option_string .= "{ value: '" . $_->{$level_keys{$level + 1}{value}}
                                .  "', title: '" . $_->{$level_keys{$level + 1}{title}}
                                .  "'}," } @{$option->{$level_keys{$level + 1}{object}}};
        $js_option_string .= "],";
        push @next_collections, @{$option->{$level_keys{$level + 1}{object}}};
      }
      $js_option_string .= "},";
      @current_collections = @next_collections;
      @next_collections = ();
    }

    $code .= javascript( qq|
      var ${id}_options = {
        $js_option_string
      };
    |);
    foreach my $level (1 .. ($levels - 1)) {
      my $next_level = $level + 1;
      $code .= javascript( qq|
      function ${id}_on_chanche_level_${level}(select_${level}) {
        var value = select_${level}.value;
        for (var i = ${next_level}; i < $levels + 1; i++) {
          var id = '${id}_level_' + i;
          var select_i = document.getElementById(id);
          while (select_i.options.length) {
            select_i.options.remove(0);
          }
          select_i.disabled = true;
        }
        var id_${next_level} = '${id}_level_${next_level}';
        var select_${next_level} = document.getElementById(id_${next_level});
        for (var i=0; i < ${id}_options[${level}][value].length; i++) {
          var option = new Option(${id}_options[${level}][value][i].title, ${id}_options[${level}][value][i].value)
          select_${next_level}.options.add(option);
        }
        select_${next_level}.disabled = false;
        select_${next_level}.selectedIndex = -1;
      }
      |);
    }
  }

  return $multi_level_select_tag . $code;
}

sub checkbox_tag {
  my ($name, %attributes) = @_;

  my %label_attributes = map { (substr($_, 6) => $attributes{$_}) } grep { m{^label_} } keys %attributes;
  delete @attributes{grep { m{^label_} } keys %attributes};

  _set_id_attribute(\%attributes, $name);

  $attributes{value}   = 1 unless defined $attributes{value};
  my $label            = delete $attributes{label};
  my $checkall         = delete $attributes{checkall};
  my $for_submit       = delete $attributes{for_submit};

  if ($attributes{checked}) {
    $attributes{checked} = 'checked';
  } else {
    delete $attributes{checked};
  }

  my $code  = '';
  $code    .= hidden_tag($name, 0, %attributes, id => $attributes{id} . '_hidden') if $for_submit;
  $code    .= html_tag('input', undef,  %attributes, name => $name, type => 'checkbox');
  $code    .= html_tag('label', $label, for => $attributes{id}, %label_attributes) if $label;
  $code    .= javascript(qq|\$('#$attributes{id}').checkall('$checkall');|) if $checkall;

  return $code;
}

sub radio_button_tag {
  my ($name, %attributes) = @_;

  my %label_attributes = map { (substr($_, 6) => $attributes{$_}) } grep { m{^label_} } keys %attributes;
  delete @attributes{grep { m{^label_} } keys %attributes};

  $attributes{value}   = 1 unless exists $attributes{value};

  _set_id_attribute(\%attributes, $name, 1);
  my $label            = delete $attributes{label};

  _set_id_attribute(\%attributes, $name . '_' . $attributes{value});

  if ($attributes{checked}) {
    $attributes{checked} = 'checked';
  } else {
    delete $attributes{checked};
  }

  my $code  = html_tag('input', undef,  %attributes, name => $name, type => 'radio');
  $code    .= html_tag('label', $label, for => $attributes{id}, %label_attributes) if $label;

  return $code;
}

sub button_tag {
  my ($onclick, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $attributes{name}) if $attributes{name};
  $attributes{type} ||= 'button';
  $attributes{tag}  ||= 'input';

  $onclick = 'if (!confirm("'. _J(delete($attributes{confirm})) .'")) return false; ' . $onclick if $attributes{confirm};

  if ( $attributes{tag} eq 'input' ) {
    html_tag('input', undef, %attributes, value => $value, (onclick => $onclick)x!!$onclick)
  }
  elsif ( $attributes{tag} eq 'button' ) {
    html_tag('button', undef, %attributes, value => $value, (onclick => $onclick)x!!$onclick);
  }
}

sub submit_tag {
  my ($name, $value, %attributes) = @_;

  _set_id_attribute(\%attributes, $attributes{name}) if $attributes{name};

  if ( $attributes{confirm} ) {
    $attributes{onclick} = 'return confirm("'. _J(delete($attributes{confirm})) .'");';
  }

  input_tag($name, $value, %attributes, type => 'submit', class => 'submit');
}

sub ajax_submit_tag {
  my ($url, $form_selector, $text, %attributes) = @_;

  $url           = _J($url);
  $form_selector = _J($form_selector);
  my $onclick    = qq|kivi.submit_ajax_form('${url}', '${form_selector}')|;

  button_tag($onclick, $text, %attributes);
}

sub input_number_tag {
  my ($name, $value, %params) = @_;

  _set_id_attribute(\%params, $name);
  my @onchange = $params{onchange} ? (onChange => delete $params{onchange}) : ();
  my @classes  = ('numeric');
  push @classes, delete($params{class}) if $params{class};
  my %class    = @classes ? (class => join(' ', @classes)) : ();

  $::request->layout->add_javascripts('kivi.Validator.js');
  $::request->presenter->need_reinit_widgets($params{id});

  input_tag(
    $name, $::form->format_amount(\%::myconfig, $value, $params{precision}),
    "data-validate" => "number",
    %params,
    %class, @onchange,
  );
}

sub input_email_tag {
  my ($name, $value, %params) = @_;

  my $show_icon = $value || delete($params{show_icon_always});

  # _set_id_attribute removes the no_id param
  my $no_id_wanted = $params{no_id};
  _set_id_attribute(\%params, $name);
  $params{no_id} = $no_id_wanted;

  my $html = input_tag_trim($name, $value, %params);

  my $link_id   = $params{id} ? $params{id} . '_link' : undef;
  $html        .= link_tag(escape('mailto:' . $value),
                           img_tag(src => 'image/mail.png', alt => t8('Send email'), border => 0),
                           (id    => $link_id)x!!$link_id,
                           (style => 'display:none')x!$show_icon);

  return '<span>' . $html . '</span>';
}

sub context_help_tag {
  my ($text, %params) = @_;

  my $class    = $params{class} // 'context-help';
  my $tt_class = $params{html} ? 'tooltipster-html' : 'tooltipster';

  img_tag(src => 'image/icons/svg/question.svg', class => "$class $tt_class", title => $text);
}

sub javascript {
  my ($data) = @_;
  html_tag('script', $data, type => 'text/javascript');
}

sub _set_id_attribute {
  my ($attributes, $name, $unique) = @_;

  if (!delete($attributes->{no_id}) && !$attributes->{id}) {
    $attributes->{id}  = name_to_id($name);
    $attributes->{id} .= '_' . $attributes->{value} if $unique;
  }

  %{ $attributes };
}

my $html_restricter;

sub textarea_tag {
  my ($name, $content, %attributes) = @_;

  _set_id_attribute(\%attributes, $name);
  $attributes{rows}  *= 1; # required by standard
  $attributes{cols}  *= 1; # required by standard

  if (join_values(class => $attributes{class}) =~ /\btexteditor\b/) {
    $::request->{layout}->add_javascripts("$_.js") for qw(ckeditor5/ckeditor ckeditor5/translations/de);
  }

  html_tag('textarea', $content, %attributes, name => $name);
}

sub link_tag {
  my ($href, $content, %params) = @_;

  $href ||= '#';

  html_tag('a', $content, %params, href => $href);
}
# alias for compatibility
sub link { goto &link_tag }

sub date_tag {
  my ($name, $value, %params) = @_;

  _set_id_attribute(\%params, $name);
  my @onchange = $params{onchange} ? (onChange => delete $params{onchange}) : ();
  my @classes  = $params{no_cal} || $params{readonly} ? () : ('datepicker');
  push @classes, delete($params{class}) if $params{class};
  my %class    = @classes ? (class => join(' ', @classes)) : ();

  $::request->layout->add_javascripts('kivi.Validator.js');
  $::request->presenter->need_reinit_widgets($params{id});

  $params{'data-validate'} = join(' ', "date", grep { $_ } (delete $params{'data-validate'}));

  input_tag(
    $name, blessed($value) ? $value->to_lxoffice : $value,
    size   => 11,
    %params,
    %class, @onchange,
  );
}

sub div_tag {
  my ($content, %params) = @_;
  return html_tag('div', $content, %params);
}

sub img_tag {
  my (%params) = @_;

  $params{alt} ||= '';

  return html_tag('img', undef, %params);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Tag - Layouting / tag generation

=head1 SYNOPSIS

Usage in a template:

  [% USE P %]

  [% P.select_tag('direction', [ [ 'left', 'To the left' ], [ 'right', 'To the right', 1 ] ]) %]

  [% P.select_tag('direction', [ { direction => 'left',  display => 'To the left'  },
                                 { direction => 'right', display => 'To the right' } ],
                               value_key => 'direction', title_key => 'display', default => 'right') %]

  [% P.select_tag('direction', [ { direction => 'left',  display => 'To the left'  },
                                 { direction => 'right', display => 'To the right', selected => 1 } ],
                               value_key => 'direction', title_key => 'display') %]

  # Use an RDBO object and its n:m relationship as the default
  # values. For example, a user can be a member of many groups. "All
  # groups" is therefore the full collection and "$user->groups" is a
  # list of RDBO AuthGroup objects whose IDs must match the ones in
  # "All groups". This could look like the following:
  [% P.select_tag('user.groups[]', SELF.all_groups, multiple=1,
                  default=SELF.user.groups, default_value_key='id' ) %]

=head1 DESCRIPTION

A module modeled a bit after Rails' ActionView helpers. Several small
functions that create HTML tags from various kinds of data sources.

The C<id> attribute is usually calculated automatically. This can be
overridden by either specifying an C<id> attribute or by setting
C<no_id> to trueish.

=head1 FUNCTIONS

=head2 LOW-LEVEL FUNCTIONS

=over 4

=item C<html_tag $tag_name, $content_string, %attributes>

Creates an opening and closing HTML tag for C<$tag_name> and puts
C<$content_string> between the two. If C<$content_string> is undefined
or empty then only a E<lt>tag/E<gt> tag will be created. Attributes
are key/value pairs added to the opening tag.

C<$content_string> is not HTML escaped.

=item C<name_to_id $name>

Converts a name to a HTML id by replacing various characters.

=item C<stringify_attributes %items>

Creates a string from all elements in C<%items> suitable for usage as
HTML tag attributes. Keys and values are HTML escaped even though keys
must not contain non-ASCII characters for browsers to accept them.

=back

=head2 HIGH-LEVEL FUNCTIONS

=over 4

=item C<input_tag $name, $value, %attributes>

Creates a HTML 'input type=text' tag named C<$name> with the value
C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

=item C<input_tag_trim $name, $value, %attributes>

This is a wrapper around C<input_tag> that adds ' trimmed_whitespaces' to
$attributes{'data-validate'} and loads C<js/kivi.Validator.js>. This will trim
the whitespaces around the input.

=item C<input_email_tag $name, $value, %params>

This creates an C<input_tag_trim> and a C<link_tag> with an C<img_tag> for an
email icon. The link opens a 'mailto:' url with the value of the C<input_tag>.
The style of the C<link_tag> is set to 'display:none' if there is no value or
if the param C<show_icon_always> is truish.
All but the C<show_icon_always> params are forwared to the C<input_tag_trim>
as attributes.
This tag does not offer any javascript magic. The input value is only
evaluated when the tag is created.
The 'id' attrubute of the C<link_tag> is set to the 'id' of the C<input_tag>
with the string '_link' appended. This can be used to show/hide set the
C<link_tag> or set the link target dynamically.

=item C<submit_tag $name, $value, %attributes>

Creates a HTML 'input type=submit class=submit' tag named C<$name> with the
value C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

If C<$attributes{confirm}> is set then a JavaScript popup dialog will
be added via the C<onclick> handler asking the question given with
C<$attributes{confirm}>. The request is only submitted if the user
clicks the dialog's ok/yes button.

=item C<ajax_submit_tag $url, $form_selector, $text, %attributes>

Creates a HTML 'input type="button"' tag with a very specific onclick
handler that submits the form given by the jQuery selector
C<$form_selector> to the URL C<$url> (the actual JavaScript function
called for that is C<kivi.submit_ajax_form()> in
C<js/client_js.js>). The button's label will be C<$text>.

=item C<button_tag $onclick, $text, %attributes>

Creates a HTML 'input type="button"' tag with an onclick handler
C<$onclick> and a value of C<$text>. The button does not have a name
nor an ID by default.

If C<$attributes{confirm}> is set then a JavaScript popup dialog will
be prepended to the C<$onclick> handler asking the question given with
C<$attributes{confirm}>. The request is only submitted if the user
clicks the dialog's "ok/yes" button.

=item C<man_days_tag $name, $object, %attributes>

Creates two HTML inputs: a text input for entering a number and a drop
down box for chosing the unit (either 'man days' or 'hours').

C<$object> must be a L<Rose::DB::Object> instance using the
L<SL::DB::Helper::AttrDuration> helper.

C<$name> is supposed to be the name of the underlying column,
e.g. C<time_estimation> for an instance of
C<SL::DB::RequirementSpecItem>. If C<$name> has the form
C<prefix.method> then the full C<$name> is used for the input's base
names while the methods called on C<$object> are only the suffix. This
makes it possible to write statements like e.g.

  [% P.man_days_tag("requirement_spec_item.time_estimation", SELF.item) %]

The attribute C<size> can be used to set the text input's size. It
defaults to 5.

=item C<hidden_tag $name, $value, %attributes>

Creates a HTML 'input type=hidden' tag named C<$name> with the value
C<$value> and with arbitrary HTML attributes from C<%attributes>. The
tag's C<id> defaults to C<name_to_id($name)>.

=item C<checkbox_tag $name, %attributes>

Creates a HTML 'input type=checkbox' tag named C<$name> with arbitrary
HTML attributes from C<%attributes>. The tag's C<id> defaults to
C<name_to_id($name)>. The tag's C<value> defaults to C<1>.

If C<%attributes> contains a key C<label> then a HTML 'label' tag is
created with said C<label>. No attribute named C<label> is created in
that case. Furthermore, all attributes whose names start with
C<label_> become attributes on the label tag without the C<label_>
prefix. For example, C<label_style='#ff0000'> will be turned into
C<style='#ff0000'> on the label tag, causing the text to become red.

If C<%attributes> contains a key C<checkall> then the value is taken as a
JQuery selector and clicking this checkbox will also toggle all checkboxes
matching the selector.

=item C<radio_button_tag $name, %attributes>

Creates a HTML 'input type=radio' tag named C<$name> with arbitrary
HTML attributes from C<%attributes>. The tag's C<value> defaults to
C<1>. The tag's C<id> defaults to C<name_to_id($name . "_" . $value)>.

If C<%attributes> contains a key C<label> then a HTML 'label' tag is
created with said C<label>. No attribute named C<label> is created in
that case. Furthermore, all attributes whose names start with
C<label_> become attributes on the label tag without the C<label_>
prefix. For example, C<label_style='#ff0000'> will be turned into
C<style='#ff0000'> on the label tag, causing the text to become red.

=item C<select_tag $name, \@collection, %attributes>

Creates an HTML 'select' tag named C<$name> with the contents of one
'E<lt>optionE<gt>' tag for each element in C<\@collection> and with arbitrary
HTML attributes from C<%attributes>. The value
to use and the title to display are extracted from the elements in
C<\@collection>. Each element can be one of four things:

=over 12

=item 1. An array reference with at least two elements. The first element is
the value, the second element is its title. The third element is optional and and should contain a boolean.
If it is true, than the element will be used as default.

=item 2. A scalar. The scalar is both the value and the title.

=item 3. A hash reference. In this case C<%attributes> must contain
I<value_key>, I<title_key> and may contain I<default_key> keys that name the keys in the element to use
for the value, title and default respectively.

=item 4. A blessed reference. In this case C<%attributes> must contain
I<value_key>, I<title_key> and may contain I<default_key> keys that name functions called on the blessed
reference whose return values are used as the value, title and default
respectively.

=back

For cases 3 and 4 C<$attributes{value_key}> defaults to C<id>,
C<$attributes{title_key}> defaults to C<$attributes{value_key}> and
C<$attributes{default_key}> defaults to C<selected>. Note that
C<$attributes{default_key}> is set to C<undef> if
C<$attributes{default_value_key}> is used as well (see below).

In addition to pure keys/method you can also provide coderefs as I<value_sub>
and/or I<title_sub> and/or I<default_sub>. If present, these take precedence over keys or methods,
and are called with the element as first argument. It must return the value, title or default.

Lastly a joint coderef I<value_title_sub> may be provided, which in turn takes
precedence over the C<value_sub> and C<title_sub> subs. It will only be called once for each
element and must return a list of value and title.

If the option C<with_empty> is set then an empty element (value
C<undef>) will be used as the first element. The title to display for
this element can be set with the option C<empty_title> and defaults to
an empty string.

The tag's C<id> defaults to C<name_to_id($name)>.

The option C<default> can be quite a lot of things:

=over 4

=item 1. A scalar value. This is the value of the entry that's
selected by default.

=item 2. A hash reference for C<multiple=1>. Whether or not an entry
is selected by default is looked up in this hash.

=item 3. An array reference containing scalar values. Same as 1., just
for the case of C<multiple=1>.

=item 4. If C<default_value_key> is given: an array reference of hash
references. For each hash reference the value belonging to the key
C<default_value_key> is treated as one value to select by
default. Constructs a hash that's treated like 3.

=item 5. If C<default_value_key> is given: an array reference of
blessed objects. For each object the value returne from calling the
function named C<default_value_key> on the object is treated as one
value to select by default. Constructs a hash that's treated like 3.

=back

5. also applies to single RDBO instances (due to 'wantarray'
shenanigans assigning RDBO's relationships to a hash key will result
in a single RDBO object being assigned instead of an array reference
containing that single RDBO object).

If the option C<with_optgroups> is set then this function expects
C<\@collection> to be one level deeper. The upper-most level is
translated into an HTML C<optgroup> tag. So the structure becomes:

=over 4

=item 1. Array of array references. Each element in the
C<\@collection> is converted into an optgroup.

=item 2. The optgroup's C<label> attribute will be set to the
first element in the array element. The second array element is then
converted to a list of C<option> tags as described above.

=back

Example for use of optgroups:

  # First in a controller:
  my @collection = (
    [ t8("First optgroup with three items"),
      [ { id => 42, name => "item one" },
        { id => 54, name => "second item" },
        { id => 23, name => "and the third one" },
      ] ],
    [ t8("Another optgroup, with a lot of items from Rose"),
      SL::DB::Manager::Customer->get_all_sorted ],
  );

  # Later in the template:
  [% L.select_tag('the_selection', COLLECTION, with_optgroups=1, title_key='name') %]

=item C<multi_level_select_tag $name, \@collection, $levels, %attributes>

Creates multiple HTML 'select' tags, one for each level. Each tag ist created
with C<select_tag>.

The parameters for C<select_tag> are created from the values stored in the
corrosponding level attributes. The attributes for each level are in
C<%attributes{level_i}>, starting with 1.

The following are used directly from each level:

=over 4

=item I<name> is deleted from level attributes.
The I<name> is used for the name of the 'select' tag.

=item I<object_key> is deleted from level attriutes.
The I<object_key> is used to get the level objects for the current level
from the object of the previous level, this is intended for the use of RSDB object.
Each level attributes must contain I<object_key>, except level_1.

=item I<id> is overridden.
The I<id> is set to a specific value for use in JavaScript.

=item I<value_key> names the key for the value of level object. Defaults to
C<id>.

=item I<title_key> names the key for the titel of level object. Defaults to
C<$attributes{value_key}>.

=item I<default> is used to find the default level object.

=item I<default_key> names the key for the default feld of level object. Is
ignored if I<default> is set.

=item I<\@collection> is used for the level object of level 1. The objects of the next
level are taken from the previous level via the <object_key>. On each level the
objects must be a hash reference or a blessed reference.

=back

A I<surround_tag> can be specified, which generates an C<html_tag> with the
corresponding tag around every C<select_tag>.

Example:

  # First in a controller:
    my @collection = (
    { 'description' => 'foo_1', 'id' => '1',
      'key_1' => [
        { 'id' => 3, 'description' => "bar_1",
          'key_2' => [
            { 'id' => 1, 'value' => "foobar_1", },
            { 'id' => 2, 'value' => "foobar_2", },
          ], },
        { 'id' => 4, 'description' => "bar_2",
        'key_2' => [], },
      ], },
    { 'description' => 'foo_2', 'id' => '2',
      'key_1' => [
        { 'id' => 1, 'description' => "bar_1",
          'key_2' => [
            { 'id' => 3, 'value' => "foobar_3", },
            { 'id' => 4, 'value' => "foobar_4", },
          ], },
        { 'id' => 2, 'description' => "bar_2",
          'stock' => [
            { 'id' => 5, 'value' => "test_5", },
          ], },
      ], },
  );

  # Later in the template (in a table):
  [% L.multi_level_select_tag("multi_select_foo_bar_foobar", COLLECTION, 3,
      surround_tag="td",
      level_1={
        name="foo.id",
        value_key="id",
        title_key="description",
        default="2",
      },
      level_2={
        object_key="key_1",
        name="bar.id",
        value_key="id",
        title_key="description",
        default="1",
      },
      level_3={
        object_key="key_2",
        name="foobar.id",
        value_key="id",
        title_key="value",
        default="4",
      },
  ) %]

=item C<context_help_tag $tooltip, %params>

This creates a small circled question mark in the size of the current text with
the given text as a mouse-over tooltip .

If C<params> contains C<html>, then the tooltip is rendered as html. If
C<params> contains a C<class>, then this is used instead of the default css
class C<context-help>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>,
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
