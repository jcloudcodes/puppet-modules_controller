class tom_cat::service (
  String $service_name = 'tomcat',
  String $tomcat_home = '/jcloudcodes/cbtom-cat',
  String $install_dir = '/jcloudcodes/cbtom-cat',
  String $windows_install_dir = 'C:/Tomcat',
) {

  if $facts['kernel'] == 'Linux' {
    service { $service_name:
      ensure     => running,
      enable     => true,
      provider   => systemd,
      hasrestart => true,
      require    => Class['tom_cat::config'],
      subscribe  => [
        File["/etc/systemd/system/${service_name}.service"],
        File["${install_dir}/bin/setenv.sh"],
        File["${install_dir}/conf/server.xml"],
        File["${install_dir}/conf/tomcat-users.xml"],
        File["${tomcat_home}/tomcat-java"],
      ],
    }
  } elsif $facts['kernel'] == 'windows' {
    service { $service_name:
      ensure    => running,
      enable    => true,
      subscribe => [
        File["${windows_install_dir}/bin/setenv.bat"],
        File["${windows_install_dir}/conf/server.xml"],
        File["${windows_install_dir}/conf/tomcat-users.xml"],
      ],
    }
  } else {
    fail("Unsupported kernel: ${facts['kernel']}")
  }
}
