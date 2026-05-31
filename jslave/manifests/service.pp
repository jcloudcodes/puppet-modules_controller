class jslave::service (
  String $agent_home,
) {

  service { 'sshd':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => Package['openssh-server'],
    subscribe  => File["${agent_home}/.ssh/authorized_keys"],
  }
}
