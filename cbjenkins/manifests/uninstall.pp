class cb_jenkins::uninstall (
  String          $service_name,
  String          $jenkins_package,
  String          $config_file,
  Enum['', 'yes'] $remove_cb_je = '',
) {

  Exec {
    path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  $jenkins_root      = '/jcloudcodes/cbjenkins'
  $jenkins_java_root = '/jcloudcodes/cbjenkins-java'
  $jenkins_ssh_root  = '/jcloudcodes/customer-ssh-keys'

  #notify { 'cb_jenkins::uninstall loaded': }

  # Stop Jenkins only if the service exists.
  exec { 'stop_jenkins_before_uninstall':
    command => "systemctl stop ${service_name}",
    onlyif  => "systemctl list-unit-files ${service_name}.service",
  }

  # Disable Jenkins only if the service exists.
  exec { 'disable_jenkins_before_uninstall':
    command => "systemctl disable ${service_name}",
    onlyif  => "systemctl list-unit-files ${service_name}.service",
    require => Exec['stop_jenkins_before_uninstall'],
  }

  # Remove Jenkins RPM package.
  package { $jenkins_package:
    ensure  => absent,
    require => Exec['disable_jenkins_before_uninstall'],
  }

  # Remove Jenkins main config file.
  file { $config_file:
    ensure  => absent,
    require => Package[$jenkins_package],
  }

  # Stop NGINX only if the service exists.
  exec { 'stop_nginx_before_uninstall':
    command => 'systemctl stop nginx',
    onlyif  => 'systemctl list-unit-files nginx.service',
    require => Package[$jenkins_package],
  }

  # Disable NGINX only if the service exists.
  exec { 'disable_nginx_before_uninstall':
    command => 'systemctl disable nginx',
    onlyif  => 'systemctl list-unit-files nginx.service',
    require => Exec['stop_nginx_before_uninstall'],
  }

  # Remove Jenkins systemd override directory.
  file { '/etc/systemd/system/jenkins.service.d':
    ensure  => absent,
    force   => true,
    recurse => true,
    require => Package[$jenkins_package],
    notify  => Exec['systemd-daemon-reload-after-uninstall'],
  }

  # Remove Jenkins repository file.
  file { '/etc/yum.repos.d/jenkins.repo':
    ensure  => absent,
    require => Package[$jenkins_package],
  }

  # Remove Jenkins NGINX reverse proxy configuration.
  file { '/etc/nginx/conf.d/jenkins.conf':
    ensure  => absent,
    require => Exec['disable_nginx_before_uninstall'],
  }

  # Remove Jenkins logrotate configuration.
  file { '/etc/logrotate.d/jenkins':
    ensure  => absent,
    require => Package[$jenkins_package],
  }

  # Remove Jenkins limits configuration.
  file { '/etc/security/limits.d/jenkins.conf':
    ensure  => absent,
    require => Package[$jenkins_package],
  }

  # Remove Jenkins runtime/cache/log/lib directories.
  file { [
    '/var/cache/jenkins',
    '/var/log/jenkins',
    '/var/lib/jenkins',
  ]:
    ensure  => absent,
    force   => true,
    recurse => true,
    require => Package[$jenkins_package],
  }

  # Remove Jenkins WAR if left behind.
  file { '/usr/share/java/jenkins.war':
    ensure  => absent,
    require => Package[$jenkins_package],
  }

  # Remove NGINX package.
  package { 'nginx':
    ensure  => absent,
    require => [
      Exec['disable_nginx_before_uninstall'],
      File['/etc/nginx/conf.d/jenkins.conf'],
    ],
  }

  # Remove Jenkins generated systemd unit symlink if left behind.
  file { "/etc/systemd/system/multi-user.target.wants/${service_name}.service":
    ensure  => absent,
    require => Package[$jenkins_package],
    notify  => Exec['systemd-daemon-reload-after-uninstall'],
  }

  # Reload systemd after removing systemd files.
  exec { 'systemd-daemon-reload-after-uninstall':
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }

  # Reset failed Jenkins service state only if needed.
  exec { 'systemd-reset-failed-jenkins-after-uninstall':
    command => "systemctl reset-failed ${service_name}",
    onlyif  => "systemctl is-failed ${service_name}",
    require => Package[$jenkins_package],
  }

  # Optional full cleanup of custom Jenkins and custom Corretto directories.
  if $remove_cb_je == 'yes' {

    file { $jenkins_root:
      ensure  => absent,
      force   => true,
      recurse => true,
      require => Package[$jenkins_package],
    }

    file { $jenkins_java_root:
      ensure  => absent,
      force   => true,
      recurse => true,
      require => Package[$jenkins_package],
    }

    file { $jenkins_ssh_root:
      ensure  => absent,
      force   => true,
      recurse => true,
      require => Package[$jenkins_package],
    }

    file { '/jcloudcodes':
      ensure  => absent,
      force   => true,
      recurse => true,
      require => [
        File[$jenkins_java_root],
        File[$jenkins_ssh_root],
      ],
    }
  }
  # Remove Git and perl-Git together in one transaction to avoid the
  # RPM dependency loop between the two packages.
  exec { 'remove_git_and_perl_git_after_jenkins_uninstall':
    command => '/usr/bin/dnf remove -y git perl-Git',
    onlyif  => "/bin/bash -c 'rpm -q git >/dev/null 2>&1 || rpm -q perl-Git >/dev/null 2>&1'",
    require => Package[$jenkins_package],
  }
}
