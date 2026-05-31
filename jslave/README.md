## jslave

This module manages a Jenkins Linux inbound agent with:

- Amazon Corretto installed under a custom path
- A dedicated Jenkins SSH agent user
- SSH authorized key access for the Jenkins controller
- A custom workspace and Java path for SSH-launched builds
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
ls -l /jcloudcodes/jslave
ls -l /jcloudcodes/jslave-java
cat /home/jenkins/.ssh/authorized_keys
su - jenkins -s /bin/bash -c '/jcloudcodes/jslave/jenkins-java/bin/java -version'
```
