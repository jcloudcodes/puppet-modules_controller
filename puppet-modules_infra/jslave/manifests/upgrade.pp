class jslave::upgrade (
  String $agent_user,
  String $agent_home,
  String $controller_host,
) {

  Exec {
    path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  exec { 'refresh_jslave_known_host_fingerprint':
    command => "/bin/bash -c 'mkdir -p ${agent_home}/.ssh && ssh-keyscan -H ${controller_host} >> ${agent_home}/.ssh/known_hosts && chown ${agent_user}:${agent_user} ${agent_home}/.ssh/known_hosts'",
    unless  => "/bin/bash -c 'test -f ${agent_home}/.ssh/known_hosts && grep -q \"${controller_host}\" ${agent_home}/.ssh/known_hosts'",
  }
}
