## jslave

This module manages a Jenkins Linux inbound agent with:

- Amazon Corretto installed under a custom path
- A dedicated Jenkins SSH agent user
- SSH authorized key access for the Jenkins controller
- A custom workspace and Java path for SSH-launched builds
- An optional NGINX status page exposed as `jslave.jcloudcodes.com`
- Separate install, config, service, upgrade, and uninstall classes

### Module Layout

- `manifests/init.pp`
  Orchestrates install, config, service, upgrade, and uninstall actions.

- `manifests/install.pp`
  Installs Corretto, creates the custom runtime directories, and prepares the agent path layout.

- `manifests/config.pp`
  Configures SSH access, agent workspace paths, and agent runtime environment.

- `manifests/service.pp`
  Ensures the SSH service is enabled and running.

- `manifests/nginx.pp`
  Exposes a simple HTTP status page for the SSH agent host.

- `manifests/upgrade.pp`
  Handles SSH service restarts and optional agent package refresh actions.

- `manifests/uninstall.pp`
  Stops and removes the Jenkins agent service and custom runtime paths.

### Runtime Paths

- Agent root: `/jcloudcodes/jslave`
- Agent workdir: `/jcloudcodes/jslave/data`
- Java root: `/jcloudcodes/jslave-java`
- Java symlink used by the agent: `/jcloudcodes/jslave/jenkins-java`
- Authorized keys root: `/jcloudcodes/customer-authorization`
- Real authorized keys directory: `/jcloudcodes/customer-authorization/.ssh`
- Real authorized keys file: `/jcloudcodes/customer-authorization/.ssh/authorized_keys`
- Agent home: `/home/jenkins`

### Required Console Parameters

- `action`
  Example: `install`

- `java_version`
  Full Corretto version.
  Example: `17.0.19.10.1`

All other agent values are resolved from Hiera:

- `jslave::controller_host`
- `jslave::agent_name`
- `jslave::agent_labels`
- `jslave::ssh_public_key`

### Configure Slave SSH Key with Eyaml

The `jslave` module stores the Jenkins controller public key in:

```text
/jcloudcodes/customer-authorization/.ssh/authorized_keys
```

To keep standard SSH login behavior, the module also makes:

```text
/home/jenkins/.ssh
```

point to:

```text
/jcloudcodes/customer-authorization/.ssh
```

That value should be stored in:

- [common.eyaml](/Users/makutaworldmpm/Desktop/eagunu_2025/jcloudcodes/programming/infra_coding/puppet-modules/jslave/data/common.eyaml)

The source public key comes from the Jenkins controller custom key path:

```bash
cat /jcloudcodes/customer-ssh-keys/jenkins/id_ed25519.pub
```

Example public key:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAmyc01CD+cgNthDdg+u92QujW2sb4V6QKioKcZVccaL jenkins@jenkins
```

Encrypt it on the Puppet server with the eyaml public key:

```bash
/usr/local/bin/eyaml encrypt \
  -s 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAmyc01CD+cgNthDdg+u92QujW2sb4V6QKioKcZVccaL jenkins@jenkins' \
  --pkcs7-public-key /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem
```

Take the `block: >` output and store it in:

```yaml
jslave::ssh_public_key: >
  ENC[PKCS7,...]
```

Example file target:

- [common.eyaml](/Users/makutaworldmpm/Desktop/eagunu_2025/jcloudcodes/programming/infra_coding/puppet-modules/jslave/data/common.eyaml)

Verify decryption on the Puppet server before running the agent:

```bash
sudo /usr/local/bin/eyaml decrypt \
  --pkcs7-private-key /etc/puppetlabs/puppet/eyaml/private_key.pkcs7.pem \
  --pkcs7-public-key /etc/puppetlabs/puppet/eyaml/public_key.pkcs7.pem \
  -f /etc/puppetlabs/code/environments/production/modules/jslave/data/common.eyaml
