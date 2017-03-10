instance = search("aws_opsworks_instance", "self:true").first
layer = instance['layer_ids'].first

search("aws_opsworks_app","deploy:true").each do |candidate_app|
  if candidate_app['environment']['LAYER_ID'] == layer
    app = candidate_app
    app_path = "/srv/#{app['shortname']}"

    include_recipe 'apt::default'
    include_recipe 'chef_nginx::default'
    include_recipe 'varnish::default'

    package 'varnish' do
      package_name 'varnish'
    end

    template '/etc/nginx/sites-enabled/000-default' do
      source 'nginx.erb'
      variables({
        server_name: app['domains'].first,
        docroot: "#{app_path}/dist"
      })
    end

    execute "add_node_dep" do
      command "curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -"
      user "root"
      action :run
    end

    execute "install_node" do
      command "sudo apt-get install -y nodejs"
      user "root"
      action :run
    end

    execute "install_angular" do
      command "sudo npm install angular-cli universal-cli -g"
      user "root"
      action :run
    end

    execute "install_pm2" do
      command "sudo npm install pm2 -g"
      user "root"
      action :run
    end

    execute "restart_nginx" do
      command "service nginx restart"
      user "root"
      action :run
    end

    error_page = ""

    if app['environment']['VARNISH_ERROR_PAGE']
      error_page = "/srv/#{app['shortname']}/#{app['environment']['VARNISH_ERROR_PAGE']}"
    end

    template '/etc/varnish/default.vcl' do
      source 'default.vcl.erb'
      variables({
        errorpage: error_page
      })
    end

    varnish_config 'default' do
      listen_address '0.0.0.0'
      listen_port 80
    end

    varnish_log 'default'

    varnish_log 'default_ncsa' do
      log_format 'varnishncsa'
    end

    service 'varnish' do
      action [:restart]
    end
  end
end