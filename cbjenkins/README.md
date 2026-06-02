## cb_jenkins

This module manages a customized Jenkins controller installation on Linux using Puppet and Foreman.

It is designed to:

- install Jenkins from the official Jenkins RPM repository
- install Amazon Corretto in a custom path
- force Jenkins to use the custom Java runtime
- move `JENKINS_HOME` to a custom runtime path
- support install, upgrade, config, service, uninstall, and Nginx flows
- expose Jenkins through `jenkins.jcloudcodes.com`

## Final Jenkins Layout

After a successful run, Jenkins uses this layout:

```text
/jcloudcodes
├── cbjenkins
│   ├── data              # Active JENKINS_HOME
│   └── jenkins-java      # Symlink to Corretto Java
└── cbjenkins-java
    └── amazon-corretto-<version>-linux-x64
```

Important runtime values:

```text
JENKINS_HOME=/jcloudcodes/cbjenkins/data
JAVA_HOME=/jcloudcodes/cbjenkins/jenkins-java
JENKINS_JAVA_CMD=/jcloudcodes/cbjenkins/jenkins-java/bin/java
```

## Module Layout

- `manifests/init.pp`
  Orchestrates install, upgrade, config, service, nginx, and uninstall classes.

- `manifests/install.pp`
  Installs Amazon Corretto, configures the Jenkins RPM repository, imports the Jenkins GPG key, and installs the Jenkins package.

- `manifests/config.pp`
  Manages Jenkins runtime behavior:
  - custom Jenkins home
  - Java symlink
  - `/etc/sysconfig/jenkins`
  - systemd override
  - log/cache permissions
  - logrotate and limits configuration
  - transparent huge page tuning
  - Git package installation for SCM support

- `manifests/service.pp`
  Ensures Jenkins is enabled and running.

- `manifests/upgrade.pp`
  Handles post-package-change systemd reload and failed-state cleanup.

- `manifests/nginx.pp`
  Manages the Nginx reverse proxy for `jenkins.jcloudcodes.com`.

- `manifests/uninstall.pp`
  Removes Jenkins, related runtime data, and the Jenkins-owned Nginx reverse proxy.

## Class Flow

Main install flow:

```puppet
Class['cb_jenkins::install']
-> Class['cb_jenkins::upgrade']
-> Class['cb_jenkins::config']
-> Class['cb_jenkins::service']
-> Class['cb_jenkins::nginx']
```

This keeps responsibilities separated:

```text
install.pp   -> software and prerequisites
upgrade.pp   -> post-install/post-upgrade handling
config.pp    -> runtime configuration
service.pp   -> Jenkins service
nginx.pp     -> reverse proxy
uninstall.pp -> cleanup
```

## Required Console Parameters

These values are expected from Foreman / console:

- `action`
  Example: `install`

- `jenkins_version`
  Jenkins RPM version.
  Example: `2.555.2-1`

- `corretto_jdk_version`
  Full Amazon Corretto version.
  Example: `21.0.11.10.1`

- `git_version`
  Optional today, reserved for future custom tool management.

## Hiera Values

Current defaults from `data/common.yaml`:

```yaml
cb_jenkins::http_port: '8080'
cb_jenkins::ajp_port: '-1'
cb_jenkins::manage_repo: true
cb_jenkins::manage_java: false
cb_jenkins::service_name: 'jenkins'
cb_jenkins::jenkins_user: 'jenkins'
cb_jenkins::listen_address: '0.0.0.0'
cb_jenkins::jenkins_package: 'jenkins'
cb_jenkins::jenkins_repo_key_id: '14ABFC68'
cb_jenkins::nginx_server_name: 'jenkins.jcloudcodes.com'
cb_jenkins::config_file: '/etc/sysconfig/jenkins'
cb_jenkins::jenkins_repo_baseurl: 'https://pkg.jenkins.io/rpm-stable'
cb_jenkins::jenkins_repo_gpg: 'https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key'
```

## Nginx Reverse Proxy

The module exposes Jenkins through:

- `http://jenkins.jcloudcodes.com`

Managed pieces:

- `/etc/nginx/conf.d/jenkins.conf`
- SELinux boolean for outbound proxy connectivity
- `nginx -t` validation before reload

Key reverse proxy headers now included:

- `Host`
- `X-Forwarded-For`
- `X-Forwarded-Proto`
- `X-Forwarded-Port`
- `X-Forwarded-Host`

This is what allows Jenkins to display and remember:

- `http://jenkins.jcloudcodes.com/`

instead of the backend IP and port.

## Useful Validation Commands

### Package and Service

```bash
dnf list --showduplicates jenkins
rpm -qi jenkins
rpm -q --qf '%{VERSION}-%{RELEASE}\n' jenkins
systemctl status jenkins
systemctl status nginx
```

