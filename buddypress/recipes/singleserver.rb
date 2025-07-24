# Initial setup: just a couple vars we need
app = search(:aws_opsworks_app).first
app_path = "/srv/#{app['shortname']}"

# 1. We install the dependencies
mysql_service 'wp' do
  port '3306'
  version '5.7'
  initial_root_password 'm0nk3ysl4b'
  action [:create, :start]
end

# We mount the folders as EFS folders
if app['environment']['EFS_UPLOADS']
  execute 'mount_uploads' do
    command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport #{app['environment']['EFS_UPLOADS']}:/ #{app_path}/wp-content/uploads"
  end
end

if app['environment']['EFS_GALLERY']
  execute 'mount_gallery' do
    command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport #{app['environment']['EFS_GALLERY']}:/ #{app_path}/wp-content/gallery"
  end
end

if app['environment']['EFS_AUTHORS']
  execute 'mount_authors' do
    command "sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport #{app['environment']['EFS_AUTHORS']}:/ #{app_path}/wp-content/authors"
  end
end