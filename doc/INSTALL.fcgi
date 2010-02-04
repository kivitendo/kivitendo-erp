
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

Folgende Kombinationen funktionieren nicht:

 * Apache 2.2.11 (Ubuntu) + mod_fcgid:



=head2 Konfiguration des Webservers.

Zuerst muss das FastCGI-Modul aktiviert werden. Dies kann unter
Debian/Ubuntu z.B. mit folgendem Befehl geschehen:

  a2enmod fastcgi

Die Konfiguration für die Verwendung von Lx-Office mit FastCGI erfolgt
durch Anpassung der vorhandenen Alias- und Directory-Direktiven. Dabei
wird zwischen dem Installationspfad von Lx-Office im Dateisystem
("/path/to/lx-office-erp") und der URL unterschieden, unter der
Lx-Office im Webbrowser erreichbar ist ("/web/path/to/lx-office-erp").

  AliasMatch ^/web/path/to/lx-office-erp/[^/]+\.pl /path/to/lx-office-erp/dispatcher.fpl

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

Hierdurch wird nur ein zentraler Dispatcher gestartet. Alle Zugriffe
auf die einzelnen Scripte werden auf diesen umgeleitet. Dadurch, dass
zur Laufzeit öfter mal Scripte neu geladen werden, gibt es hier kleine
Performance-Einbußen. Trotzdem ist diese Variante einer globalen
Benutzung von "AddHandler fastcgi-script .pl" vorzuziehen.


=head2 Entwicklungsaspekte

Die AddHandler Direktive vom Apache ist entgegen der Dokumentation
anscheinend nicht lokal auf das Verzeichnis beschränkt sondern global im
vhost.

Wenn Änderungen in der Konfiguration von Lx-Office gemacht werden, oder wenn
Templates editiert werden muss der Server neu gestartet werden.

Es ist möglich die gleiche Lx-Office Version parallel unter cgi und fastcgi zu
betreiben. Da nimmt man Variante 2 wie oben beschrieben, und ändert die
AliasMatch Zeile auf eine andere URL, und lässt alle anderen URLs auch
weiterleiten:

  # Zugriff ohne FastCGI
  Alias /web/path/to/lx-office-erp /path/to/lx-office-erp

  # Zugriff mit FastCGI:
  AliasMatch ^/web/path/to/lx-office-erp-fcgi/[^/]+\.pl /path/to/lx-office-erp/dispatcher.fpl
  Alias       /web/path/to/lx-office-erp-fcgi/          /path/to/lx-office-erp/

Dann ist unter C</web/path/to/lx-office-erp/> die normale Version erreichbar,
und unter C</web/opath/to/lx-office-erp-fcgi/> die FastCGI Version.

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
schreiben, und C<exit> wird die Ausführung beenden.

Prinzipiell ist es kein Beinbruch, wenn sich der Prozess beendet, fcgi wird ihn
sofort neu starten. Allerdings sollte das die Ausnahme sein. Quintessenz: Bitte
kein C<warn> oder C<exit> benutzen, alle anderen Exceptionmechanismen sind ok.

=head3 Globale Variablen

Um zu vermeiden, dass Informationen von einem Request in einen anderen gelangen,
müssen alle globalen Variablen vor einem Request sauber initialisiert werden.
Das ist besonders wichtig im C<$::cgi> und C<$::auth> Objekt, weil diese nicht
gelöscht werden pro Instanz, sondern persistent gehalten werden.

Datenbankverbindungen wird noch ein Guide verfasst werden, wie man sichergeht,
dass man die richtige erwischt.

=head2 Performance und Statistiken

Die kritischen Pfade des Programms sind die Belegmasken, und unter diesen ganz
besonders die Verkaufsrechnungsmaske. Ein Aufruf der Rechnungsmaske in
Lx-Office 2.4.3 stable dauert auf einem Core2duo mit 2GB Arbeitsspeicher und
Ubuntu 9.10 eine halbe Sekunde. In der 2.6.0 sind es je nach Menge der
definierten Variablen 1-2s. Ab der Moose/Rose::DB Version sind es 5-6s.

Mit FastCGI ist die neuste Version auf 0,4 Sekunden selbst in den kritischen
Pfaden, unter 0,15 sonst.

=head2 Bekannte Probleme

Bei Administrativen Tätigkeiten werden in seltenen Fällen die Locales nicht
richtig geladen und die Maske erscheint in Englisch.

Die bin/mozilla und SL/ Scripte haben teilweise noch globale Variablen mit our
definiert, oder haben noch startup code der bei einbinden ausgeführt wird.
Beides muss überprüft werden.

Verkauf -> Rechnungen -> Weiter -> Neu erfassen Rechnung gibt einen Zugriffsfehler

Template Editor funktioniert nicht

