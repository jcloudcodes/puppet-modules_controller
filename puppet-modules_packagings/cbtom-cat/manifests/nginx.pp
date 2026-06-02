# Manages NGINX reverse proxy for Tomcat.
class tom_cat::nginx (
  String $server_name = 'tomcat.jcloudcodes.com',
  String $tomcat_port = '8085',
) {

  if $facts['kernel'] == 'Linux' {

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

    exec { 'allow_nginx_tomcat_selinux_connect':
      command => 'setsebool -P httpd_can_network_connect 1',
      path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      unless  => "/bin/bash -c 'command -v getenforce >/dev/null 2>&1 && test \"$(getenforce)\" = \"Enforcing\" && getsebool httpd_can_network_connect | grep -q -- \"--> on\"'",
      before  => Service['nginx'],
    }

    exec { 'validate_tomcat_nginx_config':
      command     => 'nginx -t',
      path        => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      refreshonly => true,
      subscribe   => File['/etc/nginx/conf.d/tomcat.conf'],
      notify      => Service['nginx'],
    }

    service { 'nginx':
      ensure     => running,
      enable     => true,
      hasrestart => true,
      require    => [
        Package['nginx'],
        Exec['allow_nginx_tomcat_selinux_connect'],
      ],
    }

  } elsif $facts['kernel'] == 'windows' {

    $windows_powershell      = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
    $windows_temp            = 'C:/temp'
    $windows_nginx_home      = lookup('tom_cat::windows_nginx_home', { 'default_value' => 'C:/jcloudcodes/cbtom-nginx' })
    $windows_nginx_version   = lookup('tom_cat::windows_nginx_version', { 'default_value' => '1.28.0' })
    $windows_nginx_task_name = lookup('tom_cat::windows_nginx_task_name', { 'default_value' => 'tomcat-nginx' })
    $windows_nginx_version_file = "${windows_nginx_home}/.nginx_version"
    $windows_nginx_url          = "https://nginx.org/download/nginx-${windows_nginx_version}.zip"

    file { $windows_nginx_home:
      ensure => directory,
    }

    file { 'C:/temp/install-nginx.ps1':
      ensure  => file,
      source  => 'puppet:///modules/tom_cat/windows/install-nginx.ps1',
      require => File[$windows_temp],
    }

    exec { 'install_windows_nginx':
      command     => "${windows_powershell} -NoProfile -ExecutionPolicy Bypass -File C:/temp/install-nginx.ps1 -NginxVersion ${windows_nginx_version} -NginxUrl ${windows_nginx_url} -NginxHome ${windows_nginx_home} -VersionFile ${windows_nginx_version_file}",
      unless      => "${windows_powershell} -NoProfile -Command \"if ((Test-Path '${windows_nginx_home}/nginx.exe') -and (Test-Path '${windows_nginx_version_file}') -and ((Get-Content '${windows_nginx_version_file}' -ErrorAction SilentlyContinue | Select-Object -First 1) -eq '${windows_nginx_version}')) { exit 0 } else { exit 1 }\"",
      cwd         => $windows_temp,
      environment => [
        "TEMP=${windows_temp}",
        "TMP=${windows_temp}",
      ],
      timeout     => 1800,
      require     => [
        File[$windows_temp],
        File[$windows_nginx_home],
        File['C:/temp/install-nginx.ps1'],
      ],
      logoutput   => true,
    }

    file { "${windows_nginx_home}/conf/nginx.conf":
      ensure  => file,
      content => epp('tom_cat/tomcat-nginx-windows.conf.epp', {
        'server_name' => $server_name,
        'tomcat_port' => $tomcat_port,
      }),
      require => Exec['install_windows_nginx'],
      notify  => Exec['reload_windows_nginx'],
    }

    exec { 'register_windows_nginx_startup_task':
      command   => "${windows_powershell} -NoProfile -Command \"\$action = New-ScheduledTaskAction -Execute '${windows_nginx_home}/nginx.exe' -Argument '-p \\\"${windows_nginx_home}\\\"'; \$trigger = New-ScheduledTaskTrigger -AtStartup; \$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries; Register-ScheduledTask -TaskName '${windows_nginx_task_name}' -Action \$action -Trigger \$trigger -Settings \$settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null\"",
      unless    => "${windows_powershell} -NoProfile -Command \"if (Get-ScheduledTask -TaskName '${windows_nginx_task_name}' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }\"",
      require   => Exec['install_windows_nginx'],
      logoutput => true,
    }

    exec { 'allow_windows_nginx_http_firewall':
      command   => "${windows_powershell} -NoProfile -Command \"New-NetFirewallRule -DisplayName 'Tomcat Nginx HTTP' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80 | Out-Null\"",
      unless    => "${windows_powershell} -NoProfile -Command \"if (Get-NetFirewallRule -DisplayName 'Tomcat Nginx HTTP' -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }\"",
      require   => Exec['install_windows_nginx'],
      logoutput => true,
    }

    exec { 'ensure_windows_nginx_running':
      command     => "${windows_powershell} -NoProfile -Command \"Start-Process -FilePath '${windows_nginx_home}/nginx.exe' -WorkingDirectory '${windows_nginx_home}' -WindowStyle Hidden\"",
      unless      => "${windows_powershell} -NoProfile -Command \"if (Get-Process -Name nginx -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }\"",
      require     => [
        File["${windows_nginx_home}/conf/nginx.conf"],
        Exec['register_windows_nginx_startup_task'],
        Exec['allow_windows_nginx_http_firewall'],
      ],
      refreshonly => false,
      logoutput   => true,
    }

    exec { 'reload_windows_nginx':
      command     => "${windows_powershell} -NoProfile -Command \"if (Get-Process -Name nginx -ErrorAction SilentlyContinue) { & '${windows_nginx_home}/nginx.exe' -p '${windows_nginx_home}' -s reload } else { Start-Process -FilePath '${windows_nginx_home}/nginx.exe' -WorkingDirectory '${windows_nginx_home}' -WindowStyle Hidden }\"",
      refreshonly => true,
      require     => Exec['install_windows_nginx'],
      logoutput   => true,
    }

  } else {
    fail("Unsupported kernel: ${facts['kernel']}")
  }
}
