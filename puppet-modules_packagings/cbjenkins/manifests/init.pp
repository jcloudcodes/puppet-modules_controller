# -------
# This module was created by Pipeline
#

class cb_jenkins (
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
  $http_port            = lookup('cb_jenkins::http_port')
  $ajp_port             = lookup('cb_jenkins::ajp_port')
  $service_name         = lookup('cb_jenkins::service_name')
  $jenkins_user         = lookup('cb_jenkins::jenkins_user')
  $listen_address       = lookup('cb_jenkins::listen_address')
  $jenkins_package      = lookup('cb_jenkins::jenkins_package')
  $jenkins_repo_key_id  = lookup('cb_jenkins::jenkins_repo_key_id')
  $config_file          = lookup('cb_jenkins::config_file')
  $jenkins_repo_baseurl = lookup('cb_jenkins::jenkins_repo_baseurl')
  $jenkins_repo_gpg     = lookup('cb_jenkins::jenkins_repo_gpg')
  $nginx_server_name    = lookup('cb_jenkins::nginx_server_name', { 'default_value' => 'jenkins.jcloudcodes.com' })

  if $action == 'uninstall' {

  class { 'cb_jenkins::uninstall':
    service_name    => $service_name,
    jenkins_package => $jenkins_package,
    config_file     => $config_file,
    remove_cb_je    => $remove_cb_je,
  }
  contain cb_jenkins::uninstall
  } elsif $action == 'install' {

    class { 'cb_jenkins::install':
      jenkins_version      => $jenkins_version,
      corretto_jdk_version => $corretto_jdk_version,
      jenkins_package      => $jenkins_package,
      jenkins_repo_baseurl => $jenkins_repo_baseurl,
      jenkins_repo_gpg     => $jenkins_repo_gpg,
      jenkins_repo_key_id  => $jenkins_repo_key_id,
    }

    -> class { 'cb_jenkins::upgrade':
      jenkins_version => $jenkins_version,
      jenkins_package => $jenkins_package,
      service_name    => $service_name,
    }

    -> class { 'cb_jenkins::config':
      http_port            => $http_port,
      ajp_port             => $ajp_port,
      service_name         => $service_name,
      jenkins_user         => $jenkins_user,
      listen_address       => $listen_address,
      config_file          => $config_file,
      corretto_jdk_version => $corretto_jdk_version,
    }

    -> class { 'cb_jenkins::service':
      service_name => $service_name,
    }

    -> class { 'cb_jenkins::nginx':
      server_name  => $nginx_server_name,
      jenkins_port => $http_port,
    }

    contain cb_jenkins::install
    contain cb_jenkins::upgrade
    contain cb_jenkins::config
    contain cb_jenkins::service
    contain cb_jenkins::nginx

  } else {
    fail("Unsupported action: ${action}")
  }
}
