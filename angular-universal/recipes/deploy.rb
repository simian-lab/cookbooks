app = search("aws_opsworks_app","deploy:true").first
app_path = "/srv/#{app['shortname']}"

application app_path do
  environment.update(app["environment"])

  git app_path do
    repository app["app_source"]["url"]
    revision app["app_source"]["revision"]
    deploy_key app["app_source"]["ssh_key"]
  end
end