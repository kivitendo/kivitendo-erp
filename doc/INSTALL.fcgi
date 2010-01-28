
1. Was ist FCGI?



2. Kombinationen aus Webservern und Plugin.

Folgende Kombinationen sind getestet:

- Apache 2.2.11 (Ubuntu) und mod_fastcgi.

Folgende Kombinationen funktionieren nicht:

- Apacje 2.2.11 (Ubuntu) + mod_fcgid:



3. Konfiguration des Webservers.

Variante 1:

  AddHandler fastcgi-script .pl

Variante 2:

AliasMatch ^/web/path/to/lx-office-erp/[^/]+\.pl /path/to/lx-office-erp/dispatcher.fpl

<Directory /path/to/lx-office-erp>
  AllowOverride All
  AddHandler fastcgi-script .fpl
  Options ExecCGI Includes FollowSymlinks
  Order Allow,Deny
  Allow from All
</Directory>

<DirectoryMatch //.*/users>
  Order Deny,Allow
  Deny from All
</DirectoryMatch>




Variante 1 startet einfach jeden Lx-Office Request als fcgi Prozess. Für sehr große Installationen ist das die schnellste Version, benötigt aber sehr viel Arbeitspseicher (ca. 2GB).

Variante 2 startet nur einen zentralen Dispatcher und lenkt alle Scripte auf diesen. Dadurch dass zur Laufzeit öfter mal Scripte neu geladen werden gibt es hier kleine Performance Einbußen.



4. TODO

4.1. Fehlermeldungen, die per $form->error() ausgegeben werden, werden momentan doppelt angezeigt.
