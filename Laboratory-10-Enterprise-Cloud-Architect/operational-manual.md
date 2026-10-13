# CCM101 – Cloud Computing

# Enterprise Cloud Architect Operational Manual

| Item | Details |
| --- | --- |
| Project | Secure Multi-Tier Web Application |
| Application Stack | WordPress + MySQL |
| Prepared by | Acerit, Suzette; Apolinar, Cyriel; Castillo, Gammie; Godoy, Rose Ann; Tamayo, Josephine |
| Section | BSIT 4A |
| Instructor | Jenkielyn C. Torres |
| Date | October 2026 |

---

## 1. Project Overview

This manual explains how the secure multi-tier web application was built, deployed, secured, backed up, and maintained. The application uses WordPress with a MySQL database. Both run as Docker containers inside an Ubuntu Server 24.04 LTS virtual machine on VirtualBox. The virtual machine is stored on the laptop's internal drive.

Follow the sections in order and test each part before moving to the next. Replace `YOURUSER` with your GitHub username and `youruser` with the Ubuntu username you created. Keep all passwords private.

### 1.1 Project at a glance

| Item | Choice |
| --- | --- |
| Application stack | WordPress + MySQL |
| Hypervisor | VirtualBox (Type 2) |
| Guest OS | Ubuntu Server 24.04 LTS |
| VM storage | Laptop internal drive (`C:\CCM101\VMs`) |
| Network | NAT with port forwarding: host `2222` to guest `22`, host `8080` to guest `80` |
| Security | UFW, default deny, allow ports 22 and 80 only |
| Automation | Bash backup script and cron at 11:00 PM |
| Repository lab folder | `Laboratory-10-Enterprise-Cloud-Architect` |

### 1.2 Folder layout on the laptop

```text
C:\CCM101\
├── ISO\          Ubuntu Server ISO
├── VMs\          CCM101-Ubuntu-Server and backup-disk.vdi
├── Repo\         GitHub repository clone
├── Screenshots\  Proof for the manual
└── VM-Backups\   Exported .OVA copy
```

## 2. Infrastructure and Architecture

The architecture diagram shows the layers from the host laptop to the application containers. The browser and terminal reach the VM through VirtualBox NAT port forwarding. UFW protects the Ubuntu VM, and Docker runs the two containers on a private backend network.

### 2.1 Layers, outside to inside

| Layer | Role |
| --- | --- |
| Host laptop (Windows 11) | Contains the internal drive and VirtualBox Type 2 hypervisor. |
| Internal drive (`C:`) | Holds the VM disk and `backup-disk.vdi` inside `C:\CCM101\VMs`. |
| VirtualBox | Runs the Ubuntu Server virtual machine. |
| UFW firewall | Uses default deny and allows ports 22 and 80. |
| Docker backend network | Connects the WordPress and MySQL containers privately. |
| Containers | `ccm101-wordpress` serves the site; `ccm101-mysql` stores the database. |
| Persistent volumes | `wordpress_data` and `db_data` keep data outside the containers. |

### 2.2 Traffic paths

| From | To | Used for |
| --- | --- | --- |
| Browser at `localhost:8080` | VM port 80 | WordPress website |
| Terminal at `localhost:2222` | VM port 22 | SSH administration |
| Cron script | `/mnt/backup` | Database backup storage |

## 3. Required Resources

### 3.1 Hardware

- Laptop with at least 8 GB of RAM. Allocate 4 GB to the VM, or 3 GB if the laptop has limited memory.
- At least 60 GB free on the `C:` drive. The 40 GB VM disk and 10 GB backup disk are dynamically allocated and grow as needed.
- Virtualization enabled in BIOS (Intel VT-x or AMD SVM Mode).

### 3.2 Software and accounts

| Software or account | Source and notes |
| --- | --- |
| VirtualBox | `virtualbox.org`; keep the default options and accept driver prompts. |
| Git for Windows | `git-scm.com`; default options. |
| VS Code | `code.visualstudio.com`; default options. |
| draw.io | `app.diagrams.net` or the desktop app. |
| Ubuntu Server ISO | `ubuntu.com/download/server`, version 24.04 LTS. |
| GitHub account | `github.com` |
| KillerCoda account | `killercoda.com`; can sign in with GitHub. |

