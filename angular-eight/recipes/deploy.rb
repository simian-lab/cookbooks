instance = search("aws_opsworks_instance", "self:true").first
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

    # Make sure permissions are correct for installation
    execute "chmod-install" do
      command "chown -R 777 #{app_path}"
      user "root"
      action :run
      not_if "stat -c %U #{app_path} | grep www-data"
    end

    execute 'install_dependencies' do
      user "root"
      command "npm install"
      cwd app_path
    end

    # Fix permissions
    execute "chown-data-www" do
      command "chown -R www-data:www-data #{app_path}"
      user "root"
      action :run
      not_if "stat -c %U #{app_path} | grep www-data"
    end

    execute "chmod-standart" do
      command "chmod -R 755 #{app_path}"
      user "root"
      action :run
      not_if "stat -c %U #{app_path} | grep www-data"
    end

    execute 'build_npm' do
      user "root"
      command "npm run build:#{app['environment']['ENV_NAME']}"
      cwd app_path
    end

    execute 'start_pm2' do
      user "root"
      command "pm2 start ecosystem.config.js"
      cwd app_path
    end
  end
end