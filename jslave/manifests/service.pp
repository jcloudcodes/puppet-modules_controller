class jslave::service (
  String $agent_home,
  String $authorization_root,
) {

  service { 'sshd':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => Package['openssh-server'],
    subscribe  => File["${authorization_root}/.ssh/authorized_keys"],
  }
}
