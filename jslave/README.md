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

### Validation Commands

```bash
systemctl status sshd
systemctl status nginx
ls -l /jcloudcodes/jslave
ls -l /jcloudcodes/jslave-java
cat /home/jenkins/.ssh/authorized_keys
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
  If you manage `/var/lib/jenkins/.ssh/known_hosts`, choose the known-hosts based strategy.

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
  `/var/lib/jenkins/.ssh/id_ed25519`

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
  `/var/lib/jenkins/.ssh/id_ed25519`

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
  `/var/lib/jenkins/.ssh/id_ed25519`

Important mapping:

- Jenkins controller private key:
  `/var/lib/jenkins/.ssh/id_ed25519`

- Matching public key installed by Puppet on the agent:
  `jslave::ssh_public_key`

- Agent login user created by Puppet:
  `jenkins`

Important:

- the `Username` must match the slave user created by Puppet:
  `jenkins`

- the public key from:
  `/var/lib/jenkins/.ssh/id_ed25519.pub`
  is what was installed into the slave’s `authorized_keys`

- the private key from:
  `/var/lib/jenkins/.ssh/id_ed25519`
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

- `Credentials`
  add the Jenkins controller private key that matches the public key you put on the slave

- Click `Save`

Then when creating the node:

- `Launch method`
  `Launch agents via SSH`

- `Host`
  `jslave` IP or DNS

- `Credentials`
  choose `jslave-ssh-key`

### Controller-Side Known Hosts

If Jenkins reports that `/var/lib/jenkins/.ssh/known_hosts` is missing, create and populate it on the controller:

```bash
sudo mkdir -p /var/lib/jenkins/.ssh
sudo touch /var/lib/jenkins/.ssh/known_hosts
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh
sudo chmod 600 /var/lib/jenkins/.ssh/known_hosts
sudo -u jenkins ssh-keyscan -H jslave.jcloudcodes.com >> /var/lib/jenkins/.ssh/known_hosts
```

Useful controller-side checks:

```bash
sudo cat /var/lib/jenkins/.ssh/id_ed25519.pub
sudo cat /var/lib/jenkins/.ssh/id_ed25519
sudo -u jenkins cat /var/lib/jenkins/.ssh/known_hosts
ls -l /var/lib/jenkins/.ssh
```
