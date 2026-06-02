# tom_cat

This module manages Apache Tomcat on Linux and Windows using Puppet and Foreman.

It is designed to:

- install Amazon Corretto in a custom path
- install and configure Tomcat in a custom runtime path
- support both Linux and Windows layout handling
- manage Tomcat Manager credentials
- expose Tomcat through Nginx at `tomcat.jcloudcodes.com`
- preserve deployed applications during upgrades
- support install, upgrade, config, service, nginx, and uninstall actions

## Final Design

### Linux Layout

After successful installation, Linux Tomcat uses this layout:

```text
/jcloudcodes
├── cbtom-cat
│   └── data                  # Active Tomcat runtime
└── cbtomcat-java
    └── amazon-corretto-<version>-linux-x64
```

Important runtime paths:

```text
Tomcat container root : /jcloudcodes/cbtom-cat
Tomcat active runtime : /jcloudcodes/cbtom-cat/data
Java root             : /jcloudcodes/cbtomcat-java
Java symlink          : /jcloudcodes/cbtom-cat/data/tomcat-java
```

### Windows Layout

The module also supports Windows with these design points:

- Windows install root comes from:
  - `tom_cat::windows_install_dir`
- current default:
  - `C:/Tomcat`
- Windows config uses the same class split:
  - install
  - config
  - service
  - uninstall

Windows-specific behaviors in the module include:

- service registration/removal through PowerShell
- Windows `setenv.bat` management
- Windows install path handling through `windows_install_dir`

## Module Layout

- `manifests/init.pp`
  Orchestrates install, upgrade, nginx, config, service, and uninstall classes.

- `manifests/install.pp`
  Installs Tomcat software and Amazon Corretto, stages runtime content, and prepares the custom layout.

- `manifests/upgrade.pp`
  Handles upgrade-time stop/backup/version transition behavior.

- `manifests/nginx.pp`
  Manages the Nginx reverse proxy for `tomcat.jcloudcodes.com`.

- `manifests/config.pp`
  Manages Tomcat runtime configuration such as:
  - `server.xml`
  - `tomcat-users.xml`
  - `setenv.sh`
  - `setenv.bat`
  - Manager remote access context
  - systemd service/unit content

- `manifests/service.pp`
  Ensures Tomcat is enabled and running.

- `manifests/uninstall.pp`
  Removes Tomcat runtime, Java, and related Nginx resources.

## Class Flow

Install flow:

```puppet
Class['tom_cat::install']
-> Class['tom_cat::upgrade']
-> Class['tom_cat::nginx']
-> Class['tom_cat::config']
-> Class['tom_cat::service']
```

Responsibilities:

```text
install.pp   -> software and prerequisites
upgrade.pp   -> stop/backup/transition logic
nginx.pp     -> reverse proxy
config.pp    -> runtime shaping and configuration
service.pp   -> Tomcat service
uninstall.pp -> cleanup
```

## Required Console Parameters

The top-level class expects:

- `action`
  Example: `install`

- `environment`
  Example: `prod`

- `tom_version`
  Example: `10.1.24`

- `java_version`
  Example: `21.0.11.10.1`

These values should be treated as `string` in Foreman.

Do not put the literal text `undef` into Foreman string parameter fields. Leave the value blank if you want no explicit default.

## Hiera Values

Current defaults from `data/common.yaml`:

```yaml
tom_cat::base_dir: '/jcloudcodes'
tom_cat::tomcat_home: '/jcloudcodes/cbtom-cat'
tom_cat::install_dir: '/jcloudcodes/cbtom-cat/data'
tom_cat::java_root: '/jcloudcodes/cbtomcat-java'
tom_cat::service_name: 'tomcat'
tom_cat::tomcat_user: 'tomcat'
tom_cat::tomcat_group: 'tomcat'
tom_cat::windows_install_dir: 'C:/Tomcat'
tom_cat::shutdown_port: 8005
tom_cat::connector_port: 8085
tom_cat::redirect_port: 8443
tom_cat::nexus_url: 'https://archive.apache.org/dist/tomcat'
tom_cat::admin_user: 'admin'
tom_cat::nginx_server_name: 'tomcat.jcloudcodes.com'
```

Encrypted value in `data/common.eyaml`:

- `tom_cat::admin_password`

## Nginx Reverse Proxy

The module exposes Tomcat through:

- `http://tomcat.jcloudcodes.com`

