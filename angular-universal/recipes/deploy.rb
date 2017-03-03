instance = search("aws_opsworks_instance").first
layer = instance['layer_ids'].first

search("aws_opsworks_app","deploy:true").each do |candidate_app|
  if candidate_app['environment']['LAYER_ID'] == layer
    app = candidate_app
    app_path = "/srv/#{app['shortname']}"

    Chef::Log.info("Deploying #{app['shortname']}")

    application app_path do
      environment.update(app["environment"])

      git app_path do
        repository app["app_source"]["url"]
        revision app["app_source"]["revision"]
        deploy_key app["app_source"]["ssh_key"]
      end
    end

    # make sure permissions are correct
    execute "chown-data-www" do
      command "chown -R www-data:www-data #{app_path}"
      user "root"
      action :run
      not_if "stat -c %U #{app_path} | grep www-data"
    end

    execute 'install_dependencies' do
      user "root"
      command "npm install"
      cwd app_path
    end

    execute 'build_ng' do
      user "root"
      # We don't use target=production for now.
      #command "ung build --target=production --environment=#{app['environment']['ENV_NAME']}"
      command "ung build --environment=#{app['environment']['ENV_NAME']}"
      cwd app_path
    end

    # Make sure UNIVERSAL_CACHE works
    ruby_block "php_env_vars" do
      block do
        file = Chef::Util::FileEdit.new("#{app_path}/dist/client/index.html")
        Chef::Log.info("Setting async for the js bundle")
        file.search_file_replace /src="client.bundle.js"/, "async=\"\" src=\"client.bundle.js\""
        file.write_file
      end
    end

    execute 'start_pm2' do
      user "root"
      command "pm2 start server.bundle.js"
      cwd "#{app_path}/dist/server"
    end
  end
end