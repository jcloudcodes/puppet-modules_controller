class jslave::uninstall (
  String $agent_root,
  String $agent_home,
  String $java_root,
  String $authorization_root,
  String $agent_user,
  String $agent_group,
  String $nginx_server_name,
) {

  Exec {
    path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  file { $agent_root:
    ensure  => absent,
    recurse => true,
    force   => true,
  }

  file { $java_root:
    ensure  => absent,
    recurse => true,
    force   => true,
  }

  file { $agent_home:
    ensure => absent,
    recurse => true,
    force   => true,
  }

  file { $authorization_root:
    ensure  => absent,
    recurse => true,
    force   => true,
  }

  exec { 'stop_nginx_before_jslave_uninstall':
    command => '/bin/systemctl stop nginx',
    onlyif  => '/bin/systemctl list-unit-files nginx.service',
  }

  exec { 'disable_nginx_before_jslave_uninstall':
    command => '/bin/systemctl disable nginx',
    onlyif  => '/bin/systemctl list-unit-files nginx.service',
    require => Exec['stop_nginx_before_jslave_uninstall'],
  }

  file { '/etc/nginx/conf.d/jslave.conf':
    ensure  => absent,
    require => Exec['disable_nginx_before_jslave_uninstall'],
  }

  package { 'nginx':
    ensure  => absent,
    require => [
      Exec['disable_nginx_before_jslave_uninstall'],
      File['/etc/nginx/conf.d/jslave.conf'],
    ],
  }

  user { $agent_user:
    ensure => absent,
    require => File[$agent_home],
  }

  group { $agent_group:
    ensure => absent,
    require => User[$agent_user],
  }
}
