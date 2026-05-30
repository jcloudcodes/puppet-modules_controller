class tom_cat::config (
  Enum['prod', 'dev'] $environment,
  String              $tom_version,
  String              $java_version,
  String              $tomcat_home,
  String              $install_dir,
  String              $java_root,
  String              $service_name,
  String              $tomcat_user,
  String              $tomcat_group,
  Integer             $shutdown_port,
  Integer             $connector_port,
  Integer             $redirect_port,
  String              $admin_user,
  Sensitive[String]   $admin_password,
  String              $windows_install_dir,
) {

  if $facts['kernel'] == 'Linux' {

    Exec {
      path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
    }

    $tomcat_java_link = "${install_dir}/tomcat-java"
    $corretto_home    = "${java_root}/amazon-corretto-${java_version}-linux-x64"

    file { [
      "${install_dir}/bin",
      "${install_dir}/conf",
      "${install_dir}/lib",
      "${install_dir}/logs",
      "${install_dir}/temp",
      "${install_dir}/webapps",
      "${install_dir}/work",
    ]:
      ensure  => directory,
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0755',
      require => Class['tom_cat::install'],
    }

    file { [
      "${install_dir}/bin/setclasspath.sh",
      "${install_dir}/bin/catalina.sh",
      "${install_dir}/bin/startup.sh",
      "${install_dir}/bin/shutdown.sh",
    ]:
      ensure  => file,
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0755',
      require => Class['tom_cat::install'],
    }

    exec { 'set_tomcat_permissions':
      command => "chown -R ${tomcat_user}:${tomcat_group} ${install_dir}",
      unless  => "/bin/bash -c 'test \"$(stat -c %U ${install_dir})\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir})\" = \"${tomcat_group}\" && test \"$(stat -c %U ${install_dir}/bin)\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir}/bin)\" = \"${tomcat_group}\" && test \"$(stat -c %U ${install_dir}/bin/startup.sh)\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir}/bin/startup.sh)\" = \"${tomcat_group}\" && test \"$(stat -c %U ${install_dir}/bin/setclasspath.sh)\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir}/bin/setclasspath.sh)\" = \"${tomcat_group}\" && test \"$(stat -c %U ${install_dir}/bin/bootstrap.jar)\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir}/bin/bootstrap.jar)\" = \"${tomcat_group}\" && test \"$(stat -c %U ${install_dir}/bin/tomcat-juli.jar)\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir}/bin/tomcat-juli.jar)\" = \"${tomcat_group}\" && test \"$(stat -c %U ${install_dir}/conf)\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir}/conf)\" = \"${tomcat_group}\" && test \"$(stat -c %U ${install_dir}/conf/catalina.properties)\" = \"${tomcat_user}\" && test \"$(stat -c %G ${install_dir}/conf/catalina.properties)\" = \"${tomcat_group}\"'",
      require => [
        Class['tom_cat::install'],
        File["${install_dir}/bin"],
        File["${install_dir}/conf"],
        File["${install_dir}/lib"],
        File["${install_dir}/logs"],
        File["${install_dir}/temp"],
        File["${install_dir}/webapps"],
        File["${install_dir}/work"],
        File["${install_dir}/bin/setclasspath.sh"],
        File["${install_dir}/bin/catalina.sh"],
        File["${install_dir}/bin/startup.sh"],
        File["${install_dir}/bin/shutdown.sh"],
      ],
    }

    file { $tomcat_java_link:
      ensure  => link,
      target  => $corretto_home,
      require => [
        Class['tom_cat::install'],
        Exec['set_tomcat_permissions'],
      ],
    }

    file { "${install_dir}/bin/setenv.sh":
      ensure  => file,
      content => epp('tom_cat/setenv.sh.epp', {
        java_home   => $tomcat_java_link,
        tomcat_home => $install_dir,
        install_dir => $install_dir,
      }),
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0755',
      require => [
        File[$tomcat_java_link],
        Exec['set_tomcat_permissions'],
      ],
    }

    file { "${install_dir}/conf/server.xml":
      ensure  => file,
      content => epp('tom_cat/server.xml.epp', {
        shutdown_port => $shutdown_port,
        connector_port => $connector_port,
        redirect_port => $redirect_port,
        environment   => $environment,
      }),
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0644',
      require => Exec['set_tomcat_permissions'],
    }

    file { "${install_dir}/conf/tomcat-users.xml":
      ensure  => file,
      content => epp('tom_cat/tomcat-users.xml.epp', {
        admin_user     => $admin_user,
        admin_password => $admin_password.unwrap,
      }),
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0600',
      require => Exec['set_tomcat_permissions'],
    }

    file { "${install_dir}/webapps/manager/META-INF/context.xml":
      ensure  => file,
      content => epp('tom_cat/manager-context.xml.epp', {}),
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0644',
      require => File["${install_dir}/webapps/manager/META-INF"],
    }

    file { "${install_dir}/webapps/manager/META-INF":
      ensure  => directory,
      owner   => $tomcat_user,
      group   => $tomcat_group,
      mode    => '0755',
      require => [
        Class['tom_cat::install'],
        Exec['set_tomcat_permissions'],
      ],
    }

    file { "/etc/systemd/system/${service_name}.service":
      ensure  => file,
      content => epp('tom_cat/tomcat.service.epp', {
        service_name  => $service_name,
        tomcat_home   => $install_dir,
        install_dir   => $install_dir,
        tomcat_user   => $tomcat_user,
        tomcat_group  => $tomcat_group,
        java_home     => $tomcat_java_link,
      }),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      notify  => Exec['systemd_daemon_reload'],
    }

    exec { 'systemd_daemon_reload':
      command     => '/bin/systemctl daemon-reload',
      path        => ['/usr/bin', '/bin'],
      refreshonly => true,
    }

  } elsif $facts['kernel'] == 'windows' {

    file { "${windows_install_dir}/bin/setenv.bat":
      ensure  => file,
      content => epp('tom_cat/setenv.bat.epp', {
        java_version => $java_version,
        tomcat_home  => $windows_install_dir,
        install_dir  => $windows_install_dir,
      }),
    }

    file { "${windows_install_dir}/conf/server.xml":
      ensure  => file,
      content => epp('tom_cat/server.xml.epp', {
        shutdown_port => $shutdown_port,
        connector_port => $connector_port,
        redirect_port => $redirect_port,
        environment   => $environment,
      }),
    }

    file { "${windows_install_dir}/conf/tomcat-users.xml":
      ensure  => file,
      content => epp('tom_cat/tomcat-users.xml.epp', {
        admin_user     => $admin_user,
        admin_password => $admin_password.unwrap,
      }),
    }

  } else {
    fail("Unsupported kernel: ${facts['kernel']}")
  }
}
