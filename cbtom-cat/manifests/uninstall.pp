class tom_cat::uninstall (
  Enum['prod', 'dev'] $environment,
  String              $tom_version,
  String              $java_version,
  String              $base_dir,
  String              $tomcat_home,
  String              $install_dir,
  String              $java_root,
  String              $service_name,
  String              $windows_install_dir,
) {

  $tomcat_package         = "apache-tomcat-${tom_version}"
  $corretto_major_version = regsubst($java_version, '^([0-9]+).*$', '\1')
  $corretto_archive       = "amazon-corretto-${corretto_major_version}-x64-linux-jdk.tar.gz"
  $corretto_extract_dir   = "${java_root}/amazon-corretto-${java_version}-linux-x64"

  if $facts['kernel'] == 'Linux' {

    service { $service_name:
      ensure => stopped,
      enable => false,
    }

    file { "${install_dir}/temp/tomcat.pid":
      ensure  => absent,
      force   => true,
      require => Service[$service_name],
    }

    exec { 'stop_nginx_before_tomcat_uninstall':
      command => '/bin/systemctl stop nginx',
      onlyif  => '/bin/systemctl list-unit-files nginx.service',
      path    => ['/usr/bin', '/bin'],
      require => Service[$service_name],
    }

    exec { 'disable_nginx_before_tomcat_uninstall':
      command => '/bin/systemctl disable nginx',
      onlyif  => '/bin/systemctl list-unit-files nginx.service',
      path    => ['/usr/bin', '/bin'],
      require => Exec['stop_nginx_before_tomcat_uninstall'],
    }

    file { "/etc/systemd/system/${service_name}.service":
      ensure => absent,
      notify => Exec['systemd_daemon_reload_uninstall'],
    }

    file { '/etc/nginx/conf.d/tomcat.conf':
      ensure  => absent,
      require => Exec['disable_nginx_before_tomcat_uninstall'],
    }

    package { 'nginx':
      ensure  => absent,
      require => [
        Exec['disable_nginx_before_tomcat_uninstall'],
        File['/etc/nginx/conf.d/tomcat.conf'],
      ],
    }

    exec { 'systemd_daemon_reload_uninstall':
      command     => '/bin/systemctl daemon-reload',
      path        => ['/usr/bin', '/bin'],
      refreshonly => true,
      notify      => Exec['systemd_reset_failed_uninstall'],
    }

    exec { 'systemd_reset_failed_uninstall':
      command     => "/bin/bash -c '/bin/systemctl reset-failed ${service_name} || true'",
      path        => ['/usr/bin', '/bin'],
      refreshonly => true,
      notify      => Exec['systemd_daemon_reexec_uninstall'],
    }

    exec { 'systemd_daemon_reexec_uninstall':
      command     => '/bin/systemctl daemon-reexec',
      path        => ['/usr/bin', '/bin'],
      refreshonly => true,
    }

    file { $tomcat_home:
      ensure => absent,
      force  => true,
      require => [
        File["${install_dir}/temp/tomcat.pid"],
        Exec['systemd_daemon_reload_uninstall'],
      ],
    }

    file { $java_root:
      ensure  => absent,
      recurse => true,
      force   => true,
    }

    file { "/tmp/${tomcat_package}.tar.gz":
      ensure => absent,
    }

    file { "/tmp/${corretto_archive}":
      ensure => absent,
    }

    exec { 'remove_tomcat_backup_archives_linux':
      command => "/bin/bash -c 'rm -f /opt/backups/${service_name}-*.tar.gz'",
      onlyif  => "/bin/bash -c 'compgen -G \"/opt/backups/${service_name}-*.tar.gz\" > /dev/null'",
      path    => ['/usr/bin', '/bin'],
    }

  } elsif $facts['kernel'] == 'windows' {

    $windows_powershell = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'

    exec { 'remove_windows_service':
      command   => "${windows_powershell} -Command \"if (Get-Service -Name '${service_name}' -ErrorAction SilentlyContinue) { Stop-Service -Name '${service_name}' -Force; sc.exe delete ${service_name} }\"",
      logoutput => true,
    }

    file { $windows_install_dir:
      ensure  => absent,
      recurse => true,
      force   => true,
      require => Exec['remove_windows_service'],
    }

  } else {
    fail("Unsupported kernel: ${facts['kernel']}")
  }
}
