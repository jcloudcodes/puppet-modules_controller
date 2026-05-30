class tom_cat (
  Enum['prod', 'dev']          $environment  = 'prod',
  Enum['install', 'uninstall'] $action       = 'install',
  Optional[String]             $tom_version  = '10.1.24',
  Optional[String]             $java_version = '21.0.11.10.1',
) {

  # Values from Hiera/common.yaml
  $base_dir            = lookup('tom_cat::base_dir')
  $install_dir         = lookup('tom_cat::install_dir')
  $java_root           = lookup('tom_cat::java_root')
  $service_name        = lookup('tom_cat::service_name')
  $nexus_url           = lookup('tom_cat::nexus_url')
  $tomcat_user         = lookup('tom_cat::tomcat_user')
  $tomcat_group        = lookup('tom_cat::tomcat_group')
  $shutdown_port       = lookup('tom_cat::shutdown_port')
  $connector_port      = lookup('tom_cat::connector_port')
  $redirect_port       = lookup('tom_cat::redirect_port')
  $windows_install_dir = lookup('tom_cat::windows_install_dir')

  if $action == 'uninstall' {

    class { 'tom_cat::uninstall':
      environment         => $environment,
      tom_version         => $tom_version,
      java_version        => $java_version,
      base_dir            => $base_dir,
      install_dir         => $install_dir,
      service_name        => $service_name,
      windows_install_dir => $windows_install_dir,
    }

    contain tom_cat::uninstall

  } elsif $action == 'install' {

    if $tom_version == undef or $tom_version == '' {
      fail('Tomcat version is not set on console parameter')
    }

    if $java_version == undef or $java_version == '' {
      fail('Java version is not set on console parameter')
    }

    class { 'tom_cat::install':
      environment         => $environment,
      tom_version         => $tom_version,
      java_version        => $java_version,
      nexus_url           => $nexus_url,
      base_dir            => $base_dir,
      install_dir         => $install_dir,
      java_root           => $java_root,
      service_name        => $service_name,
      tomcat_user         => $tomcat_user,
      tomcat_group        => $tomcat_group,
      windows_install_dir => $windows_install_dir,
    }

    -> class { 'tom_cat::upgrade':
      environment         => $environment,
      tom_version         => $tom_version,
      java_version        => $java_version,
      base_dir            => $base_dir,
      install_dir         => $install_dir,
      service_name        => $service_name,
      tomcat_user         => $tomcat_user,
      tomcat_group        => $tomcat_group,
      windows_install_dir => $windows_install_dir,
    }

    -> class { 'tom_cat::config':
      environment         => $environment,
      tom_version         => $tom_version,
      java_version        => $java_version,
      install_dir         => $install_dir,
      java_root           => $java_root,
      service_name        => $service_name,
      tomcat_user         => $tomcat_user,
      tomcat_group        => $tomcat_group,
      shutdown_port       => $shutdown_port,
      connector_port      => $connector_port,
      redirect_port       => $redirect_port,
      windows_install_dir => $windows_install_dir,
    }

    -> class { 'tom_cat::service':
      service_name        => $service_name,
      install_dir         => $install_dir,
      windows_install_dir => $windows_install_dir,
    }

    contain tom_cat::install
    contain tom_cat::upgrade
    contain tom_cat::config
    contain tom_cat::service

  } else {
    fail("Unsupported action: ${action}")
  }
}
