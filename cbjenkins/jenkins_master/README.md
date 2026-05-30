## jenkins_master

This module manages a Jenkins master installation on Linux with:

- Jenkins installed from the official Jenkins RPM repository
- Amazon Corretto installed under a custom path
- Jenkins runtime configured to use custom home and Java paths
- Jenkins service managed separately from package installation

### Current Module Layout

- `manifests/init.pp`
  Orchestrates install, upgrade, config, and service classes based on the selected action.

- `manifests/install.pp`
  Installs Amazon Corretto under `/jcloudcodes/cbjenkins-java`, configures the Jenkins RPM repository, imports the Jenkins GPG key, and installs the Jenkins RPM package.

- `manifests/config.pp`
  Configures Jenkins runtime behavior. This class manages:
  - Jenkins home under `/jcloudcodes/cbjenkins/data`
  - Jenkins Java symlink under `/jcloudcodes/cbjenkins/jenkins-java`
  - `/etc/sysconfig/jenkins`
  - systemd override configuration
  - log and cache directory ownership
  - logrotate and limits configuration
  - transparent huge page tuning
  - Git package installation for SCM support

- `manifests/service.pp`
  Ensures the Jenkins service is enabled and running after configuration is complete.

- `manifests/upgrade.pp`
  Handles post-install or post-upgrade systemd reload and Jenkins failed-state reset.

- `manifests/uninstall.pp`
  Handles uninstall behavior when `action => 'uninstall'` is used.

### Runtime Paths

The module currently uses these custom paths:

- Jenkins root: `/jcloudcodes/cbjenkins`
- Jenkins home: `/jcloudcodes/cbjenkins/data`
- Java root: `/jcloudcodes/cbjenkins-java`
- Java symlink used by Jenkins: `/jcloudcodes/cbjenkins/jenkins-java`

Important note:

- Jenkins is installed as an RPM package from the official Jenkins repository.
- That means the Jenkins package files still come from standard RPM-managed locations.
- The custom path under `/jcloudcodes/cbjenkins` is the Jenkins runtime home and Java location, not a fully custom WAR-only installation model.

### Installation Flow

At a high level, the module currently works like this:

1. `install.pp`
   - creates `/jcloudcodes`
   - creates `/jcloudcodes/cbjenkins`
   - creates `/jcloudcodes/cbjenkins-java`
   - downloads Amazon Corretto to `/tmp`
   - extracts Corretto into `/jcloudcodes/cbjenkins-java`
   - configures the Jenkins yum repo
   - imports the Jenkins public key
   - installs the Jenkins package

2. `config.pp`
   - creates `/jcloudcodes/cbjenkins/data`
   - creates the Java symlink
   - writes Jenkins runtime values into `/etc/sysconfig/jenkins`
   - writes a systemd override to force Jenkins home and Java

3. `service.pp`
   - enables and starts the Jenkins service

### Required Console Parameters

These values are expected from the UI / console:

- `action`
  Example: `install`

- `jenkins_version`
  This must be the Jenkins RPM version, not the Java major version.
  Example: `2.555.2-1`

- `corretto_jdk_version`
  This is the full Amazon Corretto version used to build the extracted directory path.
  Example: `17.0.19.10.1`

- `git_version`
  Optional at the module level today, depending on future tool-management work.

### Hiera Values

Current defaults from `data/common.yaml`:

```yaml
jenkins_master::http_port: '8080'
jenkins_master::ajp_port: '-1'
jenkins_master::manage_repo: true
jenkins_master::manage_java: false
jenkins_master::service_name: 'jenkins'
jenkins_master::jenkins_user: 'jenkins'
jenkins_master::listen_address: '0.0.0.0'
jenkins_master::jenkins_package: 'jenkins'
jenkins_master::jenkins_repo_key_id: '14ABFC68'
jenkins_master::config_file: '/etc/sysconfig/jenkins'
jenkins_master::jenkins_repo_baseurl: 'https://pkg.jenkins.io/rpm-stable'
jenkins_master::jenkins_repo_gpg: 'https://pkg.jenkins.io/rpm-stable/jenkins.io-2026.key'
```

### Useful Validation Commands

After a Puppet run, these commands are useful for validation:

