# kivitendo-erp
Web-based ERP system for the German market

Anmerkungen jan:

1) send_email macht nicht das was es soll, es sendet nicht nur stumpf eine E-Mail, sondern prüft auch auf den Zustand des Background Jobs.
   Das ist aber eher in der Verantwortung der aufrufenden Routine, damit das besser abgegrenzt ist:
   

 ```@@ -56,9 +57,6 @@ sub _email_user {
 sub send_email {
   my ($self) = @_;
 
 -  my @ids = @{$self->{job_obj}->data_as_hash->{ids}};
 -  return unless (scalar @ids && $self->{config} && $self->{config}->{send_email_to});
 -
   my $user  = $self->_email_user;
   my $email = $self->{job_obj}->data_as_hash->{mail_to} ? $self->{job_obj}->data_as_hash->{mail_to}
             : $user                                     ? $user->get_config_value('email')
 @@ -140,13 +138,15 @@ sub run {
 
   $self->check_below_minimum_stock();
 
 -  $self->send_email();
 -
    my $data = $job_obj->data_as_hash;
 -  die $data->{errors} if $data->{errors};
 +  # errors indicate we have to inform the user
 +  if ($data->{errors}) {
 +    $self->send_email();
 +    die $data->{errors} if $data->{errors};
 +  }
 ```


 2) Die Routine send_email springt raus, falls sich in der kivitendo.conf kein mit einer gültigen E-Mail-Adresse befindet.
   Das ist für den kivi-Admin schwierig zu konfigurieren und für Admins die nur an der Oberfläche administrieren überhaupt einstellbar
   Ferner wird ja im weiteren Verlauf auf andere Mail-Adressen geprüft und _email_user ist ja auch schon ausgelagert.
   
   2.1) Prüfung auf valide Konfig in methode
   
 ```sub _email_user {
    my ($self) = @_;
 +  return unless ($self->{config} && $self->{config}->{send_email_to});
    $self->{email_user} ||= SL::DB::Manager::AuthUser->find_by(login => $self->{config}->{send_email_to});
  }
 ```
  2.2) Nicht zu früh bei send_email abbrechen:
  
   ```sub send_email {
   my ($self) = @_;
 
 -  my @ids = @{$self->{job_obj}->data_as_hash->{ids}};
 -  return unless (scalar @ids && $self->{config} && $self->{config}->{send_email_to});
```

 3.) Kosmetik
 ```-  return ;
 +  return;
 ```
  
  