Managed pieces:

- `/etc/nginx/conf.d/tomcat.conf`
- SELinux boolean for proxy connectivity
- `nginx -t` validation before reload

Tomcat is proxied to:

- `127.0.0.1:8085`

Important note:

- Tomcat is a plain HTTP backend on `8085`
- Nginx is the public HTTP entrypoint

## Useful Validation Commands

### Package and Service

```bash
systemctl status tomcat
systemctl status nginx
ss -lntp | grep 8085
```

### Runtime Validation

```bash
/jcloudcodes/cbtom-cat/data/bin/version.sh
/jcloudcodes/cbtom-cat/data/tomcat-java/bin/java -version
systemctl show tomcat -p Environment --no-pager
cat /jcloudcodes/cbtom-cat/data/bin/setenv.sh
ls -l /jcloudcodes/cbtom-cat/data/tomcat-java
```

### Manager and Web Validation

```bash
curl -I http://127.0.0.1:8085
curl -u admin:admin12345 -I http://127.0.0.1:8085/manager/html
curl -u admin-script:admin12345 http://127.0.0.1:8085/manager/text/list
curl -I http://tomcat.jcloudcodes.com
```

### File Validation

```bash
ls -l /jcloudcodes/cbtom-cat/data/bin
ls -l /jcloudcodes/cbtom-cat/data/conf
xmllint /jcloudcodes/cbtom-cat/data/conf/tomcat-users.xml
```

## Important Fixes and Lessons Learned

### 1. Custom Layout Split

The final Linux layout was intentionally separated into:

- container root:
  - `/jcloudcodes/cbtom-cat`
- active runtime:
  - `/jcloudcodes/cbtom-cat/data`

This keeps the runtime under `data` and avoids mixing parent directory structure with the live Tomcat tree.

### 2. `CATALINA_HOME` / `CATALINA_BASE` Fix

The runtime was adjusted so Tomcat uses:

- `CATALINA_HOME=/jcloudcodes/cbtom-cat/data`
- `CATALINA_BASE=/jcloudcodes/cbtom-cat/data`

This aligned the service, scripts, and deployed content with the final chosen runtime location.

### 3. `startup.sh` / systemd Tracking Fix

The service originally used `startup.sh`, which could report success while the real JVM died immediately after.

The final service pattern uses:

```text
catalina.sh run
```

so systemd tracks the real Tomcat JVM directly.

### 4. Ownership and Bootstrap Class Fix

One failure observed was:

```text
Could not find or load main class org.apache.catalina.startup.Bootstrap
```

Root cause:

- critical runtime files under `bin/` and `conf/` were still owned by `root`
- the `tomcat` user could not read the bootstrap classes correctly

The module was adjusted so the runtime ownership correction covers:

- `bin/bootstrap.jar`
- `bin/tomcat-juli.jar`
- `conf/`
- runtime scripts

### 5. Manager App Remote Access Fix

Tomcat Manager access initially failed due to the default localhost restriction.

Final fix:

- manage:
  - `/jcloudcodes/cbtom-cat/data/webapps/manager/META-INF/context.xml`
- remove the restrictive localhost-only access rule

This is now handled in module code rather than by manual edits.

### 6. Tomcat Manager Authentication Fix

Symptoms:

- Manager login failed
- `401 Unauthorized`
- Tomcat logs showed:
  - `No UserDatabase component found under key [UserDatabase]`

Investigation commands used:

```bash
curl -u admin:admin12345 -I http://localhost:8085/manager/html
curl -u admin-script:admin12345 http://localhost:8085/manager/text/list
journalctl -u tomcat -n 100 --no-pager
xmllint /jcloudcodes/cbtom-cat/conf/tomcat-users.xml
```

Root cause:

- malformed or incomplete `tomcat-users.xml`

Fix:

- corrected the `tomcat-users.xml` template
- validated it with `xmllint`
- ensured the file ends with a proper closing `</tomcat-users>` tag

### 7. `server.xml` / UserDatabase Fix

Tomcat authentication also depended on the correct `server.xml` pieces:

- `GlobalResourcesLifecycleListener`
- `GlobalNamingResources`
- `UserDatabaseRealm`

Those were added and corrected in the managed `server.xml.epp`.

### 8. Clean Install Consistency Fix

After reset/reinstall, the module could fail when managing Manager context if:

