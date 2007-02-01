package SL::InstallationCheck;

use vars qw(@required_modules);

@required_modules = (
  { "name" => "Class::Accessor", "url" => "http://search.cpan.org/~kasei/" },
  { "name" => "CGI", "url" => "http://search.cpan.org/~lds/" },
  { "name" => "CGI::Ajax", "url" => "http://search.cpan.org/~bct/" },
  { "name" => "DBI", "url" => "http://search.cpan.org/~timb/" },
  { "name" => "DBD::Pg", "url" => "http://search.cpan.org/~dbdpg/" },
  { "name" => "HTML::Template", "url" => "http://search.cpan.org/~samtregar/" },
  { "name" => "Archive::Zip", "url" => "http://search.cpan.org/~adamk/" },
  { "name" => "Text::Iconv", "url" => "http://search.cpan.org/~mpiotr/" },
  { "name" => "Time::HiRes", "url" => "http://search.cpan.org/~jhi/" },
  );

sub module_available {
  my ($module) = @_;

  if (!defined(eval("require $module;"))) {
    return 0;
  } else {
    return 1;
  }
}

sub test_all_modules {
  my @missing_modules;

  map({ push(@missing_modules, $_) unless (module_available($_->{"name"})); }
      @required_modules);

  return @missing_modules;
}

1;
