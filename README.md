Puppet Automation Demo
======================
This demo demonstrates how to write a manifest using Puppet to configure switches running Cumulus Linux and servers running Ubuntu. This manifest configures a CLOS topology running BGP unnumbered in the fabric with Layer 2 bridges to the hosts, and installs a webserver on one of the hosts to serve as a Hello World example. When the demo runs successfully, any server on the network should be able to access the webserver via the BGP routes established over the fabric.

This demo is written for the [cldemo-vagrant](https://github.com/cumulusnetworks/cldemo-vagrant) reference topology and applies the reference BGP numbered configuration from [cldemo-config-routing](https://github.com/cumulusnetworks/cldemo-config-routing).


Quickstart: Run the demo
------------------------
Before running this demo, install [VirtualBox](https://www.virtualbox.org/wiki/Download_Old_Builds) and [Vagrant](https://releases.hashicorp.com/vagrant/). The currently supported versions of VirtualBox and Vagrant can be found on the [cldemo-vagrant](https://github.com/cumulusnetworks/cldemo-vagrant).

    git clone https://github.com/cumulusnetworks/cldemo-vagrant
    cd cldemo-vagrant
    vagrant up oob-mgmt-server oob-mgmt-switch leaf01 leaf02 spine01 spine02 server01 server02
    vagrant ssh oob-mgmt-server
    ssh server01
    git clone https://github.com/cumulusnetworks/cldemo-automation-puppet
    cd cldemo-automation-puppet
    sudo su
    wget https://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb
    dpkg -i puppetlabs-release-pc1-xenial.deb
    apt-get update
    apt-get install puppetserver python-paramiko -qy
    rm -rf /etc/puppetlabs/code/environments/production
    ln -s  /home/cumulus/cldemo-automation-puppet/ /etc/puppetlabs/code/environments/production
    sed -i 's/-Xms2g/-Xms512m/g' /etc/default/puppetserver
    sed -i 's/-Xmx2g/-Xmx512m/g' /etc/default/puppetserver
    service puppetserver restart
    exit
    python install-puppet-agents.py leaf01,leaf02,spine01,spine02,server02
    ssh server01
    wget 172.16.2.101
    cat index.html

Topology Diagram
----------------
This demo runs on a spine-leaf topology with two single-attached hosts. Each device's management interface is connected to an out-of-band management switch and bridged with the out-of-band management server that runs the Puppetserver.

             +------------+       +------------+
             | spine01    |       | spine02    |
             |            |       |            |
             +------------+       +------------+
             swp1 |    swp2 \   / swp1    | swp2
                  |           X           |
            swp51 |   swp52 /   \ swp51   | swp52
             +------------+       +------------+
             | leaf01     |       | leaf02     |
             |            |       |            |
             +------------+       +------------+
             swp1 |                       | swp2
                  |                       |
             eth1 |                       | eth2
             +------------+       +------------+
             | server01   |       | server02   |
             |            |       |            |
             +------------+       +------------+


Setting up the Infrastructure
-----------------------------
Puppet uses a client-server model where a Puppet agent runs on each device in the network and periodically polls the Puppetserver daemon to check for updated configuration. To install the Puppetserver: 

    wget https://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb
    sudo dpkg -i puppetlabs-release-pc1-xenial.deb
    sudo apt-get update
    sudo apt-get install puppetserver -qy

Puppet configuration is broken up into environments, which can be found in `/etc/puppetlabs/code/environments`. Puppet environments are usually used to separate production from testing code. Each puppet agent is assigned to an environment (default `production`) and pulls the appropriate code from the server. This demo provides a `production` environment that can be dropped or symlinked directly into that folder. Assuming you cloned the repository into the cumulus user's home directory:

    sudo rm -rf /etc/puppetlabs/code/environments/production
    sudo ln -s  /home/cumulus/cldemo-automation-puppet /etc/puppetlabs/code/environments/production

If running this on a virtual machine, open the file `/etc/default/puppetserver` and configure the JVM to use 512 MB of RAM.

    JAVA_ARGS="-Xms512m -Xmx512m"

Finally, we start the puppetmaster.

    service puppetserver restart

Each device in the network needs the puppet agent installed. Puppet maintains a repository for the Cumulus version of the Puppet agent, which we just deploy to the servers. On each server and switch:

    sudo su
    wget https://apt.puppetlabs.com/pool/cumulus/PC1/p/puppetlabs-release-pc1/puppetlabs-release-pc1_0.9.4-1cumulus_all.deb
    dpkg -i puppetlabs-release-pc1_0.9.4-1cumulus_all.deb
    apt-get update
    apt-get install puppet-agent -qy
    echo 'server = oob-mgmt-server.lab.local' >> /etc/puppetlabs/puppet/puppet.conf
    /opt/puppetlabs/bin/puppet agent --test

This will create a certificate on the server that needs to be signed.

    # on the puppetserver
    /opt/puppetlabs/bin/puppet cert list
    /opt/puppetlabs/bin/puppet cert sign leaf01.lab.local

Back on the puppet agent, run the test command again. The test command manually triggers puppet to check for new configuration and applies it if it finds it.

    /opt/puppetlabs/bin/puppet agent --test

Assuming everything worked, run the following command to enable the puppet agent in the background. Roughly every 30 minutes, the puppet agent will attempt to query the puppetmaster for updated configuration. To force a client to update, run the test command again.

    sudo service puppet start


Anatomy of a Puppet Environment
-------------------------------
### `hieradata/`
This folder contains the data received via hiera, Puppet's tool for pulling variables. When a hiera is called, variables will be pulled from `fully.qualified.domain.name.yaml`, and will fall back to `common.yaml` if the file does not exist or if the variable is missing.

### `manifests/site.pp`
This file includes the node definitions for each device. In this file, each device in the network receives a node definition based on its hostname. Multiple devices can subscribe to the same node definition using regular expression matching, but each node must be mutually exclusive. Since we install an extra module on server02, server01 needs its own block. While this file could technically contain any puppet code, conventionally this file is kept very lean only including code in modules.

### `modules/`
Puppet code is broken into packages called "modules", and are included in the node definitions in the top-level manifest. Each module generally installs and configures a single package.

 * `manifests/init.pp`: This file contains the actual puppet code that installs and configures the node.
 * `templates/` - configuration file templates, written using Jinja2
 * `files/` - files to be copied to target hosts without modification

Expanding the Network
---------------------
To add a new device, add the new hostnames to the site.pp file and add the appropriate variables to the hieradata to connect them with the rest of the network. In a well-written manifest, templates and tasks should not need to be changed when new devices are added to the infrastructure. If you are using the reference topology, you can run vagrant up leaf03 server03 to add a third host and tor to the infrastructure, and install the puppet agent on the new devices.
