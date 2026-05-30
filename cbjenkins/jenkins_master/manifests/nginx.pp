# Manages NGINX reverse proxy for Jenkins.
#
# Exposes Jenkins through:
#   http://jenkins.jcloudcodes.com
#
# Flow:
# Jenkins listens locally on 8080.
# NGINX listens on 80 and proxies traffic to Jenkins.

class jenkins_master::nginx (
  String $server_name  = 'jenkins.jcloudcodes.com',
  String $jenkins_port = '8080',
) {

  # Install NGINX package.
  package { 'nginx':
    ensure => installed,
  }

  # Manage Jenkins NGINX reverse proxy config.
  file { '/etc/nginx/conf.d/jenkins.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("EOF"),
upstream jenkins_backend {
    server 127.0.0.1:${jenkins_port};
}

server {
    listen 80;
    server_name ${server_name};

    access_log /var/log/nginx/jenkins-access.log;
    error_log  /var/log/nginx/jenkins-error.log;

    client_max_body_size 200M;

    location / {
        proxy_pass http://jenkins_backend;

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
| EOF
    require => Package['nginx'],
    notify  => Service['nginx'],
  }

  # Validate NGINX configuration before reload/restart.
  exec { 'validate_nginx_config':
    command     => 'nginx -t',
    refreshonly => true,
    subscribe   => File['/etc/nginx/conf.d/jenkins.conf'],
    before      => Service['nginx'],
  }

  # Enable and start NGINX.
  service { 'nginx':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require    => Package['nginx'],
  }
}
