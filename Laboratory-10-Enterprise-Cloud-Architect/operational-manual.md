# CCM101 Cloud Computing

# Enterprise Cloud Architect Operational Manual

| Item | Details |
| --- | --- |
| Project | Secure Multi-Tier Web Application |
| Application Stack | WordPress + MySQL |
| Prepared by | ACERIT, SUZANNE P., ESTIBAR, JOHN DARYL T., JAVONILLO, KYRA NICOLE V., SALCEDO, KRISTINE C. |
| Section | BSIT 4A |
| Instructor | Jenkielyn C. Torres |
| Date | October 11, 2026 |

---

## 1. Project Overview

This project deploys a secure multi-tier web application on a Linux server. WordPress is the web tier and MySQL is the database tier. Both run as Docker containers on an Ubuntu Server virtual machine hosted in VirtualBox on a Windows laptop. The VM files are kept on an external drive so the internal drive stays free.

The setup was built to meet four goals.

- Data stays safe after container or VM restarts.
- Only the ports that are really needed are open.
- A database backup runs automatically every day.
- Everything is documented and stored in the GitHub repository for handover.

### Key facts

| Item | Value |
| --- | --- |
| Server name | ccm101-server |
| Operating system | Ubuntu Server 26.04 LTS |
| Hypervisor | Oracle VirtualBox (Type 2) |
| Containers | ccm101-wordpress and ccm101-mysql |
| Persistent volumes | wordpress_data and db_data |
| Open ports | 22 (SSH) and 80 (HTTP) |
| Backup schedule | Every day at 11 PM |
| Repository | [CCM101-jestibar](https://github.com/jdestibar/CCM101-jestibar) |

## 2. Infrastructure and Architecture

The system is built in layers, from the physical laptop down to the application containers.

| Layer | Role |
| --- | --- |
| Host laptop (Windows 11) | Runs VirtualBox and provides the browser and terminal used to manage the server. |
| VirtualBox | Type 2 hypervisor that runs the Ubuntu virtual machine. |
| External drive | Stores the VM disk and the separate backup disk. |
| Ubuntu Server VM | The Linux server that runs Docker and the firewall. |
| UFW firewall | Default deny policy that allows only SSH and HTTP. |
| Docker network (backend) | Private network that connects WordPress to MySQL. |
| Containers | ccm101-wordpress serves the site and ccm101-mysql stores the data. |
| Volumes | wordpress_data and db_data keep the data outside the containers. |

### How users and admins reach the server

VirtualBox uses NAT with port forwarding, which works on any network including school wifi.

| From the laptop | Goes to | Used for |
| --- | --- | --- |
| localhost port 8080 | VM port 80 | WordPress website |
| localhost port 2222 | VM port 22 | SSH administration |

![Architecture diagram](https://github.com/user-attachments/assets/6f4f9008-d4b2-4800-8dde-c22c63f7b0f9)

## 3. Required Resources

### Hardware

- Laptop with virtualization turned on (Intel VT-x or AMD SVM) and at least 8 GB of RAM.
- External drive with at least 60 GB free, formatted exFAT or NTFS, on a USB 3 port.

### Software

- Oracle VirtualBox and the Ubuntu Server ISO
- Git for Windows, VS Code, and draw.io
- A web browser, a GitHub account.

### Virtual machine sizing

| Setting | Value |
| --- | --- |
| Name | CCM101-Ubuntu-Server |
| Type and version | Linux, Ubuntu (64-bit) |
| Memory | 4096 MB (3072 MB if the laptop is low on RAM) |
| Processors | 2 |
| System disk | 40 GB VDI, dynamically allocated |
| Backup disk | 10 GB VDI, dynamically allocated |

## 4. VM and Network Setup

### 4.1 Prepare the external drive

1. Plug the drive into a USB 3 port and note its drive letter.
2. Create the folders ISO, VMs, Repo, Screenshots, and VM-Backups inside a CCM101 folder on the drive.
3. In VirtualBox open File, Preferences, General and set the Default Machine Folder to the VMs folder on the drive.

### 4.2 Create the virtual machine

Create a new VM with the sizing in section 3 and skip unattended installation. Confirm that the VM path starts with the external drive letter.

### 4.3 Configure NAT port forwarding

Before the first boot, open Settings, Network, Adapter 1, set it to NAT, then add these rules under Advanced, Port Forwarding.

| Name | Protocol | Host port | Guest port |
| --- | --- | --- | --- |
| ssh | TCP | 2222 | 22 |
| web | TCP | 8080 | 80 |

![VirtualBox port forwarding](https://github.com/user-attachments/assets/7886da53-8ca2-44bd-b85c-2b1ead1cc3f9)

### 4.4 Install Ubuntu Server

- Use the entire 40 GB disk with the default storage layout.
- Set the server name to ccm101-server and create an administrator user.
- Tick Install OpenSSH server and skip the featured snaps.
- Reboot, then log in on the console.

### 4.5 Update the server and connect with SSH

```bash
sudo apt update
sudo apt upgrade -y
ip addr
```

From PowerShell on the laptop, connect using your own username. Use this SSH window for all later commands so copy and paste works.

```bash
ssh -p 2222 estibargroup@127.0.0.1
```

![SSH login](https://github.com/user-attachments/assets/3214c65f-5fee-4d7d-b980-7434763d190d)

### 4.6 Add the backup disk

A second 10 GB virtual disk stored on the external drive holds the database backups. Shut the VM down, attach the new disk in Settings, Storage, then start the VM and find it.

```bash
lsblk
```

The new empty 10 GB disk is usually sdb. Check the size first because formatting the wrong disk erases it. Then format and mount it.

```bash
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /mnt/ssd-backup
sudo mount /dev/sdb /mnt/ssd-backup
sudo chown $USER:$USER /mnt/ssd-backup
sudo blkid /dev/sdb
```

Copy the UUID from the last command and add this line at the bottom of `/etc/fstab` so the disk mounts on every boot. The `nofail` option stops the VM from hanging if the disk is missing.

```bash
UUID=PASTE-YOUR-UUID-HERE /mnt/ssd-backup ext4 defaults,nofail 0 2
```

```bash
sudo mount -a
df -h | grep ssd-backup
```

![Backup disk mounted](https://github.com/user-attachments/assets/6908b531-6629-41ea-8fd1-a0c7f43ee37a)

## 5. Docker Deployment

### 5.1 Install Docker and Compose

Install Docker Engine and the Compose plugin from the Ubuntu repository.

```bash
sudo apt install -y docker.io docker-compose-v2
```

Let your user run Docker without sudo, then log out and back in over SSH so the change applies.

```bash
sudo usermod -aG docker $USER
sudo systemctl enable docker
exit
```

After reconnecting, verify the install.

```bash
docker --version
docker compose version
docker run hello-world
```

![Docker version and hello-world](https://github.com/user-attachments/assets/6fa6c436-fc0b-459f-9c99-6c0df06a667d)

### 5.2 Create the project files

```bash
mkdir -p ~/ccm101-final
cd ~/ccm101-final
nano .env
```

The `.env` file keeps passwords out of the compose file. Replace the sample passwords with your own.

```dotenv
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=ChangeMe_User123
MYSQL_ROOT_PASSWORD=ChangeMe_Root123
```

### 5.3 docker-compose.yml

Create `docker-compose.yml` and paste this configuration:

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

Only WordPress publishes a port. MySQL has no published port, so it can only be reached inside the backend network. The health check makes WordPress wait until the database is ready.

### 5.4 Start the stack

```bash
docker compose config
docker compose up -d
docker compose ps
```

The first run downloads the images, which can take several minutes. Then open the site in the laptop browser using `http://localhost:8080`, choose a language, and fill in the site title, an admin user, a strong password, and an email.

![WordPress setup screenshot 1](https://github.com/user-attachments/assets/33b7c712-fb33-4e82-807b-d355fac74620)

![WordPress setup screenshot 2](https://github.com/user-attachments/assets/c8fd81bf-d2f7-47c9-bc50-bbb54aba9882)

![WordPress site screenshot](https://github.com/user-attachments/assets/ac5090fd-4399-487e-ae0e-018940aac6fd)

## 6. Persistent Storage and Reboot Test

Docker volumes keep data outside the containers, so deleting or recreating a container does not delete the site or the database.

| Volume | Mounted in container at | Holds |
| --- | --- | --- |
| db_data | /var/lib/mysql | MySQL database files |
| wordpress_data | /var/www/html | WordPress files, themes, uploads |

### Persistence test

1. Create one test post in WordPress.
2. Remove and recreate the containers, then refresh the site. The post should still be there.
3. Reboot the VM, reconnect over SSH, and check that both containers came back by themselves and the post still exists.

```bash
docker compose down
docker compose up -d
sudo reboot
```

After reconnecting, check the containers, volumes, and backup disk.

```bash
docker ps
docker volume ls
df -h | grep ssd-backup
```

![Persistence test screenshot 1](https://github.com/user-attachments/assets/3da0aa61-b632-4632-be9f-19436bda958b)

![Persistence test screenshot 2](https://github.com/user-attachments/assets/7a24d37c-4936-4c3a-ae0b-3d97a15e461a)

![Persistence test screenshot 3](https://github.com/user-attachments/assets/6b360571-558e-4031-ba31-2dcbc2268d12)

![Persistence test screenshot 4](https://github.com/user-attachments/assets/8f27fd71-37e8-46a3-8606-55ee0510a1b9)

## 7. Security Hardening

The firewall uses a default deny policy for incoming traffic and opens only what the application needs. Allow SSH before enabling UFW or you will lock yourself out.

```bash
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable
sudo ufw status verbose
```

| Rule | Reason |
| --- | --- |
| Default deny incoming | Everything not listed is blocked. |
| Default allow outgoing | The server can still download updates and images. |
| Allow 22/tcp | Remote administration over SSH. |
| Allow 80/tcp | Public access to the WordPress site. |
| Port 3306 not opened | MySQL is only needed by WordPress inside the Docker network. |

![UFW status](https://github.com/user-attachments/assets/da2825dd-1bb6-413c-b4b5-02b542f48bda)

### Other security practices

- Passwords live in `.env`, which is never committed to GitHub.
- Docker writes its own firewall rules, so a published container port can bypass UFW. For this reason only WordPress publishes a port.
- Keep the system updated with `sudo apt update` and `sudo apt upgrade`.
- Use strong passwords for the Ubuntu user and the WordPress admin.

## 8. Backup Automation

The script `automation-script.sh` backs up the WordPress database. It saves to the backup disk when it is mounted and falls back to the home folder if it is not. It also deletes backups older than 7 days and writes a log line.

```bash
#!/bin/bash

if mountpoint -q /mnt/ssd-backup; then
  BACKUP_DIR="/mnt/ssd-backup/ccm101-backups"
else
  BACKUP_DIR="$HOME/ccm101-backups"
fi

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p "$BACKUP_DIR"

docker exec ccm101-mysql sh -c 'mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" wordpress' \
  > "$BACKUP_DIR/wordpress_$DATE.sql"

find "$BACKUP_DIR" -name "wordpress_*.sql" -mtime +7 -delete
echo "$(date) backup saved to $BACKUP_DIR" >> "$HOME/backup.log"
```

### Make it executable and test it

```bash
cd ~/ccm101-final
chmod +x automation-script.sh
ls -l automation-script.sh
./automation-script.sh
ls -lh /mnt/ssd-backup/ccm101-backups
cat ~/backup.log
```

![Backup script screenshot](https://github.com/user-attachments/assets/dcf2c3f0-9d01-4e52-9a54-a74aee19a646)

### Schedule it with cron

```bash
crontab -e
```

Add this line at the bottom, using the real username.

```cron
0 23 * * * /home/estibargroup/ccm101-final/automation-script.sh >> /home/estibargroup/cron.log 2>&1
```

| Field | Value | Meaning |
| --- | --- | --- |
| Minute | 0 | At minute 0 |
| Hour | 23 | At 11 PM |
| Day of month | * | Every day |
| Month | * | Every month |
| Day of week | * | Every day of the week |

Check it with `crontab -l`. For a demo, change the schedule to `* * * * *` so it runs every minute, wait two minutes, check the backup folder, then change it back. The 11 PM job only runs if the VM is switched on at that time.

![Cron schedule screenshot](https://github.com/user-attachments/assets/0df38ad4-5d59-4bf4-ba8f-f06bae7eff26)

## 9. Backup Restore Procedure

Use this when the database is damaged or data was deleted by mistake. Restoring replaces the current database content with the backup.

1. List the available backups and pick one.

```bash
ls /mnt/ssd-backup/ccm101-backups
```

2. Run the restore command with the selected file.

```bash
docker exec -i ccm101-mysql sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" wordpress' < /mnt/ssd-backup/ccm101-backups/FILENAME.sql
```

To restore the newest backup without typing the file name, use this:

```bash
LATEST=$(ls -t /mnt/ssd-backup/ccm101-backups/wordpress_*.sql | head -1)
docker exec -i ccm101-mysql sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" wordpress' < "$LATEST"
```

Refresh the WordPress website and confirm that the expected content has been restored.

## 10. Maintenance Commands

| Task | Command |
| --- | --- |
| Show running containers | `docker compose ps` |
| Show all containers | `docker ps -a` |
| WordPress logs | `docker logs ccm101-wordpress` |
| MySQL logs | `docker logs ccm101-mysql` |
| Restart the stack | `docker compose restart` |
| Stop the stack (keeps data) | `docker compose down` |
| Start the stack | `docker compose up -d` |
| Update images | `docker compose pull && docker compose up -d` |
| List volumes | `docker volume ls` |
| Firewall status | `sudo ufw status verbose` |
| Cron jobs | `crontab -l` |
| Cron and backup logs | `cat ~/cron.log ~/backup.log` |
| Disk space | `df -h` |
| Update Ubuntu | `sudo apt update && sudo apt upgrade -y` |
| Shut down safely | `sudo poweroff` |

### Shutting down with the external drive

1. Run `sudo poweroff` in the SSH window and wait for the VM window to close.
2. Check that VirtualBox shows the VM as Powered Off, then close VirtualBox.
3. Use Safely Remove Hardware in Windows before unplugging the drive.

## 11. Troubleshooting

| Problem | Likely cause | Fix |
| --- | --- | --- |
| Website does not open at localhost:8080 | Containers stopped or the port rule is missing | Run `docker compose ps` and check the web rule in VirtualBox port forwarding. |
| SSH says connection refused | VM still booting or the SSH rule is missing | Wait a minute, then check the SSH rule for host port 2222. |
| Docker says permission denied | Group change not applied yet | Run `exit`, then SSH in again. |
| WordPress cannot reach the database | MySQL not healthy or wrong password in `.env` | Check `docker logs ccm101-mysql` and compare the `.env` values. |
| Backup file is empty or missing | MySQL container not running or script not executable | Run `docker ps`, make the script executable, then run it by hand. |
| Backup disk not mounted after reboot | Wrong UUID in `/etc/fstab` | Run `sudo blkid`, fix the line, then `sudo mount -a`. |
| Locked out after enabling UFW | Port 22 was not allowed first | Use the VM console to log in and run `sudo ufw allow 22/tcp`. |
| VM is paused or very slow | Drive disconnected, full, or low RAM | Check the drive and free space, then use Machine, Resume in VirtualBox. |
| VM not found after replugging the drive | Drive letter changed | Check the letter in File Explorer and the Default Machine Folder path. |

## 12. Conclusion

This infrastructure gives a persistent multi-tier web application with container isolation, a default deny firewall, automated database backups, and clear recovery steps. The VM and backup disk live on an external drive, which keeps the laptop free and makes the setup easy to move.

One limit is that the VM disk and the backup disk sit on the same physical drive. In a real deployment, backups would also be copied to another machine or to cloud storage.

### Repository contents

| File | Purpose |
| --- | --- |
| `README.md` | Project overview and operational instructions |
| `architecture-diagram.png` | Topology of host, hypervisor, VM, firewall, and containers |
| `docker-compose.yml` | WordPress and MySQL stack |
| `automation-script.sh` | Database backup script |
| `operational-manual.md` | This manual |
| `final-reflection.md` | Reflection from Mission 1 to Mission 10 |

