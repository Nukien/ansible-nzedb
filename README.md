# nZEDb ansible playbook

This contains a minimal set of ansible roles to install a working nZEDb setup onto an existing Ubuntu 16.04 system.  Note: nZEDb is a complex beast, with a metric ton of configuration required.  The variables defined below will get the system up and running, but it will likely need additional tweaking.  Please see the [main nZEDb repo](https://github.com/nZEDb/nZEDb "nZEDb github repo") for more information.

## Prerequisites

You must be able to ssh into your target system using ssh keys.

The following python packages must be installed on the target Ubuntu 16.04 system for ansible to be able to connect and work

`apt-get install python-minimal python2.7 python`

### Setting up ansible vault (recommended)

Since a lot of the information required would be considered confidential (userids, passwords, apikeys etc.) it is recommended that you set up an Ansible Vault file to hold those items.  It should be created in `group_vars/all/vault`, using a command like

```
ansible-vault create group_vars/all/vault
```

Each of the roles below will list the variables that can be set, and the default vault-version that they pull from (if it's a secret).  In general, vault variables are named like `vault_nntp_password` which would map to a main `nntp_password` variable for use in the tasks.

For example, the `nntp_password` variable for the nZEDb role is listed in the `roles/nZEDb/defaults/main.yml` file as

```
nntp_password: "{{ vault_nntp_password | default('george') }}"
```

which means that the `nntp_password` variable will be set to the whatever the vault variable `vault_nntp_password` is, and if that doesn't exist then use a default of *george*.

### Pre-creating directories

There are several directories that you should pre-create as separate filesystems, to make data management and backups a bit easier.  If you're not already using ZFS, consider it - it's perfect for managing stuff like this, besides being an awesome filesystem.

* `/var/www/nzedb`                      The main directory for nZEDb
* `/var/www/nzedb/resources/nzb`        Can get *very* large with millions of files
* `/var/www/nzedb/resources/covers`     Can also get very large
* `/var/www/nzedb/resources/tmp/unrar`  Should be a tmpfs filesystem - used as tmp space for unrar
* `/var/lib/mysql`                      Depends on how big your database gets

For example, creating ZFS datasets might be something like the following.  This is supposing that you have SSH'd into your target box or are logged into it as `my_userid`.  The commands are run as root, and change ownership of the directories to your own `my_userid`.  You will want both user and group ownership to be to your userid.

```
zfs create -o mountpoint=/var/www/nzedb poolname/nzedb
zfs create -o mountpoint=/var/www/nzedb/resources/nzb poolname/nzbs
zfs create -o mountpoint=/var/www/nzedb/resources/covers poolname/covers
chown -R my_userid:my_userid /var/www/nzedb

cat > /etc/systemd/system/var-www-nzedb-resources-tmp-unrar.mount << EOF
[Unit]
Description=TMPFS dir for unrar for nZEDb
DefaultDependencies=no
Conflicts=umount.target
After=zfs.target

[Mount]
What=tmpfs
Where=/var/www/nzedb/resources/tmp/unrar
Type=tmpfs
Options=defaults,nodev,user,nodiratime,nosuid,noatime,mode=777

[Install]
WantedBy=multi-user.target
EOF

systemctl enable var-www-nzedb-resources-tmp-unrar.mount
```

The ugly systemd unit is needed for the tmpfs to ensure that it doesn't mount until *after* the zfs datasets mount.  If you put an entry in `/etc/fstab`, then the `/var/www/nzedb/resources/tmp/unrar` directory will mount *before* the main nzedb dataset.  That in turn will prevent parent `/var/www/nzedb` dataset from mounting.  Bad things happen.

If using ZFS, the above configuration has been verified to work.  The datasets mount in the correct order, and the tmpfs mounts after them.  Of course, this is just an example, you can use whatever systems and conventions you prefer for disk layout.

You could also use a ZFS dataset for mysql, which makes for very efficient and fast backups.  See the `/usr/local/bin/backup_nzedb.sh` script installed by the nzedb role.  Google for the appropriate `zfs create` parameters for mysql.

The nzedb role will set appropriate ownership permissions.

## Usage

Edit the `nzedb-hosts` file to put your new nZEDb box address.  This can be a remote or localhost.  Edit or create a vault file as described above - look at the role settings below to see what variables should be in the vault.  They're all of the form `vault_something`.

Check and update any variables in the individual role config files (`roles/ROLENAME/defaults/main.yml`)

Run the playbook with

```
./setup.sh full
```

or

```
ansible-playbook -K -i nzedb-hosts nzedb-playbook.yml
```

You can add `-l my_nzedb_host` to either command to restrict the run to just the host you want (from nzedb_hosts).  You can add any other ansible parameters - they will all be added to the end of the command.  For example `--tags 'nzedb` or `--extra-vars 'force_update=true`.

## Main top-level variables to set

See `group_vars/all/vars`

**This is the main user on the system**

* `username`            (pulls from `vault_default_username` or defaults to _george_)
* `userpass`            (pulls from `vault_default_password` or defaults to _password_)
* `firstname`           (pulls from `vault_firstname` or defaults to _George_)
* `lastname`            (pulls from `vault_lastname`  or defaults to _of the Jungle_)
* `default_mail_target` (pulls from `vault_default_mail_target` or defaults to _username@inventory\_hostname_)

* `enable_selfsigned_cert` Set to `true` to install a self-signed cert for nginx

## Roles included

### certs

Installs a self-signed cert setup in `/etc/ssl/<hostname>`

Nginx will use this cert, and will also create a `port80.conf` file listening on port http/80 which redirects to the https/443 main config (emailer.conf).

> ##### Variables `roles/certs/defaults/main.yml`
> * `ssl_certs_key_size` 4096
> * `ssl_certs_generate_dh_param` false - set to `true` to generate a strong DHE parameter file.  _NOTE_: this can take quite a while ...
> * `ssl_certs_...` Set cert contents (country, state etc.) to appropriate values

### nginx

Simple setup of nginx and php7.0

Defaults to installing nzedb under _/nzedb_ rather than hung directly off the root.
EG. `http://my.server.com/nzedb` rather than `http://nzedb.server.com/`

Edit the `roles/nzedb/tasks/main.yml` file to change this - the *Copy nginx configuration files* task.

The main config file is `emailer.conf` in `/etc/nginx/sites-enabled`.  It includes snippets from the `/etc/nginx/snippets/` directory of the form `emailer_<something>.conf`.  One example is `emailer_nginx_status.conf` which provides the standard nginx status page at **http://<hostname>/nginx_status**

### mariadb

Installs and configures a basic nZEDb-ready mysql database.  _NOTE:_ this is a generic install - your own tuning will be heavily dependent on your site, number of groups etc.  Consider this only a base to start from.  It will get nZEDb up and running ... but you _WILL_ have to properly tune the database for your specific environment.

*NOTE:* There are additional mysql tuning parameters to set in the nZEDb role section below.

> ##### Variables `roles/mariadb/defaults/main.yml`
> * `mysql_root_pass`  (pulls from `vault_mysql_root_pass` or has a cheap and dirty default)
> * `mysql_timezone`
>
> The rest of the variables can be left to the defaults.

### tools

Installs yydecode, niel's php-yenc-extension, par2 and latest unrar

> ##### Variables `roles/tools/defaults/main.yml`
> * `rar_version` 5.5.0
> * `nzedb_yenc_version` 1.3.0
> * `nzedb_yydecode_version` 0.2.10

### powerline

Installs powerline and several fonts to make tmux prettier

### composer

Installs latest version of composer

> ##### Variables `roles/composer/defaults/main.yml`
>
> Should not need to change anything here.

### sphinx

Installs sphinxsearch.

### nzedb

Installs nzedb, creates and populates database, configures sphinx and nginx.

> ##### Variables `roles/nzedb/defaults/main.yml`
> **NNTP server configuration**
> * `nntp_username`       (pulls from `vault_nntp_username`)
> * `nntp_password`       (pulls from `vault_nntp_password`)
> * `nntp_server`         news.supernews.com
> * `nntp_port`           443
> * `nntp_sslenabled`     true
> * `nntp_socket_timeout` 120
>
> **IRC Scraper configuration**
>
> It's recommended that you set up ZNC somewhere, and put your settings to connect to ZNC here.  The ZNC server should connect to *irc.synirc.com* on port 6697 (SSL), and join the *#nZEDbPRE*, *#nZEDbPRE2* and *#PreNNTmux* channels.
>
> If you're not using ZNC, then put in reasonable values for *username*, *nickname* etc.
> * `irc_username`        (pulls from `vault_irc_username` or defaults to _george_)
> * `irc_nickname`        (pulls from `vault_irc_nickname` or defaults to _george_)
> * `irc_realname`        (pulls from `vault_irc_realname` or defaults to _George of the Jungle_)
> * `irc_password`        (pulls from `vault_irc_password` or defaults to _george_)
> * `irc_server`          (pulls from `vault_irc_server` or defaults to _irc.synirc.net_)
> * `irc_port`            (pulls from `vault_irc_port` or defaults to 6697 for SSL)
> * `irc_tls`             true
>
> **File path locations**
> * `nzbpath`             /var/www/nzedb/resources/nzb/
> * `coverspath`          /var/www/nzedb/resources/covers/
> * `tmpunrarpath`        /var/www/nzedb/resources/tmp/unrar/
>
> **Backup info for /usr/local/bin/backup_nzedb.sh**
> * `nzedb_src_pool`      nzedb    (name of main zfs pool for nzedb)
> * `nzedb_dst_pool`      zedback  (name of backup zfs pool)
> * `nzedb_backup_dir`    /Backups (mysql backup location if NOT using zfs for mysql)
> * `nzedb_mysql_zfs_pool`         (name of mysql zfs pool if using zfs for mysql)
> * `nzedb_mysql_zfs_dataset`      (name of mysql dataset if using zfs for mysql)
> 
> **API keys**
> * `apikey_amazon_associate` (pulls from `vault_apikey_amazon_associate`)
> * `apikey_amazon_private`   (pulls from `vault_apikey_amazon_private`)
> * `apikey_amazon_public`    (pulls from `vault_apikey_amazon_public`)
> * `apikey_anidb`            (pulls from `vault_apikey_anidb`)
> * `apikey_fanarttv`         (pulls from `vault_apikey_fanarttv`)
> * `apikey_giantbomb`        (pulls from `vault_apikey_giantbomb`)
> * `apikey_tmdb`             (pulls from `vault_apikey_tmdb`)
> * `apikey_trakttv`          (pulls from `vault_apikey_trakttv`)
> * `apikey_trakttv_client`   (pulls from `vault_apikey_trakttv_client`)
>
> **Mysql configs**
> * `nzedb_mysql_dbname`      nzedb
> * `nzedb_mysql_pass`        fcrnjmiervwn  << **do change this** ...
> * `innodb_buffer_percent`   for *innodb_buffer_pool_size* - defaults to 70% of available ram
> * `innodb_buffer_pool_instances` defaults to about 1-2g of buffer_pool_size per instance
> * `innodb_additional_mem_pool_size` 20M
> * `innodb_io_capacity`      Tuning for SSD or M.2 type storage, or lower for sata disks
> * `innodb_io_capacity_max`  Tuning for SSD or M.2 type storage, or lower for sata disks
> * `innodb_lru_scan_depth`   Tuning for SSD or M.2 type storage, or lower for sata disks
> * `innodb_log_file_size`    Should be about 20% of *innodb_buffer_pool_size*
> * `key_buffer_size`         defaults to 15% of available ram
>
> **Tmux settings**
>
> Here you can add any specific settings for Tmux that you want.  The defaults here are fairly typical.  Unfortunately the tmux table doesn't have a description or hint field, so you'll have to look at the main Tmux Settings page on your site.
>
> **Custom settings**
>
> This is a list of other settings in the settings table that can be configured.  You can add whatever setting to this list as you please.  The ones already there are some reasonable examples.  You can see the setting descriptions with something like

```
mysql nzedb -e "select setting,value,hint from settings where setting like '%lookuppar2%';"
```

> **Groups to activate**
>
> This is the list of groups to activate.  You can also set whether to backfill the group, and for how many days back to go.

## Other information

[Munin stats script](https://gist.github.com/ThePeePs/bdb443f62173dcdae06297b843ab2a3a)
