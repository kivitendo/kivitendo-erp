use strict;

use lib 't';

use Support::Templates;

use File::Spec;
use File::Slurp;
use Template;
use Template::Provider;
use Test::More tests => ( scalar(@referenced_files));

my $template_path = 'templates/webpages/';

my $provider = Template::Provider->new({
  INTERPOLATE  => 0,
  EVAL_PERL    => 0,
  ABSOLUTE     => 1,
  CACHE_SIZE   => 0,
  PLUGIN_BASE  => 'SL::Template::Plugin',
  INCLUDE_PATH => '.:' . $template_path,
  COMPILE_DIR  => 'users/templates-cache-for-tests',
});

foreach my $ref (@Support::Templates::referenced_files) {
  my $file              = "${template_path}${ref}.html";
  my ($result, $not_ok) = $provider->fetch($file);

  if (!$not_ok) {
    ok(1, "${file} does not contain errors");

  } elsif (ref($result) eq 'Template::Exception') {
    print STDERR $result->as_string;
    ok(0, "${file} contains syntax errors");

  } else {
    die "Unknown result type: " . ref($result);
  }
}

exit 0;
