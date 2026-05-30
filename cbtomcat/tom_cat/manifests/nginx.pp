# Manages NGINX reverse proxy for Tomcat.
class tom_cat::nginx (
  String $server_name = 'tomcat.jcloudcodes.com',
  String $tomcat_port = '8085',
) {

  package { 'nginx':
    ensure => installed,
  }

  file { '/etc/nginx/conf.d/tomcat.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('tom_cat/tomcat-nginx.conf.epp', {
      'server_name' => $server_name,
      'tomcat_port' => $tomcat_port,
    }),
    require => Package['nginx'],
    notify  => Exec['validate_tomcat_nginx_config'],
  }

  exec { 'validate_tomcat_nginx_config':
    command     => 'nginx -t',
    refreshonly => true,
    subscribe   => File['/etc/nginx/conf.d/tomcat.conf'],
    notify      => Service['nginx'],
  }

  service { 'nginx':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => Package['nginx'],
  }
}
