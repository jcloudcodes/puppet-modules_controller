# Puppet Modules

This repository contains Puppet modules used to build and manage the `jcloudcodes.com` lab environment through Puppet and Foreman.

The current modules cover:

- Jenkins controller
- Tomcat application server
- Jenkins SSH agent
- Nginx exposure patterns for controller, app, and agent hosts

The repository also includes GitHub Actions deployment workflows and remote validation scripts so module changes can be pushed safely to the Puppet server.

## Repository Layout

```text
puppet-modules/
├── .github/workflows/
│   ├── deploy-jenkins-master.yml
│   ├── deploy-jslave.yml
│   └── deploy-tomcat.yml
├── cbjenkins/
├── cbtom-cat/
├── ci-cd/
│   ├── cbjenkins/
│   ├── cbtom-cat/
│   └── jslave/
└── jslave/
```

## Modules

### `cbjenkins`

Manages a Jenkins controller on Linux with:

- Jenkins installed from the official Jenkins RPM repository
- Amazon Corretto installed in a custom path
- Jenkins home moved to `/jcloudcodes/cbjenkins/data`
- systemd override for Java and runtime control
- Nginx reverse proxy exposure through `jenkins.jcloudcodes.com`
- install, upgrade, config, service, uninstall, and Nginx separation

Important runtime paths:

```text
/jcloudcodes/cbjenkins
├── data
└── jenkins-java -> /jcloudcodes/cbjenkins-java/amazon-corretto-<version>-linux-x64
```

Top-level Puppet class:

- `jenkins_master`

### `cbtom-cat`

Manages Tomcat on Linux and Windows with:

- Amazon Corretto installed in a custom path
- Tomcat runtime under `/jcloudcodes/cbtom-cat/data`
- Tomcat Manager configuration and credentials
- upgrade flow that preserves deployed applications in `webapps`
- Nginx reverse proxy exposure through `tomcat.jcloudcodes.com`
- install, upgrade, config, service, uninstall, and Nginx separation

Important runtime paths:

```text
/jcloudcodes/cbtom-cat
└── data

/jcloudcodes/cbtomcat-java
```

Top-level Puppet class:

- `tom_cat`

### `jslave`

Manages a Jenkins SSH agent host with:

- Amazon Corretto installed in a custom path
- agent user and SSH authorized key setup
- SSH-ready workspace for Jenkins jobs
- optional Nginx status page exposure through `jslave.jcloudcodes.com`

Important runtime paths:

```text
/jcloudcodes/jslave
├── data
└── jenkins-java -> /jcloudcodes/jslave-java/amazon-corretto-<version>-linux-x64
```

Top-level Puppet class:

- `jslave`

## Nginx Summary

This repository does not use one standalone shared Nginx module. Instead, Nginx behavior is managed inside the application modules where it belongs.

### Jenkins Nginx

Managed by:

- `cbjenkins/manifests/nginx.pp`

Purpose:

- expose Jenkins at `jenkins.jcloudcodes.com`
- preserve forwarded host/proto headers so Jenkins shows the public URL instead of the backend IP
- validate `nginx -t` before reload
- set the SELinux boolean needed for reverse proxy connectivity

### Tomcat Nginx

Managed by:

- `cbtom-cat/manifests/nginx.pp`

Purpose:

- expose Tomcat at `tomcat.jcloudcodes.com`
- proxy HTTP traffic to local Tomcat on port `8085`
- validate `nginx -t` before reload
- set the SELinux boolean needed for backend connectivity

### Jenkins Slave Nginx

Managed by:

- `jslave/manifests/nginx.pp`

Purpose:

- expose a simple status endpoint at `jslave.jcloudcodes.com`
- provide `/healthz` for basic host validation
- avoid trying to proxy SSH through Nginx

Current exposed endpoints:

- `jenkins.jcloudcodes.com`
- `tomcat.jcloudcodes.com`
- `jslave.jcloudcodes.com`

## Design Approach

The modules are intentionally split by responsibility.

Typical flow:

```text
install.pp   -> install software and prerequisites
upgrade.pp   -> lightweight upgrade or post-change handling
config.pp    -> manage runtime configuration
service.pp   -> manage service enable/start/restart
nginx.pp     -> manage reverse proxy where applicable
uninstall.pp -> remove software and custom runtime paths
```

This keeps package installation separate from runtime configuration and makes troubleshooting much easier.

## Foreman / Puppet Usage

Only assign the top-level classes in Foreman:

- `jenkins_master`
- `tom_cat`
- `jslave`

Do not assign internal child classes such as:

- `jenkins_master::install`
- `tom_cat::config`
- `jslave::service`

Those are orchestrated by the parent class.

