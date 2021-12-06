package SL::Helper::PrintOptions;

use strict;

use List::MoreUtils qw(any);

sub opthash { +{ value => shift, selected => shift, oname => shift } }

# generate the printing options displayed at the bottom of oe and is forms.
# this function will attempt to guess what type of form is displayed, and will generate according options
#
# about the coding:
# this version builds the arrays of options pretty directly. if you have trouble understanding how,
# the opthash function builds hashrefs which are then pieced together for the template arrays.
# unneeded options are "undef"ed out, and then grepped out.
#
# the inline options is untested, but intended to be used later in metatemplating
sub get_print_options {
  my ($class, %params) = @_;

  no warnings 'once';

  my $form     = $params{form}     || $::form;
  my $myconfig = $params{myconfig} || \%::myconfig;
  my $locale   = $params{locale}   || $::locale;
  my $options  = $params{options};

  use warnings 'once';

  my $prefix = $options->{dialog_name_prefix} || '';

  # names 3 parameters and returns a hashref, for use in templates
  my (@FORMNAME, @LANGUAGE_ID, @FORMAT, @SENDMODE, @MEDIA, @PRINTER_ID, @SELECTS) = ();

  # note: "||"-selection is only correct for values where "0" is _not_ a correct entry
  $form->{sendmode}   = "attachment";
  $form->{format}     = $form->{format} || $myconfig->{template_format} || "pdf";
  $form->{copies}     = $form->{copies} || $myconfig->{copies}          || 3;
  $form->{media}      = $form->{media}  || $myconfig->{default_media}   || "screen";
  $form->{printer_id} = defined $form->{printer_id}           ? $form->{printer_id} :
                        defined $myconfig->{default_printer_id} ? $myconfig->{default_printer_id} : "";

  $form->{PD}{ $form->{formname} } = "selected";
  $form->{DF}{ $form->{format} }   = "selected";
  $form->{OP}{ $form->{media} }    = "selected";
  $form->{SM}{ $form->{sendmode} } = "selected";

  push @FORMNAME, grep $_,
    ($form->{type} eq 'purchase_order') ? (
      opthash("purchase_order",      $form->{PD}{purchase_order},      $locale->text('Purchase Order')),
      opthash("bin_list",            $form->{PD}{bin_list},            $locale->text('Bin List'))
    ) : undef,
    ($form->{type} eq 'credit_note') ?
      opthash("credit_note",         $form->{PD}{credit_note},         $locale->text('Credit Note')) : undef,
    ($form->{type} eq 'sales_order') ? (
      opthash("sales_order",         $form->{PD}{sales_order},         $locale->text('Confirmation')),
      opthash("proforma",            $form->{PD}{proforma},            $locale->text('Proforma Invoice')),
      opthash("ic_supply",           $form->{PD}{ic_supply},            $locale->text('Intra-Community supply')),
    ) : undef,
    ($form->{type} =~ /sales_quotation$/) ?
      opthash('sales_quotation',     $form->{PD}{sales_quotation},     $locale->text('Quotation')) : undef,
    ($form->{type} =~ /request_quotation$/) ?
      opthash('request_quotation',   $form->{PD}{request_quotation},   $locale->text('Request for Quotation')) : undef,
    ($form->{type} eq 'invoice') ? (
      opthash("invoice",             $form->{PD}{invoice},             $locale->text('Invoice')),
      opthash("proforma",            $form->{PD}{proforma},            $locale->text('Proforma Invoice')),
      opthash("invoice_copy",        $form->{PD}{invoice_copy},        $locale->text('Invoice Copy')),
    ) : undef,
    ($form->{type} eq 'invoice' && $form->{storno}) ? (
      opthash("storno_invoice",      $form->{PD}{storno_invoice},      $locale->text('Storno Invoice')),
    ) : undef,
    ($form->{type} eq 'invoice_for_advance_payment') ? (
      opthash("invoice_for_advance_payment", $form->{PD}{invoice_for_advance_payment},      $locale->text('Invoice for Advance Payment')),
    ) : undef,
    ($form->{type} eq 'final_invoice') ? (
      opthash("final_invoice", $form->{PD}{final_invoice},             $locale->text('Final Invoice')),
    ) : undef,
    ($form->{type} =~ /_delivery_order$/) ? (
      opthash($form->{type},         $form->{PD}{$form->{type}},       $locale->text('Delivery Order')),
      opthash('pick_list',           $form->{PD}{pick_list},           $locale->text('Pick List')),
    ) : undef,
    ($form->{type} =~ /^letter$/) ? (
      opthash('letter',              $form->{PD}{letter},              $locale->text('Letter')),
    ) : undef;

  push @SENDMODE,
    opthash("attachment",            $form->{SM}{attachment},          $locale->text('Attachment')),
    opthash("inline",                $form->{SM}{inline},              $locale->text('In-line'))
      if ($form->{media} eq 'email');

  my $printable_templates = any { $::lx_office_conf{print_templates}->{$_} } qw(latex opendocument);
  push @MEDIA, grep $_,
      opthash("screen",              $form->{OP}{screen},              $locale->text('Screen')),
    ($printable_templates && $form->{printers} && scalar @{ $form->{printers} }) ?
      opthash("printer",             $form->{OP}{printer},             $locale->text('Printer')) : undef,
    ($printable_templates && !$options->{no_queue}) ?
      opthash("queue",               $form->{OP}{queue},               $locale->text('Queue')) : undef
        if ($form->{media} ne 'email');

  push @FORMAT, grep $_,
    ($::lx_office_conf{print_templates}->{opendocument} &&     $::lx_office_conf{applications}->{openofficeorg_writer}  &&     $::lx_office_conf{applications}->{xvfb}
                                                        && (-x $::lx_office_conf{applications}->{openofficeorg_writer}) && (-x $::lx_office_conf{applications}->{xvfb})
     && !$options->{no_opendocument_pdf}) ?
      opthash("opendocument_pdf",    $form->{DF}{"opendocument_pdf"},  $locale->text("PDF (OpenDocument/OASIS)")) : undef,
    ($::lx_office_conf{print_templates}->{latex}) ?
      opthash("pdf",                 $form->{DF}{pdf},                 $locale->text('PDF')) : undef,
    ($::lx_office_conf{print_templates}->{latex} && !$options->{no_postscript}) ?
      opthash("postscript",          $form->{DF}{postscript},          $locale->text('Postscript')) : undef,
    (!$options->{no_html}) ?
      opthash("html", $form->{DF}{html}, "HTML") : undef,
    ($::lx_office_conf{print_templates}->{opendocument} && !$options->{no_opendocument}) ?
      opthash("opendocument",        $form->{DF}{opendocument},        $locale->text("OpenDocument/OASIS")) : undef,
    ($::lx_office_conf{print_templates}->{excel} && !$options->{no_excel}) ?
      opthash("excel",               $form->{DF}{excel},               $locale->text("Excel")) : undef;

  push @LANGUAGE_ID,
    map { opthash($_->{id}, ($_->{id} eq $form->{language_id} ? 'selected' : ''), $_->{description}) } +{}, @{ $form->{languages} }
      if (ref $form->{languages} eq 'ARRAY');

  push @PRINTER_ID,
    map { opthash($_->{id}, ($_->{id} eq $form->{printer_id} ? 'selected' : ''), $_->{printer_description}) } +{}, @{ $form->{printers} }
      if ((ref $form->{printers} eq 'ARRAY') && scalar @{ $form->{printers } });

  @SELECTS = map {
    sname  => $_->[1],
    DATA   => $_->[0],
    show   => !$options->{"hide_" . $_->[1]} && scalar @{ $_->[0]},
    hname  => $locale->text($_->[2])
  },
  [ \@FORMNAME,    'formname',    'Formname' ],
  [ \@LANGUAGE_ID, 'language_id', 'Language' ],
  [ \@FORMAT,      'format',      'Format'   ],
  [ \@SENDMODE,    'sendmode',    'Sendmode' ],
  [ \@MEDIA,       'media',       'Media'    ],
  [ \@PRINTER_ID,  'printer_id',  'Printer'  ];

  my %dont_display_groupitems = (
    'dunning' => 1,
    );

  my %template_vars = (
    name_prefix          => $prefix || '',
    show_headers         => $options->{show_headers},
    display_copies       => scalar @{ $form->{printers} || [] } && $::lx_office_conf{print_templates}->{latex} && $form->{media} ne 'email',
    display_remove_draft => (!$form->{id} && $form->{draft_id}),
    display_groupitems   => !$dont_display_groupitems{$form->{type}},
    display_bothsided    => $options->{show_bothsided},
    groupitems_checked   => $form->{groupitems} ? "checked" : '',
    bothsided_checked    => $form->{bothsided}  ? "checked" : '',
    remove_draft_checked => $form->{remove_draft} ? "checked" : ''
  );

  return $form->parse_html_template("generic/print_options", { SELECTS  => \@SELECTS, %template_vars } );
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Helper::PrintOptions - A helper for generating the print options for
templates

=head1 SYNOPSIS

  # render your template with print_options
  $self->render('letter/edit',
    %params,
    letter        => $letter,
    print_options => SL::Helper::PrintOptions->get_print_options (
      options => { no_postscript   => 1,
                   no_opendocument => 1,
                   no_html         => 1,
                   no_queue        => 1 }),

  );

Then, in the template, you can render the options with
    C<[% print_options %]>. Look at the template
    C<generic/print_options> to see, which variables you get back.

=head1 FUNCTIONS

=over 4

=item C<get_print_options %params>

Parses the template C<generic/print_options>. It does some guessings
    and settings according to the params, (namely C<form>).


The recognized parameters are:

=over 2

=item * C<form>: defaults to $::form if not given. There are several
    keys in C<form> which control the output of the options,
    e.g. C<format>, C<media>, C<copies>, C<printers>, C<printer_id>,
    C<type>, C<formname>, ...

=item * C<myconfig>: defaults to %::myconfig

=item * C<locale>: defaults to $::locale

=item * C<options>: Options can be:

* C<dialog_name_prefix>: a string prefixed to the template
    variables. E.g. if prefix is C<mypref_> the value for copies
    returned from the user is in $::form->{mypref_copies}

* C<show_header>: render headings for the input elements

* C<no_queue>: if set, do not show option for printing to queue

* C<no_opendocument>: if set, do not show option for printing
    opendocument format

* C<no_postscript>: if set, do not show option for printing
    postscript format

* C<no_html>: if set, do not show option for printing
    html format

* C<no_opendocument_pdf>

* C<no_excel>

* and some more

=back

=back

=head1 AUTHOR

?

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt> (I just moved
    it from io.pl to here and did some minor changes)

=head1 BUGS

incomplete documentation

=cut
