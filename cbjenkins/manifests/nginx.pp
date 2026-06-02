# Manages NGINX reverse proxy for Jenkins.
#
# Exposes Jenkins through:
#   http://jenkins.jcloudcodes.com
#
# Flow:
# Jenkins listens locally on 8080.
# NGINX listens on 80 and proxies traffic to Jenkins.

class cb_jenkins::nginx (
  String $server_name  = 'jenkins.jcloudcodes.com',
  String $jenkins_port = '8080',
) {

  package { 'nginx':
    ensure => installed,
  }

  file { '/etc/nginx/conf.d/jenkins.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('cb_jenkins/jenkins-nginx.conf.epp', {
      'server_name'  => $server_name,
      'jenkins_port' => $jenkins_port,
    }),
    require => Package['nginx'],
    notify  => Exec['validate_jenkins_nginx_config'],
  }

  exec { 'allow_nginx_jenkins_selinux_connect':
    command => 'setsebool -P httpd_can_network_connect 1',
    path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
    unless  => "/bin/bash -c 'command -v getenforce >/dev/null 2>&1 && test \"$(getenforce)\" = \"Enforcing\" && getsebool httpd_can_network_connect | grep -q -- \"--> on\"'",
    before  => Service['nginx'],
  }

  exec { 'validate_jenkins_nginx_config':
    command     => 'nginx -t',
    path        => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
    refreshonly => true,
    subscribe   => File['/etc/nginx/conf.d/jenkins.conf'],
    notify      => Service['nginx'],
  }

  service { 'nginx':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => [
      Package['nginx'],
      Exec['allow_nginx_jenkins_selinux_connect'],
    ],
  }
}
