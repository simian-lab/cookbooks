instance = search("aws_opsworks_instance").first
layer = instance['layer_ids'].first

search("aws_opsworks_app","deploy:true").each do |candidate_app|
  if candidate_app['environment']['LAYER_ID'] == layer
    app = candidate_app
    app_path = "/srv/#{app['shortname']}"
  end
end

if !app
  app = search("aws_opsworks_app", "deploy:true").first
  app_path = "/srv/#{app['shortname']}"
end

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
  command "ng build --prod"
  cwd app_path
end