### 3.3 Check that virtualization is enabled

1. Press `Ctrl+Shift+Esc` to open Task Manager.
2. Select **Performance**, then **CPU**.
3. Check that **Virtualization** says **Enabled**.
4. If it says Disabled, restart the computer and enter BIOS using the appropriate key (often F2, F10, Delete, or Esc). Enable Intel VT-x or AMD SVM Mode, then save and exit.

### 3.4 Set the Git identity

Use your own name and email address:

```bash
git config --global user.name "YOUR NAME"
git config --global user.email "YOUR EMAIL"
```

## 4. VM and Network Setup

### 4.1 Prepare the project folders

Run the following in PowerShell, then move the Ubuntu ISO from Downloads into `C:\CCM101\ISO`.

```powershell
mkdir C:\CCM101\ISO, C:\CCM101\VMs, C:\CCM101\Repo, C:\CCM101\Screenshots, C:\CCM101\VM-Backups
```

In VirtualBox, open **File → Preferences → General** and set **Default Machine Folder** to `C:\CCM101\VMs`.

Clone the repository and create the lab folder. Replace the repository URL and folder name if yours differs.

```powershell
cd C:\CCM101\Repo
git clone https://github.com/YOURUSER/CCM101-YOURREPO.git
cd CCM101-YOURREPO
mkdir Laboratory-10-Enterprise-Cloud-Architect
```

### 4.2 Create the virtual machine

1. Click **New**.
2. Name the VM `ccm101-server` and set its folder to `C:\CCM101\VMs`.
3. Select the Ubuntu Server ISO from `C:\CCM101\ISO`.
4. Choose **Linux** and **Ubuntu (64-bit)**.
5. Tick **Skip Unattended Installation**.
6. Set memory to 4000 MB and processors to 4.
7. Create a 40 GB virtual hard disk, dynamically allocated (do not pre-allocate the full size), then finish.

### 4.3 Configure NAT and port forwarding

Before the first boot, select the VM and open **Settings → Network → Adapter 1**. Set **Attached to** to **NAT**, expand **Advanced**, and select **Port Forwarding**. Leave Host IP and Guest IP blank.

| Name | Protocol | Host port | Guest port |
| --- | --- | ---: | ---: |
| ssh | TCP | 2222 | 22 |
| web | TCP | 8080 | 80 |

### 4.4 Install Ubuntu Server

1. Start the VM and choose **Try or Install Ubuntu Server**.
2. Select English and English (US) keyboard settings.
3. Keep the default DHCP network, leave the proxy blank, and use the default mirror.
4. Select the entire 40 GB disk and keep the default LVM layout.
5. Create your profile, set the server name to `ccm101-server`, and create a private username and password.
6. Skip Ubuntu Pro for now, tick **Install OpenSSH server**, and select no featured snaps.
7. Reboot after installation. If the VM returns to the installer, shut it down and remove the ISO under **Settings → Storage**.

### 4.5 First login and update

Run these commands in the Ubuntu console:

```bash
sudo apt update
sudo apt upgrade -y
ip addr
```

NAT commonly assigns an address such as `10.0.2.15` to the `enp0s3` interface.

### 4.6 Connect with SSH from Windows

Open PowerShell on the laptop. Type `yes` at the fingerprint prompt, then enter your Ubuntu password. Use this SSH window for later commands so copy and paste works.

```powershell
ssh -p 2222 youruser@127.0.0.1
```

Replace `youruser` with the Ubuntu username you created.

### 4.7 Create and mount the virtual backup disk

Shut the VM down with `sudo poweroff`. In VirtualBox, select the VM and open **Settings → Storage**. Add a hard disk to the SATA controller and create a 10 GB VDI named `backup-disk` in `C:\CCM101\VMs`. Choose dynamically allocated storage. Start the VM and reconnect over SSH.

