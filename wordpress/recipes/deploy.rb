app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

# Now we finally configure the app
application app_path do
  environment.update(app['environment'])

  git app_path do
    repository app['app_source']['url']
    revision app['app_source']['revision']
    deploy_key app['app_source']['ssh_key']
  end
end

# make sure permissions are correct
execute "chown-data-www" do
  command "chown -R www-data:www-data #{app_path}"
  user "root"
  action :run
  not_if "stat -c %U #{app_path} | grep www-data"
end