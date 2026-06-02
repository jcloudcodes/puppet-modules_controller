# puppet-modules_controller

This repository contains the Puppet controller repo used to build and manage the `jcloudcodes.com` lab environment through Puppet and Foreman.

The current modules cover:

- Jenkins controller
- Tomcat application server
- Jenkins SSH agent
- Nginx exposure patterns for controller, app, and agent hosts

The repository also includes GitHub Actions deployment workflows and remote validation scripts so module changes can be pushed safely to the Puppet server.

## Repository Layout

```text
puppet-modules_controller/
├── .github/workflows/
│   ├── deploy-jenkins-master.yml
│   ├── deploy-jslave.yml
│   └── deploy-tomcat.yml
├── ci-cd/
│   ├── github_action/
│   │   ├── cbjenkins/
│   │   ├── cbtom-cat/
│   │   └── jslave/
│   ├── gitlab-ci/
│   └── jenkins-pipeline/
├── puppet-modules_packagings/
│   ├── cbjenkins/
│   └── cbtom-cat/
└── puppet-modules_infra/
    └── jslave/
```

## Modules

### `puppet-modules_packagings/cbjenkins`

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

- `cb_jenkins`

### `puppet-modules_packagings/cbtom-cat`

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

### `puppet-modules_infra/jslave`

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

- `puppet-modules_packagings/cbjenkins/manifests/nginx.pp`

Purpose:

- expose Jenkins at `jenkins.jcloudcodes.com`
- preserve forwarded host/proto headers so Jenkins shows the public URL instead of the backend IP
- validate `nginx -t` before reload
- set the SELinux boolean needed for reverse proxy connectivity

### Tomcat Nginx

Managed by:

- `puppet-modules_packagings/cbtom-cat/manifests/nginx.pp`

Purpose:

- expose Tomcat at `tomcat.jcloudcodes.com`
- proxy HTTP traffic to local Tomcat on port `8085`
- validate `nginx -t` before reload
- set the SELinux boolean needed for backend connectivity

### Jenkins Slave Nginx

Managed by:

- `puppet-modules_infra/jslave/manifests/nginx.pp`

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

- `cb_jenkins`
- `tom_cat`
- `jslave`

Do not assign internal child classes such as:

- `cb_jenkins::install`
- `tom_cat::config`
- `jslave::service`

Those are orchestrated by the parent class.

### If a Module Is Not Showing in Foreman UI

If a deployed module does not appear in Foreman:

1. Confirm Puppet can see the module:

```bash
puppet module list | grep tom_cat
ls -l /etc/puppetlabs/code/environments/production/modules/tom_cat/manifests
cat /etc/puppetlabs/code/environments/production/modules/tom_cat/manifests/init.pp
```

2. Validate the manifest:

```bash
puppet parser validate /etc/puppetlabs/code/environments/production/modules/tom_cat/manifests/init.pp
puppet parser validate /etc/puppetlabs/code/environments/production/modules/tom_cat/manifests/*.pp
```

3. Confirm Hiera lookup works:

```bash
puppet lookup tom_cat::base_dir --environment production
```

4. Re-import Puppet classes into Foreman:

```bash
foreman-rake puppet:import:puppet_classes
```

5. Verify Foreman can see the class:

```bash
hammer puppet-class list --search "name = tom_cat"
hammer puppet-class list | grep tom_cat
```

6. Attach the class to the correct host group if needed:

```bash
hammer hostgroup update --name "puppet-tomcat" --environment production
hammer hostgroup add-puppetclass --name "puppet-tomcat" --puppetclass tom_cat
hammer hostgroup info --name puppet-tomcat
```

Useful discovery commands:

```bash
foreman-rake --tasks | grep puppet
hammer hostgroup --help
hammer puppet-class --help
hammer hostgroup update --help
```

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

- `cb_jenkins::http_port`
- `cb_jenkins::listen_address`
- `cb_jenkins::nginx_server_name`

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

### Create and Configure eyaml

On the Puppet server:

1. Install prerequisites:

```bash
sudo dnf install -y ruby ruby-devel gcc gcc-c++ make
sudo gem install hiera-eyaml
```

