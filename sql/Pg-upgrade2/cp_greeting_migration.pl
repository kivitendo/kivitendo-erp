# @tag: cp_greeting_migration
# @description: Migration of cp_greeting to cp_gender
# @depends: generic_translations

die("This script cannot be run from the command line.") unless ($main::form);


sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub do_query {
  my ($query, $may_fail) = @_;

  if (!$dbh->do($query)) {
    mydberror($query) unless ($may_fail);
    $dbh->rollback();
    $dbh->begin_work();
  }
}


sub query_result {

  # list of all entries where cp_greeting is empty, meaning can't determine gender from parsing Herr/Frau/...
  # this assumes cp_greeting still exists, i.e. gender.sql was not run yet
  my $gender_table;

  my $sql2 = "select cp_id,cp_givenname,cp_name,cp_title,cp_greeting from contacts where not (cp_greeting ILIKE '%frau%' OR cp_greeting ILIKE '%herr%' or cp_greeting ILIKE '%mrs.%' or cp_greeting ILIKE '%miss%') ";
  my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr();
  $sth2->execute() or die $dbh->errstr(); 

  my $i = 1;   
  $gender_table .= '<table border="1"><tr><th>cp_givenname</th><th>cp_name</th><th>cp_title</th><th>cp_greeting</th><th><translate>male/female</th></tr>';
  $gender_table .= "\n";

  while (my $row = $sth2->fetchrow_hashref()) {
    if ( main::form->{"gender_$i"} eq "f" ) {
			$mchecked = "";
			$fchecked = "checked";
	} else {
			$mchecked = "checked";
			$fchecked = "";
	};
    
   $gender_table .= "<tr><input type=hidden name=\"cp_id_$i\" value=\"$row->{cp_id}\"> <td>$row->{cp_givenname}</td> <td>$row->{cp_name}</td> <td>$row->{cp_title} </td> <td>$row->{cp_greeting} </td><td> <input type=\"radio\" name=\"gender_$i\" value=\"m\" $mchecked> <input type=\"radio\" name=\"gender_$i\" value=\"f\" $fchecked></td></tr>\n";
   $i++;
  };

  $gender_table .= "<input type=hidden name=\"number_of_gender_entries\" value=\"$i\">"; 
  $gender_table .= "</table>";

  $main::form->{gender_table} = $gender_table;

  my $title_table;
  
  my $sql3 = "select cp_id,cp_givenname,cp_name,cp_title,cp_greeting from contacts where not ( (cp_greeting ILIKE '%frau%' OR cp_greeting ILIKE '%herr%' or cp_greeting ILIKE '%mrs.%' or cp_greeting ILIKE '%miss%')) and not (cp_greeting like ''); ";

  my $sth3 = $dbh->prepare($sql3) or die $dbh->errstr();
  $sth3->execute() or die $dbh->errstr(); 

  $title_table = '<table border="1"><tr><th>cp_givenname</th><th>cp_name</th><th>cp_title</th><th>cp_greeting</th><th>cp_title new</th></tr>';

  my $j = 1;
  while (my $row = $sth3->fetchrow_hashref()) {
# Vorschlagsfeld fuer neuen Titel mit Werten von cp_greeting und cp_title vorbelegen
		  my $value = "$row->{cp_greeting}";
		  $value .= " " if $row->{cp_greeting};
		  $value .= "$row->{cp_title}";

		  $title_table .= "<tr> <td><input type=hidden name=\"cp_id_title_$j\" value=$row->{cp_id}> $row->{cp_givenname}</td> <td>$row->{cp_name}</td><td>$row->{cp_title}</td> <td>$row->{cp_greeting}</td><td><input type=\"text\" id=\"cp_title_$j\" name=\"cp_name_$j\" value=\"$value\"></td> </tr>\n";
		  $j++;
  };

  $title_table .= "<input type=hidden name=\"number_of_title_entries\" value=\"$j\">"; 
  $title_table .= "</table>";
  $main::form->{title_table} = $title_table;

};



sub print_question {
  query_result();
  # parse html form in /templates/webpages/dbupgrade/cp_greeting_update_form
  print $main::form->parse_html_template("dbupgrade/cp_greeting_update_form");
}

sub do_update {
  # main function

  # first of all check if gender.sql was already run and thus cp_gender exists
  # if it exists there is no need for this update anymore, so return
  # without doing anything

  my $column_exists = 1;
  if (!$dbh->do("SELECT cp_gender FROM contacts LIMIT 1")) {
    $dbh->rollback();
    $dbh->begin_work();
    $column_exists = 0;
  }
  return 1 if $column_exists;


  if (!$main::form->{do_migrate}) {
    # case 1: first call of page
    set_default_greetings();
    print_question();
    return 2;
  } else {
    # case 2: submit button was pressed, hidden field do_migrate was set
    migrate_data();
  };

return 1;

}

sub migrate_data {

  my $sqlcode = <<EOF
ALTER TABLE contacts ADD COLUMN cp_gender char(1);
UPDATE contacts SET cp_gender = 'm';
UPDATE contacts SET cp_gender = 'f'
  WHERE (cp_greeting ILIKE '%frau%')
     OR (cp_greeting ILIKE '%mrs.%')
     OR (cp_greeting ILIKE '%miss%');
EOF
;

  for (my $i = 1; $i <= $main::form->{number_of_gender_entries}; $i++ ) {
    next unless $main::form->{"cp_id_$i"};
	if ( $main::form->{"gender_$i"} eq "f" ) {
	  $sqlcode .= "UPDATE contacts SET cp_gender = \'f\' WHERE cp_id = $main::form->{\"cp_id_$i\"};\n";
    };
  };

  for (my $i = 1; $i <= $main::form->{number_of_title_entries}; $i++ ) {
    next unless $main::form->{"cp_id_title_$i"} and $main::form->{"cp_id_$i"};
	$sqlcode .= "UPDATE contacts SET cp_title = \'$main::form->{\"cp_name_$i\"}\' WHERE cp_id = $main::form->{\"cp_id_$i\"};\n";
  };
  $sqlcode .= "ALTER TABLE contacts DROP COLUMN cp_greeting;";

  # insert chosen default values
  $sqlcode .= "INSERT INTO generic_translations (translation_type, translation) VALUES ('greetings::male','$main::form->{default_male}');";
  $sqlcode .= "INSERT INTO generic_translations (translation_type, translation) VALUES ('greetings::female','$main::form->{default_female}');";

  my $query  = $sqlcode;
  do_query($query);
};



sub set_default_greetings {
  # add html input boxes to template so user can specify default greetings

   my $default_male = "Herr";
   my $default_female = "Frau";

   my $default_greeting_text_male = "<input type=\"text\" id=\"default_male\" name=\"default_male\" value=\"$default_male\"><br>";
   my $default_greeting_text_female = "<input type=\"text\" id=\"default_female\" name=\"default_female\" value=\"$default_female\"><br>";
   $main::form->{default_greeting_text_male} = $default_greeting_text_male;
   $main::form->{default_greeting_text_female} = $default_greeting_text_female;
};


return do_update();