### Runtime Paths

```bash
ls -l /jcloudcodes/cbjenkins
ls -l /jcloudcodes/cbjenkins-java
cat /etc/sysconfig/jenkins
cat /etc/systemd/system/jenkins.service.d/override.conf
```

### Jenkins Runtime Validation

Verify custom Java:

```bash
/jcloudcodes/cbjenkins/jenkins-java/bin/java -version
```

Verify runtime environment:

```bash
systemctl show jenkins -p Environment --no-pager
```

Verify initial admin password after first successful startup:

```bash
cat /jcloudcodes/cbjenkins/data/secrets/initialAdminPassword
```

### Web Validation

```bash
curl -I http://127.0.0.1:8080
curl -I http://jenkins.jcloudcodes.com
```

## Important Fixes and Lessons Learned

### 1. Duplicate File Resource Fix

Do not declare the same `File[]` resource in both `install.pp` and `config.pp`.

Final ownership split:

```text
install.pp owns:
  /jcloudcodes
  /jcloudcodes/cbjenkins
  /jcloudcodes/cbjenkins-java

config.pp owns:
  /jcloudcodes/cbjenkins/data
  /jcloudcodes/cbjenkins/jenkins-java
  /etc/systemd/system/jenkins.service.d/override.conf
```

### 2. Duplicate Package Resource Fix

Only `install.pp` should manage:

```puppet
Package[jenkins]
```

`upgrade.pp` must not redeclare the Jenkins package. It should only handle post-change actions such as:

- systemd daemon reload
- failed-state reset

### 3. Java Compatibility Fix

Jenkins failed under Java 17.

Observed error pattern:

```text
Running with Java 17 ...
Supported Java versions are: [21, 25]
```

Working combination:

```text
jenkins_version      = 2.555.2-1
corretto_jdk_version = 21.0.11.10.1
```

### 4. Jenkins Home Location Fix

Final active home:

```text
/jcloudcodes/cbjenkins/data
```

Final variable pattern:

```puppet
$jenkins_root = '/jcloudcodes/cbjenkins'
$jenkins_home = "${jenkins_root}/data"
```

### 5. Systemd Override Fix

Jenkins is forced to use custom Java and custom home through:

```text
/etc/systemd/system/jenkins.service.d/override.conf
```

Expected structure:

```ini
[Service]
Environment="JENKINS_HOME=/jcloudcodes/cbjenkins/data"
Environment="JAVA_HOME=/jcloudcodes/cbjenkins/jenkins-java"
Environment="PATH=/jcloudcodes/cbjenkins/jenkins-java/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="JENKINS_JAVA_CMD=/jcloudcodes/cbjenkins/jenkins-java/bin/java"
```

### 6. `/etc/sysconfig/jenkins` Reinstall Fix

After full cleanup, `/etc/sysconfig/jenkins` could be missing, which breaks `file_line` resources in `config.pp`.

The module now ensures it exists after package installation before runtime configuration is applied.

### 7. Nginx / SELinux Reverse Proxy Fix

When Nginx was introduced, Jenkins could be reachable locally but fail through the proxy if SELinux blocked the backend connection.

The working fix pattern is:

```bash
setsebool -P httpd_can_network_connect 1
```

This behavior is now managed in `nginx.pp`.

## Troubleshooting

### Jenkins Not Starting

Useful commands:

```bash
systemctl status jenkins
journalctl -u jenkins -n 100 --no-pager
systemctl show jenkins -p Environment --no-pager
```

Check:

- Java version
- custom home path
- systemd override
- `/etc/sysconfig/jenkins`

### Jenkins Running but UI Inaccessible

Useful commands:

```bash
systemctl status nginx
nginx -t
journalctl -u nginx -n 100 --no-pager
curl -I http://127.0.0.1:8080
curl -I http://jenkins.jcloudcodes.com
```

Check:

- `nginx` is running
- reverse proxy config exists
- DNS resolves to the Nginx/Jenkins host
- port `80` is allowed

### Jenkins URL Shows IP Instead of DNS Name

Check:

- Nginx proxy headers
- Jenkins URL in:

```bash
cat /jcloudcodes/cbjenkins/data/jenkins.model.JenkinsLocationConfiguration.xml
```

Expected:

```xml
<jenkinsUrl>http://jenkins.jcloudcodes.com/</jenkinsUrl>
```

### First Admin Login

After the first clean install, Jenkins writes the initial unlock password here:

```bash
cat /jcloudcodes/cbjenkins/data/secrets/initialAdminPassword
```

### SSH Agent Troubleshooting from Controller Side

If Jenkins is used to launch SSH agents, the controller needs:

- a valid private key credential
- a matching public key on the agent host
- a readable known_hosts file