2. Create eyaml keys:

```bash
sudo mkdir -p /etc/puppetlabs/puppet/eyaml
sudo /usr/local/bin/eyaml createkeys \
  --pkcs7-private-key /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem \
  --pkcs7-public-key /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem
```

3. Set permissions so Puppetserver can read the keys:

```bash
sudo chown root:puppet /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem
sudo chmod 640 /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem
sudo chown root:puppet /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem
sudo chmod 644 /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem
```

4. Verify the `puppet` user can read the private key:

```bash
sudo -u puppet cat /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem >/dev/null && echo ok
```

5. Configure module `hiera.yaml` to use:

```yaml
pkcs7_private_key: /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem
pkcs7_public_key: /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem
```

6. Encrypt a value:

```bash
/usr/local/bin/eyaml encrypt -s 'admin12345' \
  --pkcs7-public-key /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem
```

7. Store the output in `data/common.eyaml`:

```yaml
tom_cat::admin_password: >
  ENC[PKCS7,...]
```

8. Restart Puppetserver after key/permission changes:

```bash
sudo systemctl restart puppetserver
systemctl status puppetserver
ss -lntp | grep 8140
```

If decryption fails, test the ciphertext manually:

```bash
sudo /usr/local/bin/eyaml decrypt \
  --pkcs7-private-key /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem \
  --pkcs7-public-key /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem \
  -f /etc/puppetlabs/code/environments/production/modules/jslave/data/common.eyaml
```

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

- `ci-cd/github_action/cbjenkins/deploy_cb_jenkins.sh`
- `ci-cd/github_action/cbtom-cat/deploy_tomcat.sh`
- `ci-cd/github_action/jslave/deploy_jslave.sh`

## Operational Notes

### Puppet Agent Certificate Registration

When a new agent requests a certificate, sign it from the Puppet server.

List pending requests:

```bash
sudo /opt/puppetlabs/bin/puppetserver ca list
```

Sign one specific agent:

```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign \
  --certname jslave.us-east1-b.c.eagunu-vms-2025-497522.internal
```

Sign all pending agents:

```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --all
```

Show all certificates:

```bash
sudo /opt/puppetlabs/bin/puppetserver ca list --all
```

Then rerun on the agent:

```bash
puppet agent -t
```

### Windows agent SSL / CA mismatch fix

One Windows agent failure seen in this environment was:

```text
Info: Refreshing CA certificate
Error: certificate verify failed [self-signed certificate in certificate chain for CN=Puppet Root CA: 5853579433589f]
```

On the Puppet server, `puppetserver ca list` showed:

```text
No certificates to list
```

That means the Windows agent still had stale local SSL state and never got far enough to submit a fresh CSR.

Fix on the Windows agent:

1. Stop the Puppet service:

```bat
net stop puppet
```

2. Confirm the SSL and config paths:

```bat
puppet config print ssldir
puppet config print confdir
puppet config print server
```

Example values from the working fix:

```text
C:/ProgramData/PuppetLabs/puppet/etc/ssl
C:/ProgramData/PuppetLabs/puppet/etc
puppet.jcloudcodes.com
```

3. Remove the stale SSL directory:

```bat
rmdir /s /q "C:\ProgramData\PuppetLabs\puppet\etc\ssl"
```

4. Reassert the correct Puppet server and CA server:

```bat
puppet config set server puppet.jcloudcodes.com --section main
puppet config set ca_server puppet.jcloudcodes.com --section main
```

5. Request a fresh certificate:

```bat
puppet agent -t
```

Expected result:

```text
Info: Creating a new SSL certificate request for ec2amaz-bo2vfq6.ec2.internal
Info: Certificate Request fingerprint (SHA256): ...
Info: Certificate for ec2amaz-bo2vfq6.ec2.internal has not been signed yet
```

6. Back on the Puppet server, list and sign the pending request:

```bash
sudo /opt/puppetlabs/bin/puppetserver ca list
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname ec2amaz-bo2vfq6.ec2.internal
```

7. Rerun the agent:

```bat
puppet agent -t
```

This is the standard recovery when the agent trusts an old Puppet CA or has stale local SSL material.

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
