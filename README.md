# Backup Scripts

A collection of production-ready automation and backup scripts for managing services on a Proxmox and Alpine Linux.

## Features

- **Encrypted Backups**: Automated AES-256-CBC encryption via OpenSSL.
- **Off-site Storage**: Seamless integration with Bunny.net Storage Zones.
- **Zero-Password Security**: Utilizes MariaDB Unix Socket authentication.
- **Granular Recovery**: Backs up each database into its own separate compressed file.

---

## Databases Backup Script

The primary backup engine is located at `/usr/local/bin/backup_db.sh`.

### 1. Prerequisites

Ensure the following packages are installed on your Alpine container:

```bash
apk add curl gzip openssl mariadb-client
```

### 2. Security Setup (Unix Socket)

To allow the script to run as root without a password file:

```sql
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD '<your-database-password>';
```

### 3. Environment Variables

The script relies on these environment variables for sensitive credentials:

| Variable | Description |
| :--- | :--- |
| `BUNNY_ACCESS_KEY` | Your Bunny.net Storage API Key |
| `BUNNY_STORAGE_ZONE` | Your Storage Zone Name (e.g., `rok-backups`) |
| `BUNNY_HOSTNAME` | Bunny.net Hostname (usually `storage.bunnycdn.com`) |
| `BACKUP_ENCRYPTION_PASSWORD` | Password for AES-256 encryption |

---

## Restore Manual

In the event of data loss, follow these steps to decrypt and restore your databases.

### Step 1: Decrypt the Archive

Run this command for each file you wish to restore (replace placeholders):

```bash
openssl enc -aes-256-cbc -d -pbkdf2 -pass "pass:<your-password>" \
-in <filename>.gz.enc -out <filename>.gz
```

### Step 2: Decompress and Import

```bash
# Decompress the SQL file
gunzip <filename>.gz

# Import into MariaDB
mariadb -u root < <filename>
```

---

## Automation (Cron)

The script is configured to run every 6 hours. To verify or update the schedule, use `crontab -e`:

```cron
0 */6 * * * BUNNY_ACCESS_KEY="..." BACKUP_ENCRYPTION_PASSWORD="..." /usr/local/bin/backup_db.sh >> /var/log/db_backup.log 2>&1
```