Recommended custom controller-side key path:

```text
/jcloudcodes/customer-ssh-keys/jenkins
```

Create it on the Jenkins controller like this:

```bash
sudo mkdir -p /jcloudcodes/customer-ssh-keys/jenkins
sudo chown -R jenkins:jenkins /jcloudcodes/customer-ssh-keys
sudo chmod 700 /jcloudcodes/customer-ssh-keys/jenkins
sudo -u jenkins ssh-keygen -t ed25519 -f /jcloudcodes/customer-ssh-keys/jenkins/id_ed25519 -N ''
sudo touch /jcloudcodes/customer-ssh-keys/jenkins/known_hosts
sudo chown jenkins:jenkins /jcloudcodes/customer-ssh-keys/jenkins/known_hosts
sudo chmod 600 /jcloudcodes/customer-ssh-keys/jenkins/known_hosts
```

### Jenkins UI Configuration for SSH Agents

In Jenkins UI:

1. Go to `Manage Jenkins`
2. Go to `Credentials`
3. Choose the scope/store you want, usually:
   - `System`
   - `Global credentials (unrestricted)`
4. Click `Add Credentials`
5. Set:
   - `Kind`: `SSH Username with private key`
   - `Scope`: `Global`
   - `Username`: `jenkins`
   - `Private Key`: `Enter directly`
   - paste the contents of:
     - `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519`
   - `ID`: for example `jslave-ssh-key`
   - `Description`: `Jenkins SSH key for jslave`
6. Save

Then when creating the node:

- `Launch method`: `Launch agents via SSH`
- `Host`: `jslave` IP or DNS
- `Credentials`: choose `jslave-ssh-key`

Important:

- the username must match the slave user created by Puppet:
  - `jenkins`
- the public key from:
  - `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519.pub`
  is what gets installed into the slave host `authorized_keys`
- the private key from:
  - `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519`
  is what Jenkins uses to log in

### Known Hosts Fix

One controller-side failure observed during SSH agent setup was:

```text
No Known Hosts file was found at /var/lib/jenkins/.ssh/known_hosts
```

Important:

Even when the controller keypair is stored in:

```text
/jcloudcodes/customer-ssh-keys/jenkins
```

the Jenkins SSH launcher may still read host verification entries from:

```text
/var/lib/jenkins/.ssh/known_hosts
```

That was the actual working controller-side path during validation.

Fix it on the Jenkins controller with:

```bash
sudo mkdir -p /var/lib/jenkins/.ssh
sudo touch /var/lib/jenkins/.ssh/known_hosts
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh
sudo chmod 600 /var/lib/jenkins/.ssh/known_hosts
```

Add the slave host key:

```bash
sudo -u jenkins ssh-keyscan -H jslave.jcloudcodes.com >> /var/lib/jenkins/.ssh/known_hosts
```

If you also want IP-based host matching:

```bash
sudo -u jenkins ssh-keyscan -H <jslave-public-ip> >> /var/lib/jenkins/.ssh/known_hosts
```

Useful controller-side checks:

```bash
sudo cat /jcloudcodes/customer-ssh-keys/jenkins/id_ed25519.pub
sudo cat /jcloudcodes/customer-ssh-keys/jenkins/id_ed25519
sudo -u jenkins cat /var/lib/jenkins/.ssh/known_hosts
sudo -u jenkins ssh -i /jcloudcodes/customer-ssh-keys/jenkins/id_ed25519 jenkins@jslave.jcloudcodes.com
ls -l /jcloudcodes/customer-ssh-keys/jenkins
ls -l /var/lib/jenkins/.ssh
```

## Upgrade Behavior

A clean Jenkins upgrade should ideally show only:

```text
Package[jenkins]/ensure changed old-version to new-version
Exec[daemon_reload_after_jenkins_install_or_upgrade] triggered
```

That means:

- package version changed
- runtime configuration was already converged
- no unnecessary corrective changes occurred

## Uninstall Behavior

The uninstall flow removes:

- Jenkins package
- runtime data under `/jcloudcodes/cbjenkins`
- custom Java under `/jcloudcodes/cbjenkins-java`
- Jenkins-owned Nginx config
- Nginx package
- Git/perl-Git cleanup when present

Important note:

Git and `perl-Git` had an RPM dependency loop, so they must be removed in one transaction.

## Recommended Validation After Changes

```bash
puppet agent -t
rpm -q --qf '%{VERSION}-%{RELEASE}\n' jenkins
systemctl status jenkins
systemctl status nginx
/jcloudcodes/cbjenkins/jenkins-java/bin/java -version
systemctl show jenkins -p Environment --no-pager
cat /jcloudcodes/cbjenkins/data/secrets/initialAdminPassword
```
