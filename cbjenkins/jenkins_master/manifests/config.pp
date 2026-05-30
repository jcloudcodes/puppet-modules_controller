# Configures Jenkins custom runtime settings.
#
# Responsibilities of this class:
# - Creates Jenkins custom data directory.
# - Creates Jenkins Java symlink.
# - Repoints Jenkins to Corretto Java.
# - Repoints Jenkins home to /jcloudcodes/cbjenkins/data.
# - Manages Jenkins systemd override.
# - Manages Jenkins log/cache permissions.
# - Manages Jenkins logrotate and limits configuration.
#
# NOTE:
# /jcloudcodes
# /jcloudcodes/cbjenkins
# /jcloudcodes/cbjenkins-java
# are created in install.pp to avoid duplicate File[] declarations.

class jenkins_master::config (
  String $http_port,
  String $ajp_port,
  String $service_name,
  String $jenkins_user,
  String $listen_address,
  String $config_file,
  String $corretto_jdk_version,
) {

  # Set default command search path for all exec resources in this class.
  Exec {
    path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
  }

  # Define custom Jenkins and Java paths.
  $jenkins_root       = '/jcloudcodes/cbjenkins'
  $jenkins_home       = "${jenkins_root}/data"
  $jenkins_java_root  = '/jcloudcodes/cbjenkins-java'
  $jenkins_java_link  = "${jenkins_root}/jenkins-java"
  $jenkins_java_cmd   = "${jenkins_java_link}/bin/java"
  $corretto_home      = "${jenkins_java_root}/amazon-corretto-${corretto_jdk_version}-linux-x64"

  # Define JVM heap and Jenkins Java options.
  $heap_size = '-Xmx4g -Xms2g'

  $je_java_options = "-server -Djava.awt.headless=true ${heap_size} -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/var/log/jenkins"

  # Print useful debug information during Puppet run.
  # notify { "config_file from remote: ${config_file}": }
  # notify { "jenkins_home working: ${jenkins_home}": }
  # notify { "jenkins_java_cmd: ${jenkins_java_cmd}": }
  # notify { "corretto_home: ${corretto_home}": }

  # Create Jenkins custom data directory.
  # Parent /jcloudcodes/cbjenkins is managed in install.pp.
  file { $jenkins_home:
    ensure  => directory,
    owner   => $jenkins_user,
    group   => $jenkins_user,
    mode    => '0755',
    require => Class['jenkins_master::install'],
  }

  # Create Jenkins Java symlink.
  # This allows Jenkins to use custom Corretto Java without relying on system Java.
  file { $jenkins_java_link:
    ensure  => link,
    target  => $corretto_home,
    require => Class['jenkins_master::install'],
  }

  # Ensure Jenkins home points to the custom data directory.
  file_line { 'Enforce JENKINS_HOME':
    ensure  => present,
    path    => $config_file,
    match   => '^JENKINS_HOME=',
    line    => "JENKINS_HOME=\"${jenkins_home}\"",
    require => File[$jenkins_home],
  }

  # Ensure Jenkins runs as the configured Jenkins user.
  file_line { 'Enforce JENKINS_USER':
    ensure => present,
    path   => $config_file,
    match  => '^JENKINS_USER=',
    line   => "JENKINS_USER=\"${jenkins_user}\"",
  }

  # Ensure Jenkins uses custom Corretto Java command.
  file_line { 'Enforce JENKINS_JAVA_CMD':
    ensure  => present,
    path    => $config_file,
    match   => '^JENKINS_JAVA_CMD=',
    line    => "JENKINS_JAVA_CMD=\"${jenkins_java_cmd}\"",
    require => File[$jenkins_java_link],
  }

  # Ensure Jenkins JVM options are managed.
  file_line { 'Enforce JENKINS_JAVA_OPTIONS':
    ensure => present,
    path   => $config_file,
    match  => '^JENKINS_JAVA_OPTIONS=',
    line   => "JENKINS_JAVA_OPTIONS=\"${je_java_options}\"",
  }

  # Ensure Jenkins HTTP port is managed.
  file_line { 'Enforce JENKINS_PORT':
    ensure => present,
    path   => $config_file,
    match  => '^JENKINS_PORT=',
    line   => "JENKINS_PORT=\"${http_port}\"",
  }

  # Ensure Jenkins listen address is managed.
  file_line { 'Enforce JENKINS_LISTEN_ADDRESS':
    ensure => present,
    path   => $config_file,
    match  => '^JENKINS_LISTEN_ADDRESS=',
    line   => "JENKINS_LISTEN_ADDRESS=\"${listen_address}\"",
  }

  # Ensure Jenkins AJP port is managed.
  file_line { 'Enforce JENKINS_AJP_PORT':
    ensure => present,
    path   => $config_file,
    match  => '^JENKINS_AJP_PORT=',
    line   => "JENKINS_AJP_PORT=\"${ajp_port}\"",
  }

  # Create Jenkins systemd override directory.
  file { '/etc/systemd/system/jenkins.service.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Create Jenkins systemd override to force custom Jenkins home and Java.
  file { '/etc/systemd/system/jenkins.service.d/override.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => @("EOF"),
[Service]
Environment="JENKINS_HOME=${jenkins_home}"
Environment="JAVA_HOME=${jenkins_java_link}"
Environment="PATH=${jenkins_java_link}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="JENKINS_JAVA_CMD=${jenkins_java_cmd}"
Environment="JENKINS_JAVA_OPTIONS=${je_java_options}"
| EOF
    require => [
      File['/etc/systemd/system/jenkins.service.d'],
      File[$jenkins_home],
      File[$jenkins_java_link],
    ],
    notify  => Exec['systemd-daemon-reload'],
  }

  # Reload systemd only when the Jenkins override changes.
  exec { 'systemd-daemon-reload':
    command     => 'systemctl daemon-reload',
    refreshonly => true,
  }

  # Jenkins operational directories that need Jenkins ownership.
  $jenkins_master_dirs = [
    '/var/log/jenkins',
    '/var/cache/jenkins',
  ]

  # Ensure Jenkins log/cache directories exist and are owned by Jenkins.
  $jenkins_master_dirs.each |$jenkins_master_dir| {

    file { $jenkins_master_dir:
      ensure => directory,
      owner  => $jenkins_user,
      group  => $jenkins_user,
      mode   => '0755',
    }

    # Correct owner recursively only when incorrect owner is detected.
    exec { "Manage ${jenkins_master_dir} owner permissions":
      command  => "chown -R ${jenkins_user}:${jenkins_user} ${jenkins_master_dir}",
      provider => shell,
      onlyif   => "test $(find ${jenkins_master_dir} ! -user ${jenkins_user} | wc -l) -gt 0",
      require  => File[$jenkins_master_dir],
    }

    # Correct group recursively only when incorrect group is detected.
    exec { "Manage ${jenkins_master_dir} group permissions":
      command  => "chown -R ${jenkins_user}:${jenkins_user} ${jenkins_master_dir}",
      provider => shell,
      onlyif   => "test $(find ${jenkins_master_dir} ! -group ${jenkins_user} | wc -l) -gt 0",
      require  => File[$jenkins_master_dir],
    }
  }

  # Install Jenkins logrotate configuration.
  file { '/etc/logrotate.d/jenkins':
    ensure => file,
    source => 'puppet:///modules/jenkins_master/jenkins',
  }

  # Install Jenkins Linux limits configuration.
  file { '/etc/security/limits.d/jenkins.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('jenkins_master/jenkins.conf.epp', {
      'agentname' => $jenkins_user,
    }),
  }

  # Disable Transparent Huge Pages for Jenkins runtime stability.
  exec { 'Disable Transparent Huge Pages for Jenkins Master':
    command  => 'echo "never" > /sys/kernel/mm/transparent_hugepage/enabled',
    provider => shell,
    unless   => [
      'test ! -f /sys/kernel/mm/transparent_hugepage/enabled',
      'cat /sys/kernel/mm/transparent_hugepage/enabled | grep "\[never\]"',
    ],
  }
  # Install Git for Jenkins Pipeline script from SCM support.
  # This allows Jenkins jobs to clone Git repositories and validate SCM URLs from the UI.
  package { 'git':
    ensure  => installed,
    require => Class['jenkins_master::install'],
  }
}
