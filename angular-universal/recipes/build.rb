execute 'install_dependencies' do
  command "npm install"
  cwd app_path
  user 'nginx'
end

execute 'build_ng' do
  command "ng build --prod"
  cwd app_path
  user 'nginx'
end