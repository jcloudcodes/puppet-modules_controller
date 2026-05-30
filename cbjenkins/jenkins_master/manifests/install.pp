# Installs Jenkins package and Corretto Java only.
# Custom Jenkins config, symlink, permissions, and service overrides are handled in config.pp.
# Jenkins service start/stop is handled in service.pp.

class jenkins_master::install (
  String $jenkins_version,
  String $corretto_jdk_version,
  String $jenkins_package,
  String $jenkins_repo_baseurl,
  String $jenkins_repo_gpg,
  String $jenkins_repo_key_id,
) {

  # Ensure this module only runs on Linux.
  if $facts['kernel'] != 'Linux' {
    fail("${facts['kernel']} is not supported")
  }

  # Set default command path for all exec resources.
  Exec {
    path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  # Extract major Java version from full Corretto version.
  # Example: 21.0.11.10.1 becomes 21.
  $corretto_major_version = regsubst($corretto_jdk_version, '^([0-9]+).*$', '\1')

  # Define base installation paths.
  $java_root            = '/jcloudcodes/cbjenkins-java'
  $jenkins_root         = '/jcloudcodes/cbjenkins'
  $corretto_archive     = "amazon-corretto-${corretto_major_version}-x64-linux-jdk.tar.gz"
  $corretto_download    = "/tmp/${corretto_archive}"
  $corretto_source_url  = "https://corretto.aws/downloads/latest/${corretto_archive}"
  $corretto_extract_dir = "${java_root}/amazon-corretto-${corretto_jdk_version}-linux-x64"

  # Debug values during Puppet run.
  # notify { "corretto_jdk_version: ${corretto_jdk_version}": }
  # notify { "corretto_major_version: ${corretto_major_version}": }
  # notify { "corretto_source_url: ${corretto_source_url}": }
  # notify { "corretto_extract_dir: ${corretto_extract_dir}": }

  # Create parent custom application directory.
  file { '/jcloudcodes':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Create Corretto Java root directory.
  file { $java_root:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/jcloudcodes'],
  }

  # Create Jenkins custom root directory.
  # Jenkins data directory will be managed in config.pp.
  file { $jenkins_root:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/jcloudcodes'],
  }

  # Download Amazon Corretto archive.
  exec { 'download_corretto':
    command => "curl -L -o ${corretto_download} ${corretto_source_url}",
    creates => $corretto_download,
    require => File[$java_root],
  }

  # Extract Amazon Corretto into custom Java root.
  exec { 'extract_corretto':
    command => "tar -xzf ${corretto_download} -C ${java_root}",
    unless  => "test -d ${corretto_extract_dir}",
    require => Exec['download_corretto'],
  }

  # Configure Jenkins yum repository.
  yumrepo { 'jenkins':
    descr    => 'Jenkins Repository',
    baseurl  => $jenkins_repo_baseurl,
    enabled  => 1,
    gpgcheck => 1,
    gpgkey   => $jenkins_repo_gpg,
  }

  # Import Jenkins repository public key.
  exec { 'Manage Jenkins-CI Public Key':
    command => "/bin/bash -c 'curl -fsSL ${jenkins_repo_gpg} -o /tmp/jenkins-ci.org.key && rpm --import /tmp/jenkins-ci.org.key && rm -f /tmp/jenkins-ci.org.key'",
    unless  => "/bin/bash -c 'rpm -qa gpg-pubkey* | grep -qi ${jenkins_repo_key_id}'",
    require => Yumrepo['jenkins'],
  }

  # Install Jenkins package only after Java archive is extracted and repo key is imported.
  package { $jenkins_package:
    ensure  => $jenkins_version,
    require => [
      Exec['extract_corretto'],
      Exec['Manage Jenkins-CI Public Key'],
    ],
  }
  # Ensure Jenkins sysconfig file exists after package installation.
  # This prevents config.pp file_line resources from failing after cleanup/reinstall.
  file { '/etc/sysconfig/jenkins':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package[$jenkins_package],
  }
}
