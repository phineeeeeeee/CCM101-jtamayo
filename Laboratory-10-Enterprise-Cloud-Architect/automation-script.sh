```text
#!/bin/bash

if mountpoint -q /mnt/backup; then
  BACKUP_DIR="/mnt/backup/ccm101-backups"
else
  BACKUP_DIR="$HOME/ccm101-backups"
fi

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p "$BACKUP_DIR"

docker exec ccm101-mysql sh -c 'mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" wordpress' \
  > "$BACKUP_DIR/wordpress_${DATE}.sql"

find "$BACKUP_DIR" -name "wordpress_*.sql" -mtime +7 -delete
echo "$(date +"%Y-%m-%d %H:%M:%S") backup saved to $BACKUP_DIR" >> "$HOME/backup.log"
```