```

It should print the original SSH public key line.

Then run Puppet on the slave host:

```bash
puppet agent -t
```

Validate that the public key was installed:

```bash
cat /jcloudcodes/customer-authorization/.ssh/authorized_keys
ls -ld /home/jenkins/.ssh
```

That file should contain the same controller public key from:

```text
/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519.pub
```

### Validation Commands

```bash
systemctl status sshd
systemctl status nginx
ls -l /jcloudcodes/jslave
ls -l /jcloudcodes/jslave-java
cat /jcloudcodes/customer-authorization/.ssh/authorized_keys
ls -ld /home/jenkins/.ssh
cat /jslave/jslave-nginx.conf.epp
curl -I http://jslave.jcloudcodes.com/healthz
su - jenkins -s /bin/bash -c '/jcloudcodes/jslave/jenkins-java/bin/java -version'
```

### Add Jenkins UI Configurations

After Puppet prepares the `jslave` host, create the agent node on the Jenkins controller.

In Jenkins UI:

- `Manage Jenkins`
- `Nodes`
- `New Node`

Set:

- `Node name`
  Example: `jenkins`

- `Type`
  `Permanent Agent`

This is the plain static agent type for machines managed outside Jenkins.

### Sample Filled Node Configuration

Use this as a working example in Jenkins UI.

- `Manage Jenkins`
- `Nodes`
- `New Node`

Fill the page like this:

- `Node name`
  `jenkins`

- `Type`
  `Permanent Agent`

- Click `Create`

Then fill the configuration form exactly like this:

- `Name`
  `jenkins`

- `Description`
  `Linux SSH agent managed by Puppet`

- `Number of executors`
  `1`

- `Remote root directory`
  `/jcloudcodes/jslave/data`
  This field is mandatory.

- `Labels`
  `linux ssh agent`
  You can leave this blank, but labels are recommended.

- `Usage`
  `Use this node as much as possible`

- `Launch method`
  `Launch agents via SSH`
  Do not choose:
  `Launch agent by connecting it to the controller`
  That option is for inbound agents, not this SSH-based `jslave` module.

- `Host`
  `jslave.jcloudcodes.com`
  If DNS is not ready yet, use the Linux agent IP instead.

- `Credentials`
  `jslave-ssh-key`

- `Host Key Verification Strategy`
  `Known hosts file Verification Strategy`

- `Availability`
  `Keep this agent online as much as possible`

- `Node Properties`
  Leave unchecked unless you specifically need them.

- `Disable deferred wipeout on this node`
  leave unchecked

- `Disk Space Monitoring Thresholds`
  leave unchecked unless your team uses custom monitoring values

- `Environment variables`
  leave unchecked unless you need node-specific environment variables

- `Tool Locations`
  leave unchecked unless you need Jenkins tool overrides on this agent

- Click `Save`

After saving:

- open the new node
- click the agent entry
- click `Launch agent`
- watch the connection log

If the SSH setup is correct, Jenkins should connect as user `jenkins` and bring the node online.

### Exact UI Field Mapping

If you want to match the Jenkins form field-by-field, use:

- `Manage Jenkins`
- `Nodes`
- `New Node`
- `Node name`
  `jenkins`
- `Type`
  `Permanent Agent`
- `Name`
  `jenkins`
- `Description`
  `Linux SSH agent managed by Puppet`
- `Number of executors`
  `1`
- `Remote root directory`
  `/jcloudcodes/jslave/data`
- `Labels`
  `linux ssh agent`
- `Usage`
  `Use this node as much as possible`
- `Launch method`
  `Launch agents via SSH`
- `Availability`
  `Keep this agent online as much as possible`
- `Node Properties`
  leave unchecked by default

Then configure the node:

- `Number of executors`
  Example: `1`

- `Remote root directory`
  `/jcloudcodes/jslave/data`

- `Labels`
  Example: `linux ssh agent`
  Use the value that matches `jslave::agent_labels` if you want consistency with Hiera.

- `Usage`
  `Use this node as much as possible`

- `Launch method`
  `Launch agents via SSH`

- `Host`
  Use the agent host DNS name or IP.
  Example: `jslave.jcloudcodes.com`

- `Credentials`
  Choose the SSH credential created from the Jenkins controller private key.

- `Host Key Verification Strategy`
  Use the strategy your team prefers.
  If you manage `/jcloudcodes/customer-ssh-keys/jenkins/known_hosts`, choose the known-hosts based strategy.

### Add Jenkins SSH Credential

Before saving the node, add the SSH credential Jenkins will use to log in to the agent.

In Jenkins UI:

- `Manage Jenkins`
- `Credentials`
- `System`
- `Global credentials (unrestricted)`
- `Add Credentials`

Set:

- `Kind`
  `SSH Username with private key`

- `Scope`
  `Global`

- `Username`
  `jenkins`

- `Private Key`
  `Enter directly`

- Paste the contents of:
  `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519`

- `ID`
  Example: `jslave-ssh-key`

- `Description`
  Example: `Jenkins SSH key for jslave`

### Short Jenkins Credential Workflow

Then in Jenkins UI:

- Go to `Manage Jenkins`
- Go to `Credentials`
- Choose the scope/store you want, usually:
  `System`
  `Global credentials (unrestricted)`
- Click `Add Credentials`

Set:

- `Kind`
  `SSH Username with private key`

- `Scope`
  `Global`

- `Username`
  `jenkins`

- `Private Key`
  `Enter directly`

- paste the contents of:
  `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519`

- `ID`
  something like `jslave-ssh-key`

- `Description`
  `Jenkins SSH key for jslave`

- Click `Save`

### Sample Filled SSH Credential

Use this example when adding the SSH credential in Jenkins:

- `Kind`
  `SSH Username with private key`

- `Scope`
  `Global`

- `ID`
  `jslave-ssh-key`

- `Username`
  `jenkins`

- `Private Key`
  `Enter directly`

- `Passphrase`
  leave blank if the key was created with `-N ''`

- `Description`
  `Jenkins SSH key for jslave`

- Paste into `Private Key`
  the full contents of:
  `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519`

Important mapping:

- Jenkins controller private key:
  `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519`

- Matching public key installed by Puppet on the agent:
  `jslave::ssh_public_key`

- Agent login user created by Puppet:
  `jenkins`

Important:

- the `Username` must match the slave user created by Puppet:
  `jenkins`

- the public key from:
  `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519.pub`
  is what was installed into the slave’s `authorized_keys`

- the private key from:
  `/jcloudcodes/customer-ssh-keys/jenkins/id_ed25519`
  is what Jenkins uses to log in

### Short Jenkins Node Workflow

And add the agent node like this.

What to do in Jenkins:

- Open `Manage Jenkins -> Nodes`
- Click `New Node`
- Name it:
  `jenkins-agent-01`
  or whatever matches your `jslave::agent_name`
- Choose:
  `Permanent Agent`

Set:

- `Remote root directory`
  `/jcloudcodes/jslave/data`

- `Labels`
  `linux docker`
  or whatever matches your `jslave::agent_labels`

- `Launch method`
  `Launch agents via SSH`

- `Host`
  the slave IP or DNS name
  Example: `jslave.jcloudcodes.com`

- `Credentials`
  add the Jenkins controller private key that matches the public key you put on the slave

- Click `Save`

Then when creating the node:

- `Launch method`
  `Launch agents via SSH`

- `Host`
  `jslave` IP or DNS
  Example: `jslave.jcloudcodes.com`

- `Credentials`
  choose `jslave-ssh-key`

### Controller-Side Known Hosts

Recommended shared controller-side SSH key location:

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

If Jenkins reports that `/jcloudcodes/customer-ssh-keys/jenkins/known_hosts` is missing, create and populate it on the controller:

```bash
sudo mkdir -p /jcloudcodes/customer-ssh-keys/jenkins
sudo touch /jcloudcodes/customer-ssh-keys/jenkins/known_hosts
sudo chown -R jenkins:jenkins /jcloudcodes/customer-ssh-keys
sudo chmod 700 /jcloudcodes/customer-ssh-keys/jenkins
sudo chmod 600 /jcloudcodes/customer-ssh-keys/jenkins/known_hosts
sudo -u jenkins ssh-keyscan -H jslave.jcloudcodes.com >> /jcloudcodes/customer-ssh-keys/jenkins/known_hosts
```

Useful controller-side checks:

```bash
sudo cat /jcloudcodes/customer-ssh-keys/jenkins/id_ed25519.pub
sudo cat /jcloudcodes/customer-ssh-keys/jenkins/id_ed25519
sudo -u jenkins cat /jcloudcodes/customer-ssh-keys/jenkins/known_hosts
ls -l /jcloudcodes/customer-ssh-keys/jenkins
```