- `webapps/manager` did not exist yet

This was fixed by:

- seeding default Tomcat `webapps` on clean install
- ensuring `manager/META-INF` exists before managing `context.xml`

### 9. Preserve `webapps` During Upgrade

Originally, upgrade behavior could wipe deployed applications because the runtime cleanup removed everything under the install directory.

Final design:

- Tomcat is extracted to a staging directory
- runtime files are synced into the live runtime with:
  - `rsync -a --delete --exclude webapps/`

This preserves deployed applications under:

- `/jcloudcodes/cbtom-cat/data/webapps`

while still replacing Tomcat runtime files.

### 10. `rsync` Dependency Fix

When the preserve-`webapps` upgrade logic was added, one failure was:

```text
rsync: command not found
```

Fix:

- `rsync` was added as a managed package dependency in the module

### 11. Nginx / SELinux 502 Fix

Symptoms:

- Nginx returned `502 Bad Gateway`
- Tomcat itself was healthy locally

Root cause:

- SELinux blocked Nginx from connecting to the Tomcat backend

Fix:

```bash
setsebool -P httpd_can_network_connect 1
```

This behavior is now managed in the Nginx class.

### 12. Root App / Default Home Page Behavior

If a sample WAR is deployed as:

- `ROOT.war`

then visiting:

- `http://host:8085/`

shows that sample app, not the default Tomcat landing page.

This is normal Tomcat behavior and not a module bug.

## Troubleshooting

### Tomcat Not Starting

Useful commands:

```bash
systemctl status tomcat
journalctl -u tomcat -n 100 --no-pager
tail -100 /jcloudcodes/cbtom-cat/data/logs/catalina.out
ls -l /jcloudcodes/cbtom-cat/data/bin
ls -l /jcloudcodes/cbtom-cat/data/conf
```

Check:

- runtime ownership
- `server.xml`
- `tomcat-users.xml`
- bootstrap jars
- Java symlink

### Manager Login Fails

Useful commands:

```bash
curl -u admin:admin12345 -I http://localhost:8085/manager/html
curl -u admin-script:admin12345 http://localhost:8085/manager/text/list
xmllint /jcloudcodes/cbtom-cat/data/conf/tomcat-users.xml
journalctl -u tomcat -n 100 --no-pager
```

Check:

- `tomcat-users.xml` is valid XML
- `server.xml` has the UserDatabase configuration
- Manager `context.xml` is correct

### Nginx Returns 502

Useful commands:

```bash
systemctl status tomcat
systemctl status nginx
curl -I http://127.0.0.1:8085
cat /etc/nginx/conf.d/tomcat.conf
nginx -t
tail -50 /var/log/nginx/tomcat-error.log
getenforce
```

If SELinux is enforcing, confirm the boolean:

```bash
getsebool httpd_can_network_connect
```

### Service Keeps Correcting to Running

If Puppet only keeps showing:

```text
Service[tomcat]/ensure changed 'stopped' to 'running'
```

then the install/config side is usually converged and the remaining problem is a runtime/service startup failure.

Check the Tomcat logs rather than assuming a package issue.

### Windows Validation

On Windows, validate:

- service exists
- install path exists
- generated `setenv.bat`
- Tomcat starts with the configured Java version

Use PowerShell checks such as:

```powershell
Get-Service tomcat
Test-Path C:\Tomcat
```

## Upgrade Behavior

A clean Tomcat upgrade should ideally:

- stop the service
- back up the previous runtime when needed
- replace Tomcat runtime files
- preserve deployed applications in `webapps`
- restart cleanly without re-running full install work every time

## Uninstall Behavior

The uninstall flow removes:

- Tomcat service/unit
- custom runtime under `/jcloudcodes/cbtom-cat`
- custom Java under `/jcloudcodes/cbtomcat-java`
- related Nginx config and package cleanup
- stale PID and systemd cleanup where needed

## Recommended Validation After Changes

```bash
puppet agent -t
systemctl status tomcat
systemctl status nginx
/jcloudcodes/cbtom-cat/data/bin/version.sh
/jcloudcodes/cbtom-cat/data/tomcat-java/bin/java -version
systemctl show tomcat -p Environment --no-pager
curl -I http://127.0.0.1:8085
curl -I http://tomcat.jcloudcodes.com
xmllint /jcloudcodes/cbtom-cat/data/conf/tomcat-users.xml
```
