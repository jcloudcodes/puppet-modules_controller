class tom_cat::upgrade (
  Enum['prod', 'dev'] $environment,
  String              $tom_version,
  String              $java_version,
  String              $base_dir,
  String              $tomcat_home,
  String              $install_dir,
  String              $service_name,
  String              $tomcat_user,
  String              $tomcat_group,
  String              $windows_install_dir,
) {

  $timestamp = strftime('%Y%m%d%H%M%S')

  if $facts['kernel'] == 'Linux' {

    exec { 'stop_tomcat_before_upgrade_linux':
      command => "/bin/systemctl stop ${service_name}",
      path    => ['/usr/bin', '/bin'],
      onlyif  => [
        "/bin/systemctl is-active --quiet ${service_name}",
        "/usr/bin/test -d ${install_dir}",
      ],
      unless  => "/bin/bash -c 'test -f ${install_dir}/.tomcat_version && grep -qx \"${tom_version}\" ${install_dir}/.tomcat_version'",
    }

    exec { 'backup_existing_tomcat_linux':
      command => "/bin/tar -czf /opt/backups/${service_name}-${timestamp}.tar.gz ${install_dir}",
      path    => ['/usr/bin', '/bin'],
      onlyif  => "/usr/bin/test -d ${install_dir}",
      unless  => "/bin/bash -c 'test -f ${install_dir}/.tomcat_version && grep -qx \"${tom_version}\" ${install_dir}/.tomcat_version'",
      require => Exec['stop_tomcat_before_upgrade_linux'],
    }

  } elsif $facts['kernel'] == 'windows' {

    $windows_powershell = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'

    exec { 'stop_tomcat_before_upgrade_windows':
      command   => "${windows_powershell} -Command \"if (Get-Service -Name '${service_name}' -ErrorAction SilentlyContinue) { Stop-Service -Name '${service_name}' -Force }\"",
      logoutput => true,
    }

    exec { 'backup_existing_tomcat_windows':
      command   => "${windows_powershell} -Command \"if (Test-Path '${windows_install_dir}') { Compress-Archive -Path '${windows_install_dir}\\*' -DestinationPath 'C:\\temp\\${service_name}-${timestamp}.zip' -Force }\"",
      logoutput => true,
      require   => Exec['stop_tomcat_before_upgrade_windows'],
    }

    notify { "Tomcat ${tom_version} backup completed on Windows":
    }

  } else {
    fail("Unsupported kernel: ${facts['kernel']}")
  }
}
