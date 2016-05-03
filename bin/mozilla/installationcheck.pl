use SL::InstallationCheck;

use strict;

sub verify_installation {
  my $script = $0;
  $script =~ s|.*/||;

  my $form     = $main::form;

  return unless ($form->{"action"} && ($script eq "login.pl"));

  SL::InstallationCheck::check_for_conditional_dependencies();

  my @missing_modules = SL::InstallationCheck::test_all_modules();
  return if (scalar(@missing_modules) == 0);

  use SL::Locale;

  my $locale = Locale->new($::lx_office_conf{system}->{language}, "installationcheck");

  print(qq|content-type: text/html

<html>
 <head>
  <link rel="stylesheet" href="css/lx-office-erp.css" type="text/css"
        title="kivitendo stylesheet">
  <title>| . $locale->text("One or more Perl modules missing") . qq|</title>
 </head>
 <body>

  <h1>| . $locale->text("One or more Perl modules missing") . qq|</h1>

  <p>| . $locale->text("At least one Perl module that kivitendo ERP " .
                       "requires for running is not installed on your " .
                       "system.") .
        " " .
        $locale->text("Please install the below listed modules or ask your " .
                      "system administrator to.") .
        " " .
        $locale->text("You cannot continue before all required modules are " .
                      "installed.") . qq|</p>

  <p>
   <table>
    <tr>
     <th class="listheading">| . $locale->text("Module name") . qq|</th>
     <th class="listheading">| . $locale->text("Module home page") . qq|</th>
    </tr>

|);

  my $odd = 1;
  foreach my $module (@missing_modules) {
    print(qq|
     <tr class="listrow${odd}">
      <td><code>$module->{name}</code></td>
      <td><a href="$module->{url}">$module->{url}</a></td>
     </tr>|);
    $odd = 1 - $odd;
  }

  print(qq|
   </table>
  </p>

  <p>| . $locale->text("There are usually three ways to install " .
                       "Perl modules.") .
        " " .
        $locale->text("The preferred one is to install packages provided by " .
                      "your operating system distribution (e.g. Debian or " .
                      "RPM packages).") . qq|</p>

  <p>| . $locale->text("The second way is to use Perl's CPAN module and let " .
                       "it download and install the module for you.") .
        " " .
        $locale->text("Here's an example command line:") . qq|</p>

  <p><code>perl -MCPAN -e &quot;install Config::Std&quot;</code></p>

  <p>| . $locale->text("The third way is to download the module from the " .
                       "above mentioned URL and to install the module " .
                       "manually following the installations instructions " .
                       "contained in the source archive.") . qq|</p>

 </body>
</html>
|);

  $::dispatcher->end_request;
}

1;
