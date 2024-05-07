# This recipe installs the required Software for a multiserver setup.
# In summary, it:
#
# 1. Installs the required packages, which are:
#     - NFS (for use with EFS)
#     - Memcached (for use with ElastiCache)
#
# 2. Makes sure the /wp-content/uploads, /wp-content/gallery and
# /wp-content/authors folders exist (the latter two only if required)
# 3. Mounts /wp-content/uploads, /wp-content/gallery and /wp-content/authors
# as EFS mounts.
#
# Keep in mind that the `deploy` recipe should be run *before* this one, since
# the default WordPress file layout must be present.
#
# — Ivan Vásquez (ivan@simian.co) / Jan 29, 2017

# Initial setup: just a couple vars we need
app = {
  'environment' => {},
  'shortname' => {}
}

app_path = ''

aws_ssm_parameter_store 'getShortName' do
  path '/ApplyChefRecipes-Preset/Externado-Dev-WordPress-4eddee/SHORT_NAME'
  return_key 'SHORT_NAME'
  action :get
end

ruby_block "define-app" do
  block do
    app = {
      'environment' => {},
      'shortname' => node.run_state['SHORT_NAME']
    }

    app_path = "/srv/#{app['shortname']}"
  end
end

# 1. We install the dependencies
package 'Install NFS' do
  case node[:platform]
  when 'redhat', 'centos'
    package_name 'nfs-utils'
  when 'ubuntu', 'debian'
    package_name 'nfs-common'
  end
end

# 2. We make sure that the folders exist
if app['environment']['EFS_UPLOADS']
  directory "#{app_path}/wp-content/uploads" do
    owner 'www-data'
    group 'www-data'
    mode '0755'
    action :create
  end
end

if app['environment']['EFS_GALLERY']
  directory "#{app_path}/wp-content/gallery" do
    owner 'www-data'
    group 'www-data'
    mode '0755'
    action :create
  end
end

if app['environment']['EFS_AUTHORS']
  directory "#{app_path}/wp-content/authors" do
    owner 'www-data'
    group 'www-data'
    mode '0755'
    action :create
  end
end

# 3. We mount the folders as EFS folders
if app['environment']['EFS_UPLOADS']
  execute 'mount_uploads' do
    command "sudo mount -t nfs4 -o noresvport,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_UPLOADS']}:/ #{app_path}/wp-content/uploads"
  end
end

if app['environment']['EFS_GALLERY']
  execute 'mount_gallery' do
    command "sudo mount -t nfs4 -o noresvport,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_GALLERY']}:/ #{app_path}/wp-content/gallery"
  end
end

if app['environment']['EFS_AUTHORS']
  execute 'mount_authors' do
    command "sudo mount -t nfs4 -o noresvport,nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_AUTHORS']}:/ #{app_path}/wp-content/authors"
  end
end

# 4. Call the custom cron
if app['environment']['WP_CRON_HOSTS']
  string_wp_cron_hosts = "#{app['environment']['WP_CRON_HOSTS']}"
  wp_cron_hosts = string_wp_cron_hosts.split(',')
  wp_cron_hosts.each do |host|
    # If the site is protected by username and password, we must pass those credentials for the cron to work.
    if app['environment']['ACCESS_CREDENTIALS']
      cron "Cron for #{host}" do
        minute '*'
        command "curl --user #{app["environment"]["ACCESS_CREDENTIALS"]} https://#{host}/wp-cron.php?doing_wp_cron"
      end
    else
      cron "Cron for #{host}" do
        minute '*'
        command "wget -q -O -  https://#{host}/wp-cron.php?doing_wp_cron"
      end
    end
  end
end
