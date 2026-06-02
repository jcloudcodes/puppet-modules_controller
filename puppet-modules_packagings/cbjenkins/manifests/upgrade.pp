# Handles Jenkins post-install/post-upgrade validation.
#
# IMPORTANT:
# Jenkins package is managed only in install.pp.
# Do not declare Package[$jenkins_package] here.

class cb_jenkins::upgrade (
  String $jenkins_version,
  String $jenkins_package,
  String $service_name,
) {

  Exec {
    path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  # Show installed Jenkins version only when debug is needed.
  # Disabled by default to avoid running every Puppet run.
  # notify { "target_jenkins_version: ${jenkins_version}": }

  # Reload systemd only when Jenkins package changes.
  exec { 'daemon_reload_after_jenkins_install_or_upgrade':
    command     => 'systemctl daemon-reload',
    refreshonly => true,
    subscribe   => Package[$jenkins_package],
  }

  # Reset Jenkins failed state only if Jenkins is failed.
  exec { 'reset_failed_jenkins_after_upgrade':
    command => "systemctl reset-failed ${service_name}",
    onlyif  => "systemctl is-failed ${service_name}",
    require => Exec['daemon_reload_after_jenkins_install_or_upgrade'],
  }
}
