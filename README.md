# nZEDb ansible playbook

This contains a minimal set of ansible roles to install a working nZEDb system.  Note: nZEDb is a complex beast, with a metric ton of configuration required.  The variables defined below will get the system up and running, but it will likely need additional tweaking.  Please see the [main nZEDb repo](https://github.com/nZEDb/nZEDb "nZEDb github repo") for more information.

## Prerequisites

The following python packages must be installed on the Ubuntu 16.04 system for ansible to be able to connect and work

`apt-get install python-minimal python2.7 python`

Since a lot of the information required would be considered confidential (userids, passwords, apikeys etc.) it is recommended that you set up an Ansible Vault file to hold those items.  It should be created in `group_vars/all/vault`, using a command like

```
ansible-vault create group_vars/all/vault
```

Each of the roles below will list the variables that can be set, and the default vault-version that they pull from.  In general, vault variables are named like `vault_nntp_password` which would map to a main `nntp_password` variable for use in the tasks.

There are several directories that you should pre-create, to make data management and backups a bit easier.

* `/var/www/nzedb`                      The main directory for nZEDb
* `/var/www/nzedb/resources/nzb`        Can get *very* large with millions of files
* `/var/www/nzedb/resources/covers`     Can also get very large
* `/var/www/nzedb/resources/tmp/unrar`  Should be a tmpfs filesystem - used as tmp space for unrar
* `/var/lib/mysql`                      Depends on how big your database gets

For example, creating ZFS datasets might be something like

```
zfs create -o mountpoint=/var/www/nzedb/resources/nzb poolname/nzbs
zfs create -o mountpoint=/var/www/nzedb/resources/covers poolname/covers
echo 'tmpfs /var/www/nzedb/resources/tmp/unrar tmpfs defaults,nodev,user,nodiratime,nosuid,noatime,mode=777  0 0' >> /etc/fstab
```

The nzedb role will set appropriate ownership permissions.

## Usage

Edit the `nzedb-hosts` file to put your new nZEDb box address.  This can be a remote or localhost.  Edit or create a vault file as described above - look at the role settings below to see what variables should be in the vault.  They're all of the form `vault_something`.

Check and update any variables in the individual role config files (`roles/ROLENAME/defaults/main.yml`)

Run the playboox with

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
* `password`            (pulls from `vault_default_password` or defaults to _password_)
* `firstname`           (pulls from `vault_firstname` or defaults to _George_)
* `lastname`            (pulls from `vault_lastname`  or defaults to _of the Jungle_)
* `default_mail_target` (pulls from `vault_default_mail_target` or defaults to _username@inventory\_hostname_)

## Roles included

### nginx

Simple setup of nginx and php7.0.

### mariadb

Installs and configures a basic nZEDb-ready mysql database.  NOTE: this is a generic install - your own tuning will be heavily dependent on your site, number of groups etc.  Consider this only a base to start from.  It will get nZEDb up and running ... but you _WILL_ have to properly tune the database for your specific environment.

*NOTE* There are additional mysql tuning parameters to set in the nZEDb role section below.

> ##### Variables `roles/mariadb/defaults/main.yml`

> * `mysql_root_pass`  (pulls from `vault_mysql_root_pass` or has a default)
> * `mysql_timezone`

> The rest of the variables can be left to the defaults.

### tools

Installs yydecode, niel's php-yenc-extension and latest unrar

> ##### Variables `roles/tools/defaults/main.yml`

> * `rar_version` 5.5.0
> * `nzedb_yenc_version` 1.3.0
> * `nzedb_yydecode_version` 0.2.10

### powerline

Installs powerline and several fonts to make tmux prettier

### composer

Installs latest version of composer

> #### Variables `roles/composer/defaults/main.yml`

> Should not need to change anything here.

### nzedb

Installs nzedb, sphinxsearch, creates and populates database.

> ##### Variables `roles/nzedb/defaults/main.yml`

> **NNTP server configuration**

> * `nntp_username`       (pulls from `vault_nntp_username`)
> * `nntp_password`       (pulls from `vault_nntp_password`)
> * `nntp_server`         news.supernews.com
> * `nntp_port`           443
> * `nntp_sslenabled`     true
> * `nntp_socket_timeout` 120

> **IRC Scraper configuration**

> * `irc_username`        (pulls from `vault_irc_username`)
> * `irc_nickname`        (pulls from `vault_irc_nickname`)
> * `irc_realname`        (pulls from `vault_irc_realname`)
> * `irc_password`        (pulls from `vault_irc_password`)
> * `irc_server`          (pulls from `vault_irc_server` or defaults to _irc.synirc.net_)
> * `irc_port`            (pulls from `vault_irc_port` or defaults to 6697 for SSL)
> * `irc_tls`             true

> **File path locations**

> * `nzbpath`             /var/www/nzedb/resources/nzb/
> * `coverspath`          /var/www/nzedb/resources/covers/
> * `tmpunrarpath`        /var/www/nzedb/resources/tmp/unrar/

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

> **Mysql configs**

> * `nzedb_mysql_dbname`      nzedb
> * `nzedb_mysql_pass`        fcrnjmiervwn
> * `innodb_buffer_pool_size` defaults to 0.7 of available ram
> * `innodb_buffer_pool_instances` 18
> * `innodb_additional_mem_pool_size` 20M
> * `key_buffer_size` defaults to 0.15 of available ram

> **Tmux settings**

> Here you can add any specific settings for Tmux that you want.  THe defaults here are fairly typical.  Unfortunately the tmux table doesn't have a description or hint field, so you'll have to look at the main Tmux Settings page on your site.

> **Custom settings**

> This is list of other settings in the settings table that can be configured.  You can add whatever setting to this list as you please.  The ones already there are some reasonable examples.  You can see the setting descriptions with something like

> ```
mysql nzedb -e "select setting,value,hint from settings where setting like '%lookuppar2%';"
```

> **Groups to activate**

> This is the list groups to activate.  You can also set whether to backfill the group, and for how many days back to go.

