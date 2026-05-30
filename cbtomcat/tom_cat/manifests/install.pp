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
  $tomcat_staging_dir     = "/tmp/${tomcat_package}"

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
      owner  => 'root',
      group  => 'root',
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
      unless  => "/bin/bash -c 'test -f ${install_dir}/.tomcat_version && grep -qx \"${tom_version}\" ${install_dir}/.tomcat_version && test -f ${install_dir}/bin/setclasspath.sh && test -f ${install_dir}/bin/bootstrap.jar'",
      require => File[$install_dir],
    }

    exec { 'prepare_tomcat_staging_linux':
      command => "/bin/bash -c 'rm -rf ${tomcat_staging_dir} && mkdir -p ${tomcat_staging_dir}'",
      unless  => "/bin/bash -c 'test -f ${install_dir}/.tomcat_version && grep -qx \"${tom_version}\" ${install_dir}/.tomcat_version && test -f ${install_dir}/bin/setclasspath.sh && test -f ${install_dir}/bin/bootstrap.jar'",
      require => Exec['download_tomcat_linux'],
    }

    exec { 'extract_tomcat_linux':
      command => "/bin/bash -c 'tar -xzf ${tomcat_download} --strip-components=1 -C ${tomcat_staging_dir}'",
      unless  => "/bin/bash -c 'test -f ${install_dir}/.tomcat_version && grep -qx \"${tom_version}\" ${install_dir}/.tomcat_version && test -f ${install_dir}/bin/setclasspath.sh && test -f ${install_dir}/bin/bootstrap.jar && test -f ${install_dir}/bin/catalina.sh && test -f ${install_dir}/bin/startup.sh && test -f ${install_dir}/bin/shutdown.sh'",
      require => Exec['prepare_tomcat_staging_linux'],
    }

    exec { 'sync_tomcat_runtime_linux':
      command => "/bin/bash -c 'rsync -a --delete --exclude webapps/ ${tomcat_staging_dir}/ ${install_dir}/ && echo ${tom_version} > ${install_dir}/.tomcat_version'",
      unless  => "/bin/bash -c 'test -f ${install_dir}/.tomcat_version && grep -qx \"${tom_version}\" ${install_dir}/.tomcat_version && test -f ${install_dir}/bin/setclasspath.sh && test -f ${install_dir}/bin/bootstrap.jar && test -f ${install_dir}/bin/catalina.sh && test -f ${install_dir}/bin/startup.sh && test -f ${install_dir}/bin/shutdown.sh'",
      require => Exec['extract_tomcat_linux'],
    }

    exec { 'cleanup_tomcat_download_linux':
      command => "/bin/bash -c 'rm -f ${tomcat_download} && rm -rf ${tomcat_staging_dir}'",
      onlyif  => "/bin/bash -c 'test -f ${tomcat_download} || test -d ${tomcat_staging_dir}'",
      require => Exec['sync_tomcat_runtime_linux'],
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
