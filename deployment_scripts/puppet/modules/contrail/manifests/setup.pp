class contrail::setup (
  $node_name
  ) {

  if $node_name == $contrail::deployment_node {
    file_line { 'disable_sslv3':
      path => '/etc/java-6-openjdk/security/java.security',
      line => 'jdk.tls.disabledAlgorithms=SSLv3',
    } ->
    file {'/tmp/ha.py.patch':
      ensure => file,
      source => 'puppet:///modules/contrail/ha.py.patch'
    } ->
    exec {'ha.py.patch':
    command => '/usr/bin/patch -f -p0 < /tmp/ha.py.patch'
    } ->

    file {'/tmp/keepalived_conf_template.py.patch':
      ensure => file,
      source => 'puppet:///modules/contrail/keepalived_conf_template.py.patch'
    } ->
    exec {'keepalived_conf_template.py.patch':
    command => '/usr/bin/patch -f -p0 < /tmp/keepalived_conf_template.py.patch'
    } ->

    file {'/tmp/provision.py.patch':
      ensure => file,
      source => 'puppet:///modules/contrail/provision.py.patch'
    } ->
    exec {'provision.py.patch':
    command => '/usr/bin/patch -f -p0 < /tmp/provision.py.patch'
    } ->

    # Database installation
    run_fabric { 'install_database': } ->
    run_fabric { 'setup_database': } ->
      notify{"Waiting for cassandra nodes: ${contrail::contrail_node_num}":} ->
      exec {'wait_for_cassandra':
        provider  => 'shell',
        command   => "if [ `/usr/bin/nodetool status|grep ^UN|wc -l` -lt ${contrail::contrail_node_num} ]; then exit 1; fi",
        tries     => 10, # wait for whole cluster is up: 10 tries every 30 seconds = 5 min
        try_sleep => 30,
      } ->
    # Installing components
    run_fabric { 'install_cfgm': } ->
    run_fabric { 'install_control': } ->
    run_fabric { 'install_collector': } ->
    run_fabric { 'install_webui': } ->
    # Some fixups
    run_fabric { 'setup_contrail_keepalived': } ->
    run_fabric { 'fixup_restart_haproxy_in_collector': } ->
    run_fabric { 'fix-service-tenant-name':
      hostgroup => 'control',
      command   => "sed -i '49s/service/services/g' /usr/local/lib/python2.7/dist-packages/contrail_provisioning/config/quantum_in_keystone_setup.py",
    } ->
    # Setting up the components
    run_fabric { 'setup_cfgm': } ->
    run_fabric { 'setup_control': } ->
    run_fabric { 'setup_collector': } ->
    run_fabric { 'setup_webui': }
  }
}