Identify the new empty disk, usually `/dev/sdb`. Check its size carefully because formatting the wrong disk erases data.

```bash
lsblk
```

Format and mount the backup disk:

```bash
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /mnt/backup
sudo mount /dev/sdb /mnt/backup
sudo chown $USER:$USER /mnt/backup
sudo blkid /dev/sdb
```

Copy the UUID shown by `blkid`, then edit `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

Add a line at the bottom using your actual UUID:

```text
UUID=YOUR-UUID-HERE /mnt/backup ext4 defaults,nofail 0 2
```

Save with `Ctrl+O`, press Enter, then exit with `Ctrl+X`. Test the entry:

```bash
sudo mount -a
df -h | grep /mnt/backup
```

## 5. Docker Deployment

### 5.1 Install Docker and Compose

The manual uses Docker's official repository first:

```bash
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

If the Compose package is unavailable, use the fallback packages:

```bash
sudo apt install -y docker.io docker-compose-v2
```

### 5.2 Allow your user to run Docker

```bash
sudo usermod -aG docker $USER
sudo systemctl enable docker
exit
```

Reconnect over SSH so the group change takes effect:

```powershell
ssh -p 2222 youruser@127.0.0.1
```

Verify the installation:

```bash
docker --version
docker compose version
docker run hello-world
```

### 5.3 Create the project folder and `.env` file

The `.env` file keeps database passwords out of the Compose file. Use strong passwords and never commit the real `.env` file to GitHub.

```bash
mkdir -p ~/ccm101-final-requirement
cd ~/ccm101-final-requirement
nano .env
```

Add the following, replacing the example passwords with strong private values:

```dotenv
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=REPLACE_WITH_A_STRONG_PASSWORD
MYSQL_ROOT_PASSWORD=REPLACE_WITH_A_DIFFERENT_STRONG_PASSWORD
```

### 5.4 Create `docker-compose.yml`

Create the file:

```bash
nano docker-compose.yml
```

Paste this configuration:

```yaml
services:
  db:
    image: mysql:8.0
    container_name: ccm101-mysql
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - backend
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 10

  wordpress:
    image: wordpress:latest
    container_name: ccm101-wordpress
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE}
      WORDPRESS_DB_USER: ${MYSQL_USER}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - backend

volumes:
  db_data:
  wordpress_data:

networks:
  backend:
```

Only WordPress publishes a port. MySQL has no published host port and can be reached only through the private Docker network. The health check makes WordPress wait until the database is ready.

### 5.5 Create a safe example environment file

Create a sanitized version for the repository:

```bash
sed 's/=.*/=CHANGE_ME/' .env > .env.example
cat .env.example
```

Commit `.env.example`, not `.env`.

### 5.6 Start the stack

```bash
docker compose up -d
docker compose ps
```

Both containers should be running. The database may take around 30 seconds to report healthy.

### 5.7 Open WordPress

1. Open a browser on the laptop and visit `http://localhost:8080`.
2. Choose a language and continue.
3. Enter the site title `Cloud Computing Application`, create an administrator username and strong password, and provide your email.
4. Install WordPress and log in.
5. Create and publish a test post titled **TAMAYO GROUP** that lists the group members.

## 6. Persistent Storage and the Reboot Test

The database and WordPress files are stored in Docker volumes. These volumes survive container removal and VM reboots, as long as the volumes are not explicitly deleted.

| Volume | Container path | Purpose |
| --- | --- | --- |
| `db_data` | `/var/lib/mysql` | MySQL database files |
| `wordpress_data` | `/var/www/html` | WordPress files, themes, and uploads |

### 6.1 Container restart test

```bash
docker compose down
docker compose up -d
```

Refresh `http://localhost:8080` and confirm that the test post is still present. Do not add `-v` to `docker compose down`, because that removes the Compose volumes.

### 6.2 VM reboot test

```bash
sudo reboot
```

Wait about one minute, reconnect over SSH, and run:

```bash
docker ps
docker volume ls
df -h | grep /mnt/backup
```

