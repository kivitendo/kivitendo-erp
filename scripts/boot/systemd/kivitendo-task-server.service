[Unit]
Description=kivitendo background jobs server
Requires=postgresql.service
After=postgresql.service

[Service]
Type=forking
# Change the user to the one your web server runs as.
User=www-data
# Change these two to point to the kivitendo "task_server.pl" location.
ExecStart=/var/www/kivitendo-erp/scripts/task_server.pl start
ExecStop=/var/www/kivitendo-erp/scripts/task_server.pl stop
Restart=always
ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
