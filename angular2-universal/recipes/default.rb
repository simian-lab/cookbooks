app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

package "git" do
  # workaround for:
  # WARNING: The following packages cannot be authenticated!
  # liberror-perl
  # STDERR: E: There are problems and -y was used without --force-yes
  options "--force-yes" if node["platform"] == "ubuntu" && node["platform_version"] == "14.04"
end

# install nvm
include_recipe 'nvm'

# install node.js v0.10.5
nvm_install 'v6.2.2' do
  from_source false
  alias_as_default true
  action :create
end