Both containers should be running because they use `restart: unless-stopped`. The volumes should be listed and the backup disk should be mounted. Docker prefixes volume names with the project folder name, so the volumes may appear as `ccm101-final-requirement_db_data` and `ccm101-final-requirement_wordpress_data`. Refresh `localhost:8080` and confirm that the test post survived.

## 7. Security Hardening (UFW)

UFW uses a default-deny policy for incoming traffic. Only SSH (port 22) and HTTP (port 80) are allowed. MySQL (port 3306) is not opened because it communicates with WordPress through the Docker network.

Allow SSH before enabling UFW to avoid locking yourself out:

```bash
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable
sudo ufw status verbose
```

Type `y` when asked to confirm.

| Rule | Reason |
| --- | --- |
| Default deny incoming | Blocks incoming traffic unless explicitly allowed. |
| Default allow outgoing | Allows the server to download updates and images. |
| Allow `22/tcp` | Permits SSH administration. |
| Allow `80/tcp` | Permits HTTP traffic to the WordPress service. |
| Do not open `3306/tcp` | Keeps MySQL private inside the Docker network. |

### 7.1 Test the firewall

- Reload `http://localhost:8080` and confirm that the site works.
- Open a second PowerShell window and confirm SSH still works:

```powershell
ssh -p 2222 youruser@127.0.0.1
```

- Do not run `sudo ufw allow 3306`.

## 8. Backup Automation

### 8.1 Create the backup script

The script dumps the WordPress database to `/mnt/backup`, deletes database dumps older than seven days, and records a log line. If the backup disk is not mounted, it falls back to a folder in the user's home directory.

```bash
cd ~/ccm101-final-requirement
nano automation-script.sh
```

Add this script:

```bash
#!/bin/bash

if mountpoint -q /mnt/backup; then
  BACKUP_DIR="/mnt/backup/ccm101-backups"
else
  BACKUP_DIR="$HOME/ccm101-backups"
fi

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p "$BACKUP_DIR"

docker exec ccm101-mysql sh -c \
  'mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" wordpress' \
  > "$BACKUP_DIR/wordpress_$DATE.sql"

find "$BACKUP_DIR" -name "wordpress_*.sql" -mtime +7 -delete
echo "$(date) backup saved to $BACKUP_DIR" >> "$HOME/backup.log"
```

### 8.2 Make it executable and test it

```bash
chmod +x automation-script.sh
ls -l automation-script.sh
./automation-script.sh
ls -lh /mnt/backup/ccm101-backups
cat ~/backup.log
```

Check that the script has execute permission, a non-empty `.sql` backup file is created, and the log records the run.

### 8.3 Schedule the backup with cron

Open the cron editor:

```bash
crontab -e
```

Add the following line, replacing `youruser` with your actual Ubuntu username:

```cron
0 23 * * * /home/youruser/ccm101-final-requirement/automation-script.sh >> /home/youruser/cron.log 2>&1
```

| Field | Value | Meaning |
| --- | --- | --- |
| Minute | `0` | At minute 0 |
| Hour | `23` | At 11 PM |
| Day of month | `*` | Every day of the month |
| Month | `*` | Every month |
| Day of week | `*` | Every day of the week |

Confirm the schedule:

```bash
crontab -l
```

### 8.4 Prove that cron works

1. Run `crontab -e` and temporarily change the schedule to `* * * * *` so it runs every minute.
2. Wait two minutes, then check the backup folder and cron log.
3. Change the schedule back to `0 23 * * *` and confirm with `crontab -l`.

```bash
ls -lh /mnt/backup/ccm101-backups
cat ~/cron.log
```

The scheduled backup runs only while the VM is powered on at 11:00 PM.

## 9. Backup Restore Procedure

Use this procedure to restore the WordPress database from a saved `.sql` file. Restoring replaces the current database contents with the contents of the selected backup.

1. List the available backups and choose the file to restore.

```bash
ls -lh /mnt/backup/ccm101-backups
```

2. Replace `FILENAME` with the actual backup file name and run:

