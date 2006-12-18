#!/usr/bin/perl -l
#
$db = "Pg";
$version = "0.2b";

($name,$exec) = @ARGV;
opendir SQLDIR, "sql/$db-upgrade" or die "Can't open sql dir";
@ups = sort(cmp_script_version grep(/$db-upgrade-.*?\.(sql|pl)$/, readdir(SQLDIR)));
closedir SQLDIR;
$up = $ups[-1];
$up =~ s/(.*de-)|(.sql$)|(.pl$)//g;
($from, $to) = split /-/, $up;
@next = split(/\./, $to);
$newsub = (pop @next)+1;
$next = join (".",@next).".".$newsub;

$name =~ /\.([^\.]+)$/;
$ext = $1;

print qq|
$db-upgrade Adder v$version

USE: pgupadd [file] [!]

Computes the next minor database version.
If [file] is given, proposes a copy command to add this file to the upgrade dir.
Use pgupadd [file] ! to let the adder copy and add it to svn for you (check the command first).

Current highest upgrade:   $up
Proposed next version:     $next
Proposed name for upgrade: $db-upgrade-$to-$next.$ext |;

$cmd = "cp $name sql/$db-upgrade/$db-upgrade-$to-$next.$ext; svn add sql/$db-upgrade/$db-upgrade-$to-$next.$ext;";
print qq|Proposed copy/add command:

$cmd
| if $name;

if ($name && !-f $name) {
  print qq|Warning! Given file does not exist!|;
  exit;
}

if ($name && -f "sql/$db-upgrade/$db-upgrade-$up.$ext" &&
    !`cmp $name sql/$db-upgrade/$db-upgrade-$up.$ext`) {
  print qq|Warning! Given file is identical to latest $db-upgrade!|;
  exit;
}

exec($cmd) if ($exec eq "!" and $name);


# both functions stolen and slightly modified from SL/User.pm
sub cmp_script_version {
  my ($a_from, $a_to, $b_from, $b_to);
  my ($i, $res_a, $res_b);
  my ($my_a, $my_b) = ($a, $b);

  $my_a =~ s/.*-upgrade-//;
  $my_a =~ s/.(sql|pl)$//;
  $my_b =~ s/.*-upgrade-//;
  $my_b =~ s/.(sql|pl)$//;
  ($my_a_from, $my_a_to) = split(/-/, $my_a);
  ($my_b_from, $my_b_to) = split(/-/, $my_b);

  $res_a = calc_version($my_a_from);
  $res_b = calc_version($my_b_from);

  if ($res_a == $res_b) {
    $res_a = calc_version($my_a_to);
    $res_b = calc_version($my_b_to);
  }

  return $res_a <=> $res_b;
}
sub calc_version {
  my $r = !(my @v = split(/\./, shift));
  map { $r = $r * 1000 + $v[$_] } 0..4;
  $r;
}
