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
  String              $windows_tomcat_home,
  String              $windows_install_dir,
  String              $windows_java_root,
) {

  $tomcat_package = "apache-tomcat-${tom_version}"
  $tomcat_major_version = regsubst($tom_version, '^([0-9]+)\..*$', '\1')
  $tomcat_source_url    = "${nexus_url}/tomcat-${tomcat_major_version}/v${tom_version}/bin/${tomcat_package}.tar.gz"
  $tomcat_windows_package = "apache-tomcat-${tom_version}-windows-x64.zip"
  $tomcat_windows_url     = "${nexus_url}/tomcat-${tomcat_major_version}/v${tom_version}/bin/${tomcat_windows_package}"
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

    package { 'rsync':
      ensure => installed,
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
      require => [
        Package['rsync'],
        Exec['extract_tomcat_linux'],
      ],
    }

    exec { 'seed_default_webapps_linux':
      command => "/bin/bash -c 'mkdir -p ${install_dir}/webapps && if test -d ${tomcat_staging_dir}/webapps; then rsync -a ${tomcat_staging_dir}/webapps/ ${install_dir}/webapps/; else cp -a ${install_dir}/webapps.dist/. ${install_dir}/webapps/; fi'",
      onlyif  => "/bin/bash -c 'test -d ${tomcat_staging_dir}/webapps || test -d ${install_dir}/webapps.dist'",
      unless  => "test -d ${install_dir}/webapps/manager",
      require => [
        Package['rsync'],
        Exec['extract_tomcat_linux'],
      ],
    }

    exec { 'preserve_default_webapps_linux':
      command => "/bin/bash -c 'rm -rf ${install_dir}/webapps.dist && mkdir -p ${install_dir}/webapps.dist && cp -a ${install_dir}/webapps/. ${install_dir}/webapps.dist/'",
      unless  => "test -d ${install_dir}/webapps.dist/manager",
      require => Exec['sync_tomcat_runtime_linux'],
    }

    exec { 'cleanup_tomcat_download_linux':
      command => "/bin/bash -c 'rm -f ${tomcat_download} && rm -rf ${tomcat_staging_dir}'",
      onlyif  => "/bin/bash -c 'test -f ${tomcat_download} || test -d ${tomcat_staging_dir}'",
      require => [
        Exec['preserve_default_webapps_linux'],
        Exec['sync_tomcat_runtime_linux'],
        Exec['seed_default_webapps_linux'],
      ],
    }

  } elsif $facts['kernel'] == 'windows' {

    $windows_powershell   = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
    $windows_temp         = 'C:/temp'
    $windows_extract_root = 'C:/temp/corretto-extract'
    $windows_corretto_zip = "${windows_temp}/amazon-corretto-${corretto_major_version}-x64-windows-jdk.zip"
    $windows_corretto_dir = "${windows_java_root}/amazon-corretto-${java_version}-windows-x64"
    $windows_java_link    = "${windows_tomcat_home}/tomcat-java"
    $windows_corretto_url = "https://corretto.aws/downloads/latest/amazon-corretto-${corretto_major_version}-x64-windows-jdk.zip"

    file { $windows_temp:
      ensure => directory,
    }

    file { $windows_tomcat_home:
      ensure => directory,
    }

    file { $windows_install_dir:
      ensure  => directory,
      require => File[$windows_tomcat_home],
    }

    file { $windows_java_root:
      ensure  => directory,
      require => File[$windows_tomcat_home],
    }

    file { $windows_extract_root:
      ensure  => directory,
      require => File[$windows_temp],
    }

    file { 'C:/temp/install-java.ps1':
      ensure  => file,
      source  => 'puppet:///modules/tom_cat/windows/install-java.ps1',
      require => File[$windows_temp],
    }

    exec { 'install_java_windows':
      command     => "${windows_powershell} -NoProfile -ExecutionPolicy Bypass -File C:/temp/install-java.ps1 -JavaUrl ${windows_corretto_url} -ZipPath ${windows_corretto_zip} -ExtractRoot ${windows_extract_root} -JavaRoot ${windows_java_root} -JavaHome ${windows_corretto_dir} -JavaLink ${windows_java_link}",
      unless      => "${windows_powershell} -NoProfile -Command \"if (Test-Path '${windows_java_link}/bin/java.exe') { exit 0 } else { exit 1 }\"",
      cwd         => $windows_temp,
      environment => [
        "TEMP=${windows_temp}",
        "TMP=${windows_temp}",
      ],
      timeout     => 1800,
      require     => [
        File[$windows_temp],
        File[$windows_tomcat_home],
        File[$windows_install_dir],
        File[$windows_java_root],
        File[$windows_extract_root],
        File['C:/temp/install-java.ps1'],
      ],
      logoutput   => true,
    }

    file { 'C:/temp/install-tomcat.ps1':
      ensure  => file,
      source  => 'puppet:///modules/tom_cat/windows/tomcat.ps1',
      require => File[$windows_temp],
    }

    exec { 'install_tomcat_windows':
      command     => "${windows_powershell} -NoProfile -ExecutionPolicy Bypass -File C:/temp/install-tomcat.ps1 -TomcatVersion ${tom_version} -TomcatUrl ${tomcat_windows_url} -InstallDir ${windows_install_dir} -ServiceName ${service_name} -JavaHome ${windows_java_link}",
      unless      => "${windows_powershell} -NoProfile -Command \"if (Get-Service -Name '${service_name}' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }\"",
      cwd         => $windows_temp,
      environment => [
        "TEMP=${windows_temp}",
        "TMP=${windows_temp}",
      ],
      timeout     => 1800,
      require     => [
        Exec['install_java_windows'],
        File['C:/temp/install-tomcat.ps1'],
      ],
      logoutput   => true,
    }

  } else {
    fail("Unsupported kernel: ${facts['kernel']}")
  }
}
