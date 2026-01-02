~ # cat /usr/local/bin/backup_db.sh
#!/bin/sh

: <<'QUICK_RESTORE_MANUAL'
==============================================================================
DB BACKUP RESTORE GUIDE (ENCRYPTED)
==============================================================================
1. DOWNLOAD: Get the .gz.enc file from Bunny.net Storage.
2. DECRYPT:  Run this command (replace <filename> and <your-password>):
   openssl enc -aes-256-cbc -d -pbkdf2 -pass "pass:<your-password>" \
   -in <filename>.gz.enc -out <filename>.gz
3. DECOMPRESS: gunzip <filename>.gz
4. IMPORT:   mariadb -u root < <filename>
==============================================================================
QUICK_RESTORE_MANUAL

# Environment & Security Check
if [ -z "$BUNNY_ACCESS_KEY" ] || [ -z "$BACKUP_ENCRYPTION_PASSWORD" ]; then
    echo "Error: BUNNY_ACCESS_KEY or BACKUP_ENCRYPTION_PASSWORD not set."
    exit 1
fi

STORAGE_ZONE="${BUNNY_STORAGE_ZONE:-rok-backups}"
DATE=$(date +%Y-%m-%d)
BACKUP_DIR="/tmp/db_backups_$DATE"
mkdir -p "$BACKUP_DIR"

# Identify databases to back up
DBS=$(mariadb -u root -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|sys)")

for DB in $DBS; do
    echo "Encrypting & Uploading: $DB"
    FINAL_FILE="${DB}_${DATE}.gz.enc"

    # Pipe: Dump -> Gzip -> OpenSSL AES-256 (Hardware Accelerated)
    # The password is pulled safely from $BACKUP_ENCRYPTION_PASSWORD
    mariadb-dump -u root "$DB" | \
    gzip | \
    openssl enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$BACKUP_ENCRYPTION_PASSWORD" -out "$BACKUP_DIR/$FINAL_FILE"

    # Upload to Bunny.net
    curl --request PUT \
         --url "https://storage.bunnycdn.com/${STORAGE_ZONE}/backups/${DATE}/${FINAL_FILE}" \
         --header "AccessKey: ${BUNNY_ACCESS_KEY}" \
         --header "Content-Type: application/octet-stream" \
         --upload-file "$BACKUP_DIR/$FINAL_FILE"

    # Save SSD life: Clean up local file immediately
    rm "$BACKUP_DIR/$FINAL_FILE"
done

rmdir "$BACKUP_DIR"
echo "Backup process complete. Verified separate encrypted files uploaded."
~ #