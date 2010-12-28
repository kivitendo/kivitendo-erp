
Diese Datei ist in Plain Old Documentation geschrieben. Mit

> perldoc INSTALL.fcgi

ist sie deutlich leichter zu lesen.

=head1 FastCGI für Lx-Office

=head2 Was ist FastCGI?

Direkt aus L<http://de.wikipedia.org/wiki/FastCGI> kopiert:

  FastCGI ist ein Standard für die Einbindung externer Software zur Generierung
  dynamischer Webseiten in einem Webserver. FastCGI ist vergleichbar zum Common
  Gateway Interface (CGI), wurde jedoch entwickelt, um dessen
  Performance-Probleme zu umgehen.


=head2 Warum FastCGI?

Perl Programme (wie Lx-Office eines ist) werden nicht statisch kompiliert.
Stattdessen werden die Quelldateien bei jedem Start übersetzt, was bei kurzen
Laufzeiten einen Großteil der Laufzeit ausmacht. Während SQL Ledger einen
Großteil der Funktionalität in einzelne Module kapselt, um immer nur einen
kleinen Teil laden zu müssen, ist die Funktionalität von Lx-Office soweit
gewachsen, dass immer mehr Module auf den Rest des Programms zugreifen.
Zusätzlich benutzen wir umfangreiche Bibliotheken um Funktionaltät nicht selber
entwickeln zu müssen, die zusätzliche Ladezeit kosten. All dies führt dazu dass
ein Lx-Office Aufruf der Kernmasken mittlerweile deutlich länger dauert als
früher, und dass davon 90% für das Laden der Module verwendet wird.

Mit FastCGI werden nun die Module einmal geladen, und danach wird nur die
eigentliche Programmlogik ausgeführt.

=head2 Kombinationen aus Webservern und Plugin.

Folgende Kombinationen sind getestet:

 * Apache 2.2.11 (Ubuntu) und mod_fastcgi.
 * Apache 2.2.11 (Ubuntu) und mod_fcgid:

Als Perl Backend wird das Modul FCGI.pm verwendet. Vorsicht: FCGI 0.69 und
höher ist extrem strict in der Behandlung von Unicode, und verweigert bestimmte
Eingaben von Lx-Office. Solange diese Probleme nicht behoben sind, muss auf die
Vorgängerversion FCGI 0.68 ausgewichen werden.

Mit cpan lässt sie sich wie folgt installieren:

 force install M/MS/MSTROUT/FCGI-0.68.tar.gz

=head2 Konfiguration des Webservers.

Bevor Sie versuchen eine Lx-Office Installation unter FCGI laufen zu lassen,
empfliehlt es sich die Installation ersteinmal unter CGI aufzusetzen. FCGI
macht es nicht einfach Fehler zu debuggen die beim ersten aufsetzen auftreten
können. Sollte die Installation schon funktionieren, lesen Sie weiter.

Zuerst muss das FastCGI-Modul aktiviert werden. Dies kann unter
Debian/Ubuntu z.B. mit folgendem Befehl geschehen:

  a2enmod fastcgi

bzw.

  a2enmod fcgid

Die Konfiguration für die Verwendung von Lx-Office mit FastCGI erfolgt
durch Anpassung der vorhandenen Alias- und Directory-Direktiven. Dabei
wird zwischen dem Installationspfad von Lx-Office im Dateisystem
("/path/to/lx-office-erp") und der URL unterschieden, unter der
Lx-Office im Webbrowser erreichbar ist ("/web/path/to/lx-office-erp").

Folgendes Template funktioniert mit mod_fastcgi:

  AliasMatch ^/web/path/to/lx-office-erp/[^/]+\.pl /path/to/lx-office-erp/dispatcher.fpl
  Alias       /web/path/to/lx-office-erp/          /path/to/lx-office-erp/

  <Directory /path/to/lx-office-erp>
    AllowOverride All
    AddHandler fastcgi-script .fpl
    Options ExecCGI Includes FollowSymlinks
    Order Allow,Deny
    Allow from All
  </Directory>

  <DirectoryMatch /path/to/lx-office-erp/users>
    Order Deny,Allow
    Deny from All
  </DirectoryMatch>

...und für mod_fcgid muss die erste Zeile geändert werden in:

  AliasMatch ^/web/path/to/lx-office-erp/[^/]+\.pl /path/to/lx-office-erp/dispatcher.fcgi