```bash
dnf list --showduplicates jenkins
rpm -qi jenkins
systemctl status jenkins
ls -l /jcloudcodes/cbjenkins
ls -l /jcloudcodes/cbjenkins-java
cat /etc/sysconfig/jenkins
cat /etc/systemd/system/jenkins.service.d/override.conf
```

### Current Design Notes

- `install.pp` should install software and prerequisites only.
- `config.pp` should manage Jenkins runtime configuration.
- `service.pp` should manage service enable/start/restart behavior.
- This separation is already reflected in the current module structure and is the preferred direction for production use.

### Existing Notes

internet access is restricted,
Git version must be controlled,
security-approved binaries are stored in Nexus/Artifactory,
Jenkins needs a specific Git version.

For your module design, better approach is:

install.pp  = Jenkins + Java
config.pp   = Jenkins runtime config
tools.pp    = optional Git/custom tools
service.pp  = Jenkins service

But if you want quick integration, you can add custom Git installation into config.pp.

A cleaner production-ready version of your Git logic:

# Install custom Git build for Jenkins SCM support.
#
# This supports:
# - Pipeline script from SCM
# - Git repository validation from Jenkins UI
# - Enterprise-controlled Git version

if $manage_tools == 'yes' {

  $git_root          = '/jcloudcodes/tools'
  $git_extract_dir   = "${git_root}/git-${git_version}"
  $git_archive       = "git-${git_version}.tar.gz"
  $git_archive_path  = "/tmp/${git_archive}"

  # Create tools root directory.
  file { $git_root:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Download custom Git archive from Nexus or internal repository.
  exec { 'download_custom_git':
    command => "curl -L -o ${git_archive_path} ${nexus_repo}/git/${git_archive}",
    creates => $git_archive_path,
    require => File[$git_root],
  }

  # Extract Git archive.
  exec { 'extract_custom_git':
    command => "tar -xzf ${git_archive_path} -C ${git_root}",
    unless  => "test -f ${git_extract_dir}/bin/git",
    require => Exec['download_custom_git'],
  }

  # Create global Git symlink.
  file { '/usr/bin/git':
    ensure  => link,
    target  => "${git_extract_dir}/bin/git",
    force   => true,
    require => Exec['extract_custom_git'],
  }

  # Fix older Git library dependency if required.
  exec { 'git_lib_fix':
    command => '/usr/bin/ln -s /usr/lib64/libpcre.so.1 /usr/lib64/libpcre.so.0',
    onlyif  => '/usr/bin/test ! -f /usr/lib64/libpcre.so.0',
    require => File['/usr/bin/git'],
  }

  # Validate installed Git version.
  exec { 'validate_custom_git':
    command   => '/usr/bin/git --version',
    logoutput => true,
    require   => File['/usr/bin/git'],
  }
}

Then in init.pp, pass:

manage_tools => $manage_tools,
git_version  => $git_version,

Production recommendation:

Jenkins module
├── install.pp
├── upgrade.pp
├── config.pp
├── service.pp
├── uninstall.pp
└── tools.pp   <-- best place for Git/custom tools

Instead of putting everything into config.pp.

what is in this nexus_repo for git

$nexus_repo is meant to be your internal Nexus artifact repository URL where the custom Git tarball is stored.

Example:

$nexus_repo = 'http://nexus.jcloudcodes.com:8081/repository/tools'

Then this line:

source => "${nexus_repo}/git/git-${git_version}.tar.gz"

becomes:

http://nexus.jcloudcodes.com:8081/repository/tools/git/git-2.47.0.tar.gz

Typical Nexus layout:

repository/
└── tools/
    └── git/
        ├── git-2.47.0.tar.gz
        ├── git-2.46.1.tar.gz
        └── git-2.45.0.tar.gz

You would upload the tarball manually into Nexus.

Example upload path:

curl -u admin:password \
--upload-file git-2.47.0.tar.gz \
http://nexus.jcloudcodes.com:8081/repository/tools/git/git-2.47.0.tar.gz

Then Puppet downloads it:

command => "curl -L -o ${git_archive_path} ${nexus_repo}/git/${git_archive}"

So:

nexus_repo = base repository URL
git_version = version folder/file selector

Example final values:

$nexus_repo = 'http://nexus.jcloudcodes.com:8081/repository/tools'
$git_version = '2.47.0'

Result:

http://nexus.jcloudcodes.com:8081/repository/tools/git/git-2.47.0.tar.gz

not 
