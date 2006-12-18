#!/usr/bin/perl -w

$| = 1;

my @required_modules = (
  { "name" => "Class::Accessor", "url" => "http://search.cpan.org/~kasei/" },
  { "name" => "CGI", "url" => "http://search.cpan.org/~lds/" },
  { "name" => "CGI::Ajax", "url" => "http://search.cpan.org/~bct/" },
  { "name" => "DBI", "url" => "http://search.cpan.org/~timb/" },
  { "name" => "DBD::Pg", "url" => "http://search.cpan.org/~dbdpg/" },
  { "name" => "HTML::Template", "url" => "http://search.cpan.org/~samtregar/" },
  { "name" => "Archive::Zip", "url" => "http://search.cpan.org/~adamk/" },
  { "name" => "Text::Iconv", "url" => "http://search.cpan.org/~mpiotr/" },
  );

sub module_available {
  my ($module) = @_;

  if (!defined(eval("require $module;"))) {
    return 0;
  } else {
    return 1;
  }
}

foreach my $module (@required_modules) {
  print("Looking for $module->{name}...");
  if (!module_available($module->{"name"})) {
    print(" NOT found\n" .
          "  The module '$module->{name}' is not available on your system.\n" .
          "  Please install it with the CPAN shell, e.g.\n" .
          "    perl -MCPAN -e install \"install $module->{name}\"\n" .
          "  or download it from this URL and install it manually:\n" .
          "    $module->{url}\n\n");
  } else {
    print(" ok\n");
  }
}
