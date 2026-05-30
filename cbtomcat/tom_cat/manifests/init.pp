# Manages NGINX reverse proxy for Tomcat.
#
# Exposes Tomcat through:
#   http://tomcat.jcloudcodes.com
#
# Flow:
# Tomcat listens locally on 8085.
# NGINX listens on 80 and proxies traffic to Tomcat.

class tom_cat::nginx (
  String $server_name = 'tomcat.jcloudcodes.com',
  String $tomcat_port = '8085',
) {

  # Install NGINX package.
  package { 'nginx':
    ensure => installed,
  }

  # Manage Tomcat NGINX reverse proxy configuration.
  file { '/etc/nginx/conf.d/tomcat.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',

    content => inline_epp(@('EOT')
upstream tomcat_backend {
    server 127.0.0.1:<%= $tomcat_port %>;
}

server {

    listen 80;

    server_name <%= $server_name %>;

    access_log /var/log/nginx/tomcat-access.log;
    error_log  /var/log/nginx/tomcat-error.log;

    client_max_body_size 200M;

    location / {

        proxy_pass http://tomcat_backend;

        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
| EOT
    , {
      'server_name' => $server_name,
      'tomcat_port' => $tomcat_port,
    }),

    require => Package['nginx'],
    notify  => Exec['validate_tomcat_nginx_config'],
  }

  # Validate NGINX configuration before restart.
  exec { 'validate_tomcat_nginx_config':
    command     => 'nginx -t',
    refreshonly => true,
    subscribe   => File['/etc/nginx/conf.d/tomcat.conf'],
    notify      => Service['nginx'],
  }

  # Enable and start NGINX service.
  service { 'nginx':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => Package['nginx'],
  }
}
