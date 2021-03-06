class puphpet::xhprof (
  $php_version      = '54',
  $webroot_location = '/var/www',
  $webserver_service
) inherits puphpet::params {

    exec { 'delete-xhprof-path-if-empty-folder':
      command => "rm -rf ${webroot_location}/xhprof",
      onlyif  => "test ! -f ${webroot_location}/xhprof/extension/config.m4"
    }

    vcsrepo { "${webroot_location}/xhprof":
      ensure   => present,
      provider => git,
      source   => 'https://github.com/facebook/xhprof.git',
      require  => Exec['delete-xhprof-path-if-empty-folder']
    }

    file { "${webroot_location}/xhprof/xhprof_html":
      ensure  => directory,
      mode    => 0775,
      require => Vcsrepo["${webroot_location}/xhprof"]
    }

  if $::operatingsystem == 'ubuntu' and $php_version == '54' {
    exec { 'configure xhprof':
      cwd     => "${webroot_location}/xhprof/extension",
      command => 'phpize && ./configure && make && make install',
      require => Vcsrepo["${webroot_location}/xhprof"]
    }

    puphpet::ini { 'add xhprof ini extension':
      php_version  => $php_version,
      webserver    => $webserver_service,
      ini_filename => '20-xhprof-custom.ini',
      entry        => 'XHPROF/extension',
      value        => 'xhprof.so',
      ensure       => 'present',
      require      => Exec['configure xhprof']
    }

    puphpet::ini { 'add xhprof ini xhprof.output_dir':
      php_version  => $php_version,
      webserver    => $webserver_service,
      ini_filename => '20-xhprof-custom.ini',
      entry        => 'XHPROF/xhprof.output_dir',
      value        => '/tmp',
      ensure       => 'present',
      require      => Exec['configure xhprof']
    }

    composer::exec { 'xhprof-composer-run':
      cmd     => 'install',
      cwd     => "${webroot_location}/xhprof",
      require => [
        Class['composer'],
        Exec['configure xhprof']
      ]
    }
  } else {
    $xhprof_package = $puphpet::params::xhprof_package

    if ! defined(Package[$xhprof_package]) {
      package { $xhprof_package:
        ensure  => installed,
        require => Package['php'],
        notify  => $xhprof_webserver_service,
      }
    }

    composer::exec { 'xhprof-composer-run':
      cmd     => 'install',
      cwd     => "${webroot_location}/xhprof",
      require => [
        Class['composer'],
        File["${webroot_location}/xhprof/xhprof_html"]
      ]
    }
  }

}
