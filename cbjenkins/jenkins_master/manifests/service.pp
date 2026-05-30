class jenkins_master::service (
  String $service_name = 'jenkins',
) {

  service { $service_name:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => Class['jenkins_master::config'],
    subscribe  => [
      File['/etc/systemd/system/jenkins.service.d/override.conf'],
      File['/jcloudcodes/cbjenkins/jenkins-java'],
    ],
  }
}
