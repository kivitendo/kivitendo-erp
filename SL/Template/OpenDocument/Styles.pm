package SL::Template::OpenDocument::Styles;

use strict;
use utf8;

use Carp;

my %styles = (
  text_basic => qq|
    <style:style style:name="TKIVITENDOBOLD" style:family="text">
      <style:text-properties fo:font-weight="bold" style:font-weight-asian="bold" style:font-weight-complex="bold"/>
    </style:style>
    <style:style style:name="TKIVITENDOITALIC" style:family="text">
      <style:text-properties fo:font-style="italic" style:font-style-asian="italic" style:font-style-complex="italic"/>
    </style:style>
    <style:style style:name="TKIVITENDOUNDERLINE" style:family="text">
      <style:text-properties style:text-underline-style="solid" style:text-underline-width="auto" style:text-underline-color="font-color"/>
    </style:style>
    <style:style style:name="TKIVITENDOSTRIKETHROUGH" style:family="text">
      <style:text-properties style:text-line-through-style="solid"/>
    </style:style>
    <style:style style:name="TKIVITENDOSUPER" style:family="text">
      <style:text-properties style:text-position="super 58%"/>
    </style:style>
    <style:style style:name="TKIVITENDOSUB" style:family="text">
      <style:text-properties style:text-position="sub 58%"/>
    </style:style>
    <style:style style:name="TKIVITENDOBULLETS" style:family="text">
      <style:text-properties style:font-name="OpenSymbol" fo:font-family="OpenSymbol" style:font-charset="x-symbol" style:font-name-asian="OpenSymbol" style:font-family-asian="OpenSymbol" style:font-charset-asian="x-symbol" style:font-name-complex="OpenSymbol" style:font-family-complex="OpenSymbol" style:font-charset-complex="x-symbol"/>
    </style:style>
    <style:style style:name="TKIVITENDONUMBERING" style:family="text"/>
|,

  text_list_item => qq|
    <style:style style:name="PKIVITENDO__TYPE____PARENT__" style:family="paragraph" style:parent-style-name="__PARENT__" style:list-style-name="LKIVITENDO__TYPE____PARENT__">
      <style:text-properties officeooo:rsid="002df67b" officeooo:paragraph-rsid="002df67b"/>
    </style:style>
|,

  list_itemize => qq|
    <text:list-style style:name="LKIVITENDO__TYPE____PARENT__">
      <text:list-level-style-bullet text:level="1" text:style-name="TKIVITENDOBULLETS" text:bullet-char="•">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="0.80cm" fo:text-indent="-0.435cm" fo:margin-left="0.80cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="2" text:style-name="TKIVITENDOBULLETS" text:bullet-char="◦">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="1.2cm" fo:text-indent="-0.435cm" fo:margin-left="1.2cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="3" text:style-name="TKIVITENDOBULLETS" text:bullet-char="▪">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="1.6cm" fo:text-indent="-0.435cm" fo:margin-left="1.6cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="4" text:style-name="TKIVITENDOBULLETS" text:bullet-char="•">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="2.0cm" fo:text-indent="-0.435cm" fo:margin-left="2.0cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="5" text:style-name="TKIVITENDOBULLETS" text:bullet-char="◦">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="2.4cm" fo:text-indent="-0.435cm" fo:margin-left="2.4cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="6" text:style-name="TKIVITENDOBULLETS" text:bullet-char="▪">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="2.80cm" fo:text-indent="-0.435cm" fo:margin-left="2.80cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="7" text:style-name="TKIVITENDOBULLETS" text:bullet-char="•">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="3.20cm" fo:text-indent="-0.435cm" fo:margin-left="3.20cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="8" text:style-name="TKIVITENDOBULLETS" text:bullet-char="◦">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="3.60cm" fo:text-indent="-0.435cm" fo:margin-left="3.60cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="9" text:style-name="TKIVITENDOBULLETS" text:bullet-char="▪">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="4.00cm" fo:text-indent="-0.435cm" fo:margin-left="4.00cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
      <text:list-level-style-bullet text:level="10" text:style-name="TKIVITENDOBULLETS" text:bullet-char="•">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="4.40cm" fo:text-indent="-0.435cm" fo:margin-left="4.40cm"/>
        </style:list-level-properties>
      </text:list-level-style-bullet>
    </text:list-style>|,

  list_enumerate => qq|
    <text:list-style style:name="LKIVITENDO__TYPE____PARENT__">
      <text:list-level-style-number text:level="1" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="0.80cm" fo:text-indent="-0.435cm" fo:margin-left="0.80cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="2" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="1.2cm" fo:text-indent="-0.435cm" fo:margin-left="1.2cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="3" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="1.6cm" fo:text-indent="-0.435cm" fo:margin-left="1.6cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="4" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="2.0cm" fo:text-indent="-0.435cm" fo:margin-left="2.0cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="5" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="2.4cm" fo:text-indent="-0.435cm" fo:margin-left="2.4cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="6" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="2.80cm" fo:text-indent="-0.435cm" fo:margin-left="2.80cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="7" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="3.20cm" fo:text-indent="-0.435cm" fo:margin-left="3.20cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="8" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="3.60cm" fo:text-indent="-0.435cm" fo:margin-left="3.60cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="9" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="4.00cm" fo:text-indent="-0.435cm" fo:margin-left="4.00cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
      <text:list-level-style-number text:level="10" text:style-name="TKIVITENDONUMBERING" style:num-suffix="." style:num-format="1">
        <style:list-level-properties text:list-level-position-and-space-mode="label-alignment">
          <style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="4.40cm" fo:text-indent="-0.435cm" fo:margin-left="4.40cm"/>
        </style:list-level-properties>
      </text:list-level-style-number>
    </text:list-style>|,
);

sub get_style {
  my ($class, $style_name, %replacements) = @_;

  my $copy = "". $styles{$style_name} || croak("Unknown style $style_name");

  $copy =~ s{^ +}{}gm;
  $copy =~ s{[\r\n]+}{}gm;
  $copy =~ s{__${_}__}{ $replacements{$_} }ge for keys %replacements;

  return $copy;
}

1;