Hierdurch wird nur ein zentraler Dispatcher gestartet. Alle Zugriffe
auf die einzelnen Scripte werden auf diesen umgeleitet. Dadurch, dass
zur Laufzeit öfter mal Scripte neu geladen werden, gibt es hier kleine
Performance-Einbußen. Trotzdem ist diese Variante einer globalen
Benutzung von "AddHandler fastcgi-script .pl" vorzuziehen.


Es ist möglich die gleiche Lx-Office Version parallel unter cgi und fastcgi zu
betreiben. Dafür bleiben Directorydirektiven bleiben wie oben beschrieben, die
URLs werden aber umgeleitet:

  # Zugriff ohne FastCGI
  Alias       /web/path/to/lx-office-erp                /path/to/lx-office-erp

  # Zugriff mit FastCGI:
  AliasMatch ^/web/path/to/lx-office-erp-fcgi/[^/]+\.pl /path/to/lx-office-erp/dispatcher.fpl
  Alias       /web/path/to/lx-office-erp-fcgi/          /path/to/lx-office-erp/

Dann ist unter C</web/path/to/lx-office-erp/> die normale Version erreichbar,
und unter C</web/opath/to/lx-office-erp-fcgi/> die FastCGI Version.

Achtung:

Die AddHandler Direktive vom Apache ist entgegen der Dokumentation
anscheinend nicht lokal auf das Verzeichnis beschränkt sondern global im
vhost.

=head2 Entwicklungsaspekte

Wenn Änderungen in der Konfiguration von Lx-Office gemacht werden, muss der
Server neu gestartet werden.

Bei der Entwicklung für FastCGI ist auf ein paar Fallstricke zu achten. Dadurch
dass das Programm in einer Endlosschleife läuft, müssen folgende Aspekte
geachtet werden:

=head3 Programmende und Ausnahmen: C<warn>, C<die>, C<exit>, C<carp>, C<confess>

Fehler, die dass Programm normalerweise sofort beenden (fatale Fehler), werden
mit dem FastCGI Dispatcher abgefangen, um das Programm am Laufen zu halten. Man
kann mit C<die>, C<confess> oder C<carp> Fehler ausgeben, die dann vom Dispatcher
angezeigt werden. Die Lx-Office eigene C<$::form->error()> tut im Prinzip das
Gleiche, mit ein paar Extraoptionen. C<warn> und C<exit> hingegen werden nicht
abgefangen. C<warn> wird direkt nach STDERR, also in Server Log eine Nachricht
schreiben (sofern in der Konfiguration nicht die Warnungen in das Lx-Office Log
umgeleitet wurden), und C<exit> wird die Ausführung beenden.

Prinzipiell ist es kein Beinbruch, wenn sich der Prozess beendet, fcgi wird ihn
sofort neu starten. Allerdings sollte das die Ausnahme sein. Quintessenz: Bitte
kein C<exit> benutzen, alle anderen Exceptionmechanismen sind ok.

=head3 Globale Variablen

Um zu vermeiden, dass Informationen von einem Request in einen anderen gelangen,
müssen alle globalen Variablen vor einem Request sauber initialisiert werden.
Das ist besonders wichtig im C<$::cgi> und C<$::auth> Objekt, weil diese nicht
gelöscht werden pro Instanz, sondern persistent gehalten werden.

In C<SL::Dispatcher> gibt es einen sauber abgetrennten Block der alle
kanonischen globalen Variablen listet und erklärt. Bitte keine anderen
einführen ohne das sauber zu dokumentieren.

Datenbankverbindungen wird noch ein Guide verfasst werden, wie man sichergeht,
dass man die richtige erwischt.

=head2 Performance und Statistiken

Die kritischen Pfade des Programms sind die Belegmasken, und unter diesen ganz
besonders die Verkaufsrechnungsmaske. Ein Aufruf der Rechnungsmaske in
Lx-Office 2.4.3 stable dauert auf einem Core2duo mit 4GB Arbeitsspeicher und
Ubuntu 9.10 eine halbe Sekunde. In der 2.6.0 sind es je nach Menge der
definierten Variablen 1-2s. Ab der Moose/Rose::DB Version sind es 5-6s.

Mit FastCGI ist die neuste Version auf 0,26 Sekunden selbst in den kritischen
Pfaden, unter 0,15 sonst.

=head2 Bekannte Probleme

=head3 Encoding Awareness

UTF-8 kodierte Installationen sind sehr anfällig gegen fehlerhfate Encodings
unter FCGI. latin9 Installationen behandeln falsch kodierte Zeichen eher
unwissend, und geben sie einfach weiter. UTF-8 verweigert bei fehlerhaften
Programmpfaden kurzerhand aus ausliefern. Es wird noch daran gearbeitet alles
Fehler da zu beseitigen.

