# Exposes the Jenkins SSH agent host through a simple NGINX status page.
class jslave::nginx (
  String $server_name = 'jslave.jcloudcodes.com',
  String $agent_name  = 'jenkins-agent-01',
) {

  package { 'nginx':
    ensure => installed,
  }

  file { '/etc/nginx/conf.d/jslave.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('jslave/jslave-nginx.conf.epp', {
      'server_name' => $server_name,
      'agent_name'  => $agent_name,
    }),
    require => Package['nginx'],
    notify  => Exec['validate_jslave_nginx_config'],
  }

  exec { 'allow_nginx_jslave_selinux_connect':
    command => 'setsebool -P httpd_can_network_connect 1',
    path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
    unless  => "/bin/bash -c 'command -v getenforce >/dev/null 2>&1 && test \"$(getenforce)\" = \"Enforcing\" && getsebool httpd_can_network_connect | grep -q -- \"--> on\"'",
    before  => Service['nginx'],
  }

  exec { 'validate_jslave_nginx_config':
    command     => 'nginx -t',
    path        => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
    refreshonly => true,
    subscribe   => File['/etc/nginx/conf.d/jslave.conf'],
    notify      => Service['nginx'],
  }

  service { 'nginx':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => [
      Package['nginx'],
      Exec['allow_nginx_jslave_selinux_connect'],
    ],
  }
}
