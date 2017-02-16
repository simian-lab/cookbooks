instance = search("aws_opsworks_instance").first
layer = instance['layer_ids'].first

search("aws_opsworks_app","deploy:true").each do |candidate_app|
  if candidate_app['environment']['LAYER_ID'] == layer
    app = candidate_app
    app_path = "/srv/#{app['shortname']}"

    include_recipe 'apt::default'
    include_recipe 'chef_nginx::default'
    include_recipe 'chef_nginx::http_v2_module'

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
      command "sudo npm install angular-cli -g"
      user "root"
      action :run
    end

    execute "restart_nginx" do
      command "service nginx restart"
      user "root"
      action :run
    end
  end
end