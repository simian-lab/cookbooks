instance = search("aws_opsworks_instance", "self:true").first
layer = instance['layer_ids'].first

search("aws_opsworks_app","deploy:true").each do |candidate_app|
  if candidate_app['environment']['LAYER_ID'] == layer
    app = candidate_app
    app_path = "/srv/#{app['shortname']}"

    include_recipe 'apt::default'
    include_recipe 'varnish::default'

    package 'varnish' do
      package_name 'varnish'
    end

    execute "add_node_dep" do
      command "curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -"
      user "root"
      action :run
    end

    execute "install_htop" do
      command "sudo apt-get install -y htop"
      user "root"
      action :run
    end

    execute "install_node" do
      command "sudo apt-get install -y nodejs"
      user "root"
      action :run
    end

    execute "install_angular" do
      command "sudo npm install @angular/cli -g"
      user "root"
      action :run
    end

    execute "install_pm2" do
      command "sudo npm install pm2 -g"
      user "root"
      action :run
    end

    execute "install_pm2_typescript" do
      command "sudo pm2 install typescript"
      user "root"
      action :run
    end

    error_page = ""
    if app['environment']['VARNISH_ERROR_PAGE']
      error_page = "/srv/#{app['shortname']}/#{app['environment']['VARNISH_ERROR_PAGE']}"
    end

    admin_backend_ip = ""
    if app['environment']['VARNISH_ADMIN_BACKEND_IP']
      admin_backend_ip = "#{app['environment']['VARNISH_ADMIN_BACKEND_IP']}"
    end

    admin_backend_hostname = ""
    if app['environment']['VARNISH_ADMIN_BACKEND_HOSTNAME']
      admin_backend_hostname = "#{app['environment']['VARNISH_ADMIN_BACKEND_HOSTNAME']}"
    end

    template '/etc/varnish/default.vcl' do
      source 'default.vcl.erb'
      variables({
        errorpage: error_page,
        adminbackendip: admin_backend_ip,
        adminbackendhostname: admin_backend_hostname,
      })
    end

    varnish_config 'default' do
      listen_address '0.0.0.0'
      listen_port 80
    end

    service 'varnish' do
      action [:restart]
    end

    execute "disable varnish log" do
      command "ln -sf /dev/null /var/log/varnish/varnish.log"
      user "root"
      action :run
    end

    execute "disable varnishncsa log" do
      command "ln -sf /dev/null /var/log/varnish/varnishncsa.log"
      user "root"
      action :run
    end
  end
end