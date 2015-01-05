package SL::Controller::ODGeierlein;

use strict;
use utf8;
use List::Util qw(first);

use parent qw(SL::Controller::Base);

use SL::USTVA;

use Rose::Object::MakeMethods::Generic;

#
# actions
#

sub action_send {
  $::lxdebug->enter_sub();
  my ($self) = @_;
  my $err = '';

  # Aufruf von get_config zum Einlesen der Daten aus Finanzamt und Defaults

  my $ustva = USTVA->new();
  $ustva->get_config();
  $ustva->get_finanzamt();
  $ustva->set_FromTo(\%$::form);
  $::lxdebug->message($LXDebug::DEBUG2,"fromdate=".$::form->{fromdate}." todate=".$::form->{todate}." meth=".$::form->{method});

  my $tax_office     = first { $_->{id} eq $::form->{fa_land_nr} } @{ $ustva->{tax_office_information} };

  if ( !$::form->{co_zip} ) {
    $::form->{co_zip} = $::form->{co_city};
    $::form->{co_zip} =~ s/\D//g;
    $::form->{co_city} =~ s/\d//g;
    $::form->{co_city} =~ s/^\s//g;
  }
  $::form->{period}=~ s/^0//;

  # Aufbau der Geierlein Parameter
  my $params=
    "name = "  .$::form->{company}."\nstrasse = ".$::form->{co_street}.
    "\nplz = "    .$::form->{co_zip}."\nort = "  .$::form->{co_city}.
    "\ntelefon = ".$::form->{co_tel}."\nemail = ".$::form->{co_email}.
    "\nland = ".$tax_office->{taxbird_nr}."\nsteuernummer = ".$::form->{taxnumber}."\njahr = ".$::form->{year}.
    "\nzeitraum = ".$::form->{period}."\n";

  $::lxdebug->message($LXDebug::DEBUG2,"param1=".$params );

  # USTVA Daten erzeugen
  # benötigt $form->{fromdate}, $form->{todate} $form->{method}
  $ustva->ustva(\%::myconfig, \%$::form);

  my @category_cent = $ustva->report_variables({
    myconfig    => \%::myconfig,
    form        => $::form,
    type        => '',
    attribute   => 'position',
    dec_places  => '2',
  });

  #push @category_cent, qw(Z43  Z45  Z53  Z54  Z62  Z65  Z67);

  my @category_euro = $ustva->report_variables({
    myconfig    => \%::myconfig,
    form        => $::form,
    type        => '',
    attribute   => 'position',
    dec_places  => '0',
  });

  # Numberformatting for Geierlein
  my $temp_numberformat = $::myconfig{numberformat};
  # Numberformat must be '1000,00' ?!
  $::myconfig{numberformat} = '1000,00';
  foreach my $number (@{ $::form->{category_cent} }) {
    $::form->{$number} = ($::form->{$number} !=0) ? $::form->format_amount(\%::myconfig, $::form->{$number},'2',''):'';
  }

  foreach my $number (@{ $::form->{category_euro} }) {
    $::form->{$number} = ($::form->{$number} !=0) ? $::form->format_amount(\%::myconfig, $::form->{$number},'0',''):'';
  }
  # Re-set Numberformat
  $::myconfig{numberformat} = $temp_numberformat;

  # Berichtigte Anmeldung
  $params .= "kz10 = 1\n" if $::form->{FA_10};

  # Belege (Verträge, Rechnungen, Erläuterungen usw.) werden gesondert eingereicht
  $params .= "kz22 = 1\n" if $::form->{FA_22};

  # Verrechnung des Erstattungsbetrags erwünscht / Erstattungsbetrag ist abgetreten
  $params .= "kz29 = 1\n" if $::form->{FA_29};

  # Die Einzugsermächtigung wird ausnahmsweise (z.B. wegen Verrechnungswünschen) für diesen Voranmeldungszeitraum widerrufen.
  #  Ein ggf. verbleibender Restbetrag ist gesondert zu entrichten.
  $params .= "kz26 = 1\n" if $::form->{FA_26};

  my @unused_ids = qw(511 861 971 931 Z43 811 891 Z43 Z45 Z53 Z54 Z62 Z65 Z67 83);

  for my $kennziffer (@{$::form->{category_cent}}, @{$::form->{category_euro}}) {
    $::lxdebug->message($LXDebug::DEBUG2,"kennziffer ".$kennziffer."=".$::form->{$kennziffer});

    next if first { $_ eq $kennziffer } @unused_ids;

    if ($::form->{$kennziffer} != 0) {
      $params .= "kz".$kennziffer." = ".$::form->{$kennziffer}."\n";
    }
  }

  $::lxdebug->message($LXDebug::DEBUG2,"param2=".$params );


  $self->js->flash($err?'error':'info',
                   $err?$err:
                   $::locale->text('USTVA Data sent to geierlein'));
  $self->js->run('openGeierlein',$params) if !$err;
  $::lxdebug->leave_sub();
  $self->js->render;
}



#
# filters / helpers
#


1;
