class tom_cat::install (
  Enum['prod', 'dev'] $environment,
  String              $tom_version,
  String              $java_version,
  String              $nexus_url,
  String              $base_dir,
  String              $tomcat_home,
  String              $install_dir,
  String              $java_root,
  String              $service_name,
  String              $tomcat_user,
  String              $tomcat_group,
  String              $windows_install_dir,
) {

  $tomcat_package = "apache-tomcat-${tom_version}"
  $tomcat_major_version = regsubst($tom_version, '^([0-9]+)\..*$', '\1')
  $tomcat_source_url    = "${nexus_url}/tomcat-${tomcat_major_version}/v${tom_version}/bin/${tomcat_package}.tar.gz"
  $corretto_major_version = regsubst($java_version, '^([0-9]+).*$', '\1')
  $corretto_archive       = "amazon-corretto-${corretto_major_version}-x64-linux-jdk.tar.gz"
  $corretto_download      = "/tmp/${corretto_archive}"
  $corretto_source_url    = "https://corretto.aws/downloads/latest/${corretto_archive}"
  $corretto_extract_dir   = "${java_root}/amazon-corretto-${java_version}-linux-x64"
  $tomcat_download        = "/tmp/${tomcat_package}.tar.gz"

  if $facts['kernel'] == 'Linux' {

    Exec {
      path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    }

    group { $tomcat_group:
      ensure => present,
    }

    user { $tomcat_user:
      ensure     => present,
      gid        => $tomcat_group,
      home       => $base_dir,
      managehome => false,
      shell      => '/sbin/nologin',
      require    => Group[$tomcat_group],
    }

    file { [$base_dir, $java_root, '/opt/backups']:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    file { $tomcat_home:
      ensure => directory,
      owner  => $tomcat_user,
      group  => $tomcat_group,
      mode   => '0755',
      require => [
        File[$base_dir],
        User[$tomcat_user],
      ],
    }

    file { $install_dir:
      ensure => directory,
      owner  => $tomcat_user,
      group  => $tomcat_group,
      mode   => '0755',
      require => File[$tomcat_home],
    }

    exec { 'download_corretto_linux':
      command => "curl -L -o ${corretto_download} ${corretto_source_url}",
      unless  => "test -d ${corretto_extract_dir}",
      require => File[$java_root],
    }

    exec { 'extract_corretto_linux':
      command => "tar -xzf ${corretto_download} -C ${java_root}",
      unless  => "test -d ${corretto_extract_dir}",
      require => Exec['download_corretto_linux'],
    }

    exec { 'cleanup_corretto_download_linux':
      command => "rm -f ${corretto_download}",
      onlyif  => "test -f ${corretto_download}",
      require => Exec['extract_corretto_linux'],
    }

    exec { 'download_tomcat_linux':
      command => "curl -L -o ${tomcat_download} ${tomcat_source_url}",
      unless  => "/bin/bash -c 'test -f ${tomcat_home}/.tomcat_version && grep -qx \"${tom_version}\" ${tomcat_home}/.tomcat_version'",
      require => File[$tomcat_home],
    }

    exec { 'cleanup_existing_tomcat_linux':
      command => "/bin/bash -c 'find ${tomcat_home} -mindepth 1 -maxdepth 1 -exec rm -rf {} +'",
      unless  => "/bin/bash -c 'test -f ${tomcat_home}/RELEASE-NOTES && grep -q \"Apache Tomcat Version ${tom_version}\" ${tomcat_home}/RELEASE-NOTES'",
      require => Exec['download_tomcat_linux'],
    }

    exec { 'extract_tomcat_linux':
      command => "/bin/bash -c 'tar -xzf ${tomcat_download} --strip-components=1 -C ${tomcat_home} && echo ${tom_version} > ${tomcat_home}/.tomcat_version'",
      unless  => "/bin/bash -c 'test -f ${tomcat_home}/.tomcat_version && grep -qx \"${tom_version}\" ${tomcat_home}/.tomcat_version'",
      require => Exec['cleanup_existing_tomcat_linux'],
    }

    exec { 'seed_tomcat_base_conf_linux':
      command => "/bin/bash -c 'mkdir -p ${install_dir}/conf && cp -a ${tomcat_home}/conf/. ${install_dir}/conf/'",
      unless  => "test -f ${install_dir}/conf/server.xml",
      require => [
        Exec['extract_tomcat_linux'],
        File[$install_dir],
      ],
    }

    exec { 'seed_tomcat_base_webapps_linux':
      command => "/bin/bash -c 'mkdir -p ${install_dir}/webapps && cp -a ${tomcat_home}/webapps/. ${install_dir}/webapps/'",
      unless  => "test -d ${install_dir}/webapps/manager",
      require => [
        Exec['extract_tomcat_linux'],
        File[$install_dir],
      ],
    }

    file { [
      "${install_dir}/logs",
      "${install_dir}/temp",
      "${install_dir}/work",
      "${install_dir}/webapps",
      "${install_dir}/bin",
    ]:
      ensure  => directory,
      recurse => false,
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0755',
      require => File[$install_dir],
    }

    file { [
      "${tomcat_home}/bin/catalina.sh",
      "${tomcat_home}/bin/startup.sh",
      "${tomcat_home}/bin/shutdown.sh",
    ]:
      ensure  => file,
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0755',
      require => Exec['extract_tomcat_linux'],
    }

    exec { 'set_tomcat_permissions':
      command => "chown -R ${tomcat_user}:${tomcat_group} ${tomcat_home} ${install_dir}",
      unless  => "/bin/bash -c 'test \"$(stat -c %U ${tomcat_home})\" = \"${tomcat_user}\" && test \"$(stat -c %G ${tomcat_home})\" = \"${tomcat_group}\" && test \"$(stat -c %U ${install_dir})\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir})\" = \"${tomcat_group}\"'",
      require => [
        Exec['extract_tomcat_linux'],
        Exec['seed_tomcat_base_conf_linux'],
        Exec['seed_tomcat_base_webapps_linux'],
      ],
    }

    exec { 'cleanup_tomcat_download_linux':
      command => "rm -f ${tomcat_download}",
      onlyif  => "test -f ${tomcat_download}",
      require => Exec['extract_tomcat_linux'],
    }

  } elsif $facts['kernel'] == 'windows' {

    package { "OpenJDK ${java_version}":
      ensure   => installed,
      provider => chocolatey,
    }

    file { 'C:/temp':
      ensure => directory,
    }

    file { 'C:/temp/install-tomcat.ps1':
      ensure => file,
      source => 'puppet:///modules/tom_cat/windows/tomcat.ps1',
      require => File['C:/temp'],
    }

    exec { 'install_tomcat_windows':
      command   => "powershell.exe -ExecutionPolicy Bypass -File C:/temp/install-tomcat.ps1 -TomcatVersion ${tom_version} -NexusUrl ${nexus_url} -InstallDir ${windows_install_dir} -ServiceName ${service_name}",
      provider  => powershell,
      unless    => "if (Test-Path '${windows_install_dir}') { exit 0 } else { exit 1 }",
      require   => File['C:/temp/install-tomcat.ps1'],
      logoutput => true,
    }

  } else {
    fail("Unsupported kernel: ${facts['kernel']}")
  }
}
