class jslave::install (
  String $java_version,
  String $agent_root,
  String $agent_home,
  String $java_root,
  String $agent_user,
  String $agent_group,
) {

  if $facts['kernel'] != 'Linux' {
    fail("${facts['kernel']} is not supported")
  }

  Exec {
    path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  $corretto_major_version = regsubst($java_version, '^([0-9]+).*$', '\1')
  $corretto_archive       = "amazon-corretto-${corretto_major_version}-x64-linux-jdk.tar.gz"
  $corretto_download      = "/tmp/${corretto_archive}"
  $corretto_source_url    = "https://corretto.aws/downloads/latest/${corretto_archive}"
  $corretto_extract_dir   = "${java_root}/amazon-corretto-${java_version}-linux-x64"

  file { '/jcloudcodes':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  group { $agent_group:
    ensure => present,
  }

  user { $agent_user:
    ensure     => present,
    gid        => $agent_group,
    home       => $agent_home,
    managehome => true,
    shell      => '/bin/bash',
    require    => Group[$agent_group],
  }

  file { $java_root:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/jcloudcodes'],
  }

  file { $agent_root:
    ensure  => directory,
    owner   => $agent_user,
    group   => $agent_group,
    mode    => '0755',
    require => [
      File['/jcloudcodes'],
      User[$agent_user],
    ],
  }

  exec { 'download_jslave_corretto':
    command => "curl -L -o ${corretto_download} ${corretto_source_url}",
    creates => $corretto_download,
    require => File[$java_root],
  }

  exec { 'extract_jslave_corretto':
    command => "tar -xzf ${corretto_download} -C ${java_root}",
    unless  => "test -d ${corretto_extract_dir}",
    require => Exec['download_jslave_corretto'],
  }

  package { 'openssh-server':
    ensure => installed,
  }
}
