#!/usr/bin/perl
#

#$| = 1;

#use CGI::Carp qw(fatalsToBrowser);

use strict;

sub run {
  my $session_result = shift;
  %::myconfig = $::auth->read_user($::form->{login})  if  $::form->{login};
  $::locale   = Locale->new($::myconfig{countrycode}) if $::myconfig{countrycode};

my $form     = $main::form;
my $locale   = $main::locale;

$form->header;
my $paramstring = $ENV{"QUERY_STRING"};
my @felder = split "&", $paramstring;
my ($name, $wert);
foreach (@felder) {
  ($name, $wert) = split "=", $_;
  $wert =~ tr/+/ /;
  $name = $wert;
}
my $login =
    "[" . $form->{login}
  . " - <a href=\"login.pl?action=logout\" target=\"_top\">"
  . $locale->text('Logout')
  . "</a>] ";
my ($Sekunden, $Minuten,   $Stunden,   $Monatstag, $Monat,
    $Jahr,     $Wochentag, $Jahrestag, $Sommerzeit)
  = localtime(time);
my $CTIME_String = localtime(time);
$Monat     += 1;
$Jahrestag += 1;
$Monat     = $Monat < 10     ? $Monat     = "0" . $Monat     : $Monat;
$Monatstag = $Monatstag < 10 ? $Monatstag = "0" . $Monatstag : $Monatstag;
$Jahr += 1900;
my @Wochentage = ("Sonntag",    "Montag",  "Dienstag", "Mittwoch",
                  "Donnerstag", "Freitag", "Samstag");
my @Monatsnamen = ("",       "Januar",    "Februar", "M&auml;rz",
                   "April",  "Mai",       "Juni",    "Juli",
                   "August", "September", "Oktober", "November",
                   "Dezember");
my $datum =
    $Wochentage[$Wochentag] . ", der "
  . $Monatstag . "."
  . $Monat . "."
  . $Jahr . " - ";

#$zeit="<div id='Uhr'>".$Stunden.":".$Minuten.":".$Sekunden."</div>";
my $zeit = "<div id='Uhr'>" . $Stunden . ":" . $Minuten . "</div>";

print qq|
<script type="text/javascript">
<!--
var clockid=new Array()
var clockidoutside=new Array()
var i_clock=-1
var thistime= new Date()
var hours= | . $Stunden . qq|;
var minutes= | . $Minuten . qq|;
var seconds= | . $Sekunden . qq|;
if (eval(hours) <10) {hours="0"+hours}
if (eval(minutes) < 10) {minutes="0"+minutes}
if (seconds < 10) {seconds="0"+seconds}
//var thistime = hours+":"+minutes+":"+seconds
var thistime = hours+":"+minutes

function writeclock() {
  i_clock++
  if (document.all \|\| document.getElementById \|\| document.layers) {
    clockid[i_clock]="clock"+i_clock
    document.write("<font family=arial size=2><span id='"+clockid[i_clock]+"' style='position:relative'>"+thistime+"</span></font>")
  }
}

function clockon() {
  thistime= new Date()
  hours=thistime.getHours()
  minutes=thistime.getMinutes()
  seconds=thistime.getSeconds()
  if (eval(hours) <10) {hours="0"+hours}
  if (eval(minutes) < 10) {minutes="0"+minutes}
  if (seconds < 10) {seconds="0"+seconds}
  //thistime = hours+":"+minutes+":"+seconds
  thistime = hours+":"+minutes

  if (document.all) {
    for (i=0;i<=clockid.length-1;i++) {
      var thisclock=eval(clockid[i])
      thisclock.innerHTML=thistime
    }
  }

  if (document.getElementById) {
    for (i=0;i<=clockid.length-1;i++) {
      document.getElementById(clockid[i]).innerHTML=thistime
    }
  }
  var timer=setTimeout("clockon()",60000)
}
window.onload=clockon
//-->
</script>
|;

#
print qq|
<body bgcolor="#ffffff" text="#ffffff" link="#ffffff" vlink="#ffffff" alink="#ffffff" topmargin="0" leftmargin="0"  marginwidth="0" marginheight="0" style="background-image: url('image/fade.png'); background-repeat:repeat-x;">

<table border="0" width="100%" background="image/bg_titel.gif" cellpadding="0" cellspacing="0">
  <tr>
    <td  style="color:white; font-family:verdana,arial,sans-serif; font-size: 12px;">
      &nbsp;[<a href="JavaScript:top.main_window.print();" title="| . $locale->text('Hardcopy') . qq|">| . $locale->text('Print') . qq|</a>]
      &nbsp;[<a HREF="login.pl" target="_blank" "title="| . $locale->text('Open a further Lx-Office Window or Tab') . qq|">| . $locale->text('New Win/Tab') . qq|</a>]
      &nbsp;[<a href="Javascript:top.main_window.history.back();" title="| . $locale->text('Go one step back') . qq|">| . $locale->text('Back') . qq|</a>]
      <!-- is there a better solution for Back? Possibly with the callback variable? -->
    </td>
    <td align="right" style="vertical-align:middle; color:white; font-family:verdana,arial,sans-serif; font-size: 12px;" nowrap>|
  . $login . $datum . qq| <script>writeclock()</script>&nbsp;
    </td>
  </tr>
</table>
</body>
</html>
|;

}

1;

#
