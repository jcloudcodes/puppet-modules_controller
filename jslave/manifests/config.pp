class jslave::config (
  String $java_version,
  String $controller_host,
  String $agent_name,
  String $agent_labels,
  String $ssh_public_key,
  String $agent_root,
  String $agent_workdir,
  String $agent_home,
  String $java_root,
  String $agent_user,
  String $agent_group,
) {

  Exec {
    path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  $corretto_home    = "${java_root}/amazon-corretto-${java_version}-linux-x64"
  $java_link        = "${agent_root}/jenkins-java"
  $ssh_dir          = "${agent_home}/.ssh"
  $profile_script   = '/etc/profile.d/jenkins-agent.sh'

  file { $agent_workdir:
    ensure  => directory,
    owner   => $agent_user,
    group   => $agent_group,
    mode    => '0755',
    require => Class['jslave::install'],
  }

  file { $java_link:
    ensure  => link,
    target  => $corretto_home,
    require => Class['jslave::install'],
  }

  file { $ssh_dir:
    ensure  => directory,
    owner   => $agent_user,
    group   => $agent_group,
    mode    => '0700',
    require => Class['jslave::install'],
  }

  file { "${ssh_dir}/authorized_keys":
    ensure  => file,
    owner   => $agent_user,
    group   => $agent_group,
    mode    => '0600',
    content => "${ssh_public_key}\n",
    require => [
      File[$ssh_dir],
      User[$agent_user],
    ],
  }

  file { $profile_script:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('jslave/jenkins-agent.sh.epp', {
      'controller_host' => $controller_host,
      'agent_name'      => $agent_name,
      'agent_labels'    => $agent_labels,
      'agent_workdir'   => $agent_workdir,
      'java_link'       => $java_link,
    }),
  }

  exec { 'fix_jslave_permissions':
    command => "chown -R ${agent_user}:${agent_group} ${agent_root}",
    unless  => "/bin/bash -c 'test \"$(stat -c %U ${agent_root})\" = \"${agent_user}\" && test \"$(stat -c %G ${agent_root})\" = \"${agent_group}\"'",
    require => [
      File[$agent_root],
      File[$agent_workdir],
      File[$java_link],
    ],
  }
}
