class cb_jenkins::service (
  String $service_name = 'jenkins',
) {

  service { $service_name:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => Class['cb_jenkins::config'],
    subscribe  => [
      File['/etc/systemd/system/jenkins.service.d/override.conf'],
      File['/jcloudcodes/cbjenkins/jenkins-java'],
    ],
  }
}
