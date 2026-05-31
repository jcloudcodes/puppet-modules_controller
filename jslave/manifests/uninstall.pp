class jslave::uninstall (
  String $agent_root,
  String $agent_home,
  String $java_root,
  String $agent_user,
  String $agent_group,
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

  user { $agent_user:
    ensure => absent,
    require => File[$agent_home],
  }

  group { $agent_group:
    ensure => absent,
    require => User[$agent_user],
  }
}
