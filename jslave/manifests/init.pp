class jslave (
  Enum['install', 'uninstall'] $action         = 'install',
  Optional[String]             $java_version   = undef,
) {

  $agent_user       = lookup('jslave::agent_user')
  $agent_group      = lookup('jslave::agent_group')
  $agent_root       = lookup('jslave::agent_root')
  $agent_workdir    = lookup('jslave::agent_workdir')
  $agent_home       = lookup('jslave::agent_home')
  $java_root        = lookup('jslave::java_root')
  $authorization_root = lookup('jslave::authorization_root')
  $controller_host  = lookup('jslave::controller_host')
  $nginx_server_name = lookup('jslave::nginx_server_name', { 'default_value' => 'jslave.jcloudcodes.com' })
  $resolved_name    = lookup('jslave::agent_name')
  $resolved_labels  = lookup('jslave::agent_labels')
  $ssh_public_key   = lookup('jslave::ssh_public_key')

  if $action == 'uninstall' {
    class { 'jslave::uninstall':
      agent_root    => $agent_root,
      agent_home    => $agent_home,
      java_root     => $java_root,
      authorization_root => $authorization_root,
      agent_user    => $agent_user,
      agent_group   => $agent_group,
      nginx_server_name => $nginx_server_name,
    }
    contain jslave::uninstall
  } elsif $action == 'install' {
    if $java_version == undef or $java_version == '' {
      fail('Java version is not set on console parameter')
    }

    if $ssh_public_key == 'REPLACE_WITH_JENKINS_CONTROLLER_PUBLIC_KEY' or $ssh_public_key == '' {
      fail('SSH public key is not set in Hiera')
    }

    class { 'jslave::install':
      java_version => $java_version,
      agent_root   => $agent_root,
      agent_home   => $agent_home,
      java_root    => $java_root,
      agent_user   => $agent_user,
      agent_group  => $agent_group,
    }

    -> class { 'jslave::config':
      java_version      => $java_version,
      controller_host   => $controller_host,
      agent_name        => $resolved_name,
      agent_labels      => $resolved_labels,
      ssh_public_key    => $ssh_public_key,
      agent_root        => $agent_root,
      agent_workdir     => $agent_workdir,
      agent_home        => $agent_home,
      java_root         => $java_root,
      authorization_root => $authorization_root,
      agent_user        => $agent_user,
      agent_group       => $agent_group,
    }

    -> class { 'jslave::upgrade':
      agent_user      => $agent_user,
      agent_home      => $agent_home,
      controller_host => $controller_host,
    }

    -> class { 'jslave::service':
      agent_home          => $agent_home,
      authorization_root  => $authorization_root,
    }

    -> class { 'jslave::nginx':
      server_name => $nginx_server_name,
      agent_name  => $resolved_name,
    }

    contain jslave::install
    contain jslave::config
    contain jslave::upgrade
    contain jslave::service
    contain jslave::nginx
  } else {
    fail("Unsupported action: ${action}")
  }
}