## Parameters

The modules use a mix of:

- console/Foreman parameters for install-time version control
- Hiera values for defaults and environment-specific settings
- eyaml for encrypted values

### Jenkins controller

Typical class parameters:

- `action`
- `jenkins_version`
- `corretto_jdk_version`

Key Hiera values:

- `jenkins_master::http_port`
- `jenkins_master::listen_address`
- `jenkins_master::nginx_server_name`

### Tomcat

Typical class parameters:

- `action`
- `environment`
- `tom_version`
- `java_version`

Key Hiera values:

- `tom_cat::connector_port`
- `tom_cat::admin_user`
- `tom_cat::nginx_server_name`

Encrypted eyaml value:

- `tom_cat::admin_password`

### Jenkins SSH agent

Typical class parameters:

- `action`
- `java_version`

Key Hiera values:

- `jslave::controller_host`
- `jslave::agent_name`
- `jslave::agent_labels`
- `jslave::nginx_server_name`

Encrypted eyaml value:

- `jslave::ssh_public_key`

## Parameter Type Notes

Version parameters should usually be stored in Foreman as `string`.

Examples:

- `2.555.2-1`
- `10.1.24`
- `21.0.11.10.1`

Do not type `undef` into a Foreman string parameter field. If you do not want a default, leave the value blank instead.

## Encrypted Data

Modules that use secrets rely on eyaml.

Current pattern:

- `data/common.yaml` for non-secret defaults
- `data/common.eyaml` for encrypted values
- `hiera.yaml` inside the module points to the Puppet server eyaml certificate paths

Example encrypted values in this repository:

- Tomcat Manager password
- Jenkins SSH agent public key

## Nginx Exposure

Current Nginx-backed endpoints:

- `jenkins.jcloudcodes.com`
- `tomcat.jcloudcodes.com`
- `jslave.jcloudcodes.com`

Important notes:

- Jenkins and Tomcat use reverse proxy behavior
- `jslave` is an SSH agent host, so its Nginx config exposes a small HTTP status page rather than proxying SSH
- SELinux systems require `httpd_can_network_connect` when Nginx needs backend connectivity

## GitHub Actions Deployment

Each major module has a deployment workflow that:

1. verifies the module path exists
2. validates required Puppet manifest files exist
3. prepares the remote module path on the Puppet server
4. backs up the current deployed module
5. syncs the updated module with `rsync`
6. runs remote `puppet parser validate`

Current workflows:

- `.github/workflows/deploy-jenkins-master.yml`
- `.github/workflows/deploy-tomcat.yml`
- `.github/workflows/deploy-jslave.yml`

Remote validation scripts:

- `ci-cd/cbjenkins/deploy_jenkins_master.sh`
- `ci-cd/cbtom-cat/deploy_tomcat.sh`
- `ci-cd/jslave/deploy_jslave.sh`

## Operational Notes

### Jenkins SSH agent behavior

The `jslave` module prepares the host for SSH-based Jenkins agent access, but Jenkins still needs a node definition on the controller side.

That means:

1. Puppet prepares the host
2. Jenkins controller must have the matching SSH private key credential
3. A Jenkins node must be created in `Manage Jenkins -> Nodes`

### Tomcat upgrade behavior

Tomcat upgrades are designed to preserve deployed applications under `webapps` while replacing Tomcat runtime files.

### Uninstall behavior

Jenkins and Tomcat uninstall flows remove:

- service definitions
- custom runtime trees
- related Nginx config and package cleanup

`jslave` uninstall removes the agent user, custom runtime paths, and optional Nginx status configuration, but does not tear down the entire host SSH stack beyond module-owned resources.

## Validation Commands

Useful commands after Puppet runs:

### Jenkins

```bash
rpm -q --qf '%{VERSION}-%{RELEASE}\n' jenkins
systemctl status jenkins
systemctl status nginx
cat /etc/sysconfig/jenkins
cat /etc/systemd/system/jenkins.service.d/override.conf
```

### Tomcat

```bash
systemctl status tomcat
systemctl status nginx
/jcloudcodes/cbtom-cat/data/bin/version.sh
curl -I http://127.0.0.1:8085
```

### Jenkins SSH agent

```bash
systemctl status sshd
systemctl status nginx
ls -l /home/jenkins/.ssh
cat /home/jenkins/.ssh/authorized_keys
curl -I http://jslave.jcloudcodes.com/healthz
```

## Recommended Next Improvements

- Add controller-side automation for Jenkins SSH node creation
- Add Puppet parser validation locally in CI with a Puppet toolchain container
- Add environment-specific Hiera layers beyond `common.yaml`
- Add tests for module structure and expected files
