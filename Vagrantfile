# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--memory", 800]
  end

  #
  # 172.28.33.9 is the pgbouncer vip
  # 172.28.33.10 is the postgresq vip
  #
  config.vm.define :pg01, primary: true do |pg01_config|
    pg01_config.vm.hostname = 'pg01'
    pg01_config.vm.network :private_network, ip: "172.28.33.11"
    pg01_config.vm.provision :shell, :path => "postgresql-cluster-setup.sh"
  end
  config.vm.define :pg02 do |pg02_config|
    pg02_config.vm.hostname = 'pg02'
    pg02_config.vm.network :private_network, ip: "172.28.33.12"
    pg02_config.vm.provision :shell, :path => "postgresql-cluster-setup.sh"
  end
end