```bash
docker exec -i ccm101-mysql sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" wordpress' < /mnt/backup/ccm101-backups/FILENAME.sql
```

3. Refresh `http://localhost:8080` and confirm the content is restored.

## 10. Maintenance Commands

| Task | Command |
| --- | --- |
| Show running containers | `docker compose ps` |
| WordPress logs | `docker logs ccm101-wordpress` |
| MySQL logs | `docker logs ccm101-mysql` |
| List persistent volumes | `docker volume ls` |
| Firewall status | `sudo ufw status` |
| Scheduled cron job | `crontab -l` |
| Check backup disk mount | `df -h \| grep /mnt/backup` |
| Backup history | `cat ~/backup.log` |

### 10.1 Safe shutdown

- Run `sudo poweroff` and wait for the VM window to close before shutting down or restarting the laptop.
- Keep the laptop plugged in while the VM runs. Sudden power loss can corrupt the VM disk.
- Keep at least 20 GB free on the `C:` drive because the virtual disks grow as data is added.

### 10.2 Make a safety copy of the VM

1. Run `sudo poweroff` and wait for the VM to stop.
2. In VirtualBox, open **File → Export Appliance**.
3. Select the VM, click **Next**, and save it as `C:\CCM101\VM-Backups\ccm101-server.ova`.
4. Copy the `.ova` file to a USB drive or cloud storage as well. A backup stored only on the same drive as the VM may be lost if that drive fails.

## 11. Troubleshooting

| Problem | Likely cause or fix |
| --- | --- |
| Virtualization shows Disabled | Restart, enter BIOS (F2, F10, Delete, or Esc), and enable Intel VT-x or AMD SVM Mode. |
| VM boots back into the installer | Shut down the VM, remove the ISO from **Settings → Storage**, then start again. |
| SSH is refused on port 2222 | Check that the VM is running, the port-forwarding rule maps 2222 to 22, and OpenSSH was installed. |
| Locked out after enabling UFW | Open the VM console and run `sudo ufw allow 22/tcp`. |
| Docker permission denied | Run `sudo usermod -aG docker $USER`, exit the SSH session, and reconnect. |
| `docker-compose-plugin` not found | Use `sudo apt install -y docker.io docker-compose-v2`. |
| Site does not load at `localhost:8080` | Run `docker compose ps` and `docker logs ccm101-wordpress`; check the 8080-to-80 forwarding rule and UFW port 80 rule. |
| Backup disk not mounted after reboot | Check the UUID line in `/etc/fstab`, then run `sudo mount -a` and `df -h`. |
| Backup file is empty | Check that the database container is running and the `.env` passwords are correct. |
| Cron job did not run | The VM must be powered on at 11:00 PM. Check `crontab -l` and `cat ~/cron.log`. |
| Data disappeared | Avoid `docker compose down -v`, which deletes volumes. Restore from a `.sql` backup using Section 9. |
| Port 80 is busy (for example, in KillerCoda) | Change the Compose mapping to `"8081:80"` and open the corresponding host port. |

## 12. Conclusion

This project delivered a secure multi-tier web application with WordPress and MySQL running in separate Docker containers on an Ubuntu Server VM hosted by VirtualBox. NAT port forwarding allows the laptop to reach the website and SSH. Persistent volumes retain data across container restarts and VM reboots. UFW applies a default-deny policy and exposes only ports 22 and 80, keeping MySQL private inside the Docker network. A Bash script and cron job back up the database to a dedicated virtual disk every night at 11:00 PM, and the restore procedure provides a recovery path.

Together, these steps demonstrate virtualization, Linux and SSH administration, Docker and Compose, networking, persistent storage, firewall security, and automation.

## Repository contents

| File or folder | Purpose |
| --- | --- |
| `README.md` | Short project overview |
| `docker-compose.yml` | WordPress and MySQL container configuration |
| `.env.example` | Safe example of required environment variables |
| `automation-script.sh` | Automated database backup script |
| `operational-manual.md` | This manual |
| `images/` | Images extracted from the original PDF for documentation |
