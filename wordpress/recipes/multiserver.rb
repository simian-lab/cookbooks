# This recipe installs the required Software for a multiserver setup.
# In summary, it:
#
# 1. Installs the required packages, which are:
#     - NFS (for use with EFS)
#     - Memcached (for use with ElastiCache)
#
# 2. Makes sure /wp-content/uploads exists
#
# 3. Mounts /wp-content/uploads as an EFS mount
#
# Keep in mind that the `deploy` recipe should be run *before* this one.
#
# — Ivan Vásquez (ivan@simian.co) / Jan 29, 2017

# Initial setup: just a couple vars we need
app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

# 1. We install the dependencies
package 'Install NFS' do
  case node[:platform]
  when 'redhat', 'centos'
    package_name 'nfs-utils'
  when 'ubuntu', 'debian'
    package_name 'nfs-common'
  end
end

package 'Install Memcached' do
  package_name 'php-memcache'
end

# 2. We make sure that the uploads folder exists
directory "#{app_path}/wp-content/uploads" do
  mode '0755'
  action :create
end

# 3. We mount the uploads folder as an EFS folder
execute 'mount_efs' do
  command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 #{app['environment']['EFS_VOLUME']}:/ #{app_path}/wp-content/uploads"
end