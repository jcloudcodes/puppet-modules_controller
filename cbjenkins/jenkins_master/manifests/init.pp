# -------
# This module was created by Pipeline
#

class jenkins_master (
  Enum['', 'yes']              $remove_cb_je         = '',
  Enum['yes', 'no']            $manage_tools         = 'no',
  Enum['install', 'uninstall'] $action               = 'install',
  Optional[String]             $jenkins_version      = undef,
  Optional[String]             $corretto_jdk_version = undef,
  Optional[String]             $git_version          = undef,
) {

  if $jenkins_version == undef or $jenkins_version == '' {
    fail('Jenkins version is not set on console parameter')
  }

  if $corretto_jdk_version == undef or $corretto_jdk_version == '' {
    fail('Java version is not set on console parameter')
  }

  # Values from common.yaml
  $http_port            = lookup('jenkins_master::http_port')
  $ajp_port             = lookup('jenkins_master::ajp_port')
  $service_name         = lookup('jenkins_master::service_name')
  $jenkins_user         = lookup('jenkins_master::jenkins_user')
  $listen_address       = lookup('jenkins_master::listen_address')
  $jenkins_package      = lookup('jenkins_master::jenkins_package')
  $jenkins_repo_key_id  = lookup('jenkins_master::jenkins_repo_key_id')
  $config_file          = lookup('jenkins_master::config_file')
  $jenkins_repo_baseurl = lookup('jenkins_master::jenkins_repo_baseurl')
  $jenkins_repo_gpg     = lookup('jenkins_master::jenkins_repo_gpg')
  $nginx_server_name    = lookup('jenkins_master::nginx_server_name', { 'default_value' => 'jenkins.jcloudcodes.com' })

  if $action == 'uninstall' {

  class { 'jenkins_master::uninstall':
    service_name    => $service_name,
    jenkins_package => $jenkins_package,
    config_file     => $config_file,
    remove_cb_je    => $remove_cb_je,
  }
  contain jenkins_master::uninstall
  } elsif $action == 'install' {

    class { 'jenkins_master::install':
      jenkins_version      => $jenkins_version,
      corretto_jdk_version => $corretto_jdk_version,
      jenkins_package      => $jenkins_package,
      jenkins_repo_baseurl => $jenkins_repo_baseurl,
      jenkins_repo_gpg     => $jenkins_repo_gpg,
      jenkins_repo_key_id  => $jenkins_repo_key_id,
    }

    -> class { 'jenkins_master::upgrade':
      jenkins_version => $jenkins_version,
      jenkins_package => $jenkins_package,
      service_name    => $service_name,
    }

    -> class { 'jenkins_master::config':
      http_port            => $http_port,
      ajp_port             => $ajp_port,
      service_name         => $service_name,
      jenkins_user         => $jenkins_user,
      listen_address       => $listen_address,
      config_file          => $config_file,
      corretto_jdk_version => $corretto_jdk_version,
    }

    -> class { 'jenkins_master::nginx':
      server_name  => $nginx_server_name,
      jenkins_port => $http_port,
    }

    -> class { 'jenkins_master::service':
      service_name => $service_name,
    }

    contain jenkins_master::install
    contain jenkins_master::upgrade
    contain jenkins_master::config
    contain jenkins_master::nginx
    contain jenkins_master::service

  } else {
    fail("Unsupported action: ${action}")
  }
}
