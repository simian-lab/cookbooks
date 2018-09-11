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

    execute 'install_dependencies' do
      user "root"
      command "npm install --unsafe-perm"
      cwd app_path
    end

    # Fix permissions
    execute "chown-data-www" do
      command "chown -R www-data:www-data #{app_path}"
      user "root"
      action :run
    end

    execute "chmod-755" do
      command "chmod -R 755 #{app_path}"
      user "root"
      action :run
    end

    execute "cp-template-ecosystem" do
      command "cp #{app_path}/ecosystem.config.js.templ #{app_path}/ecosystem.config.js"
      user "root"
      action :run
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