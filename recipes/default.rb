#
# Cookbook Name:: dspace
# Recipe:: default
#
# Copyright 2013, Lisa Walley
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# @note tested on lucid64 vagrant box
# @todo support different platforms
# @todo support different DSpace versions
# @todo add dspace user instead of using tomcat user
# @todo fix file permissions

# Add to or override default settings of other recipes.
node[:postgresql][:pg_hba] << {
  :type   => "local",
  :db     => node[:dspace][:database][:name],
  :user   => node[:dspace][:database][:user],
  :addr   => nil,
  :method => "md5"
}
node[:tomcat][:java_options] = "-Xmx512M -Xms64M -Dfile.encoding=UTF-8"

include_recipe "apt"
include_recipe "database::postgresql"
include_recipe "postgresql::server"
include_recipe "java"
include_recipe "ant"
include_recipe "maven"
include_recipe "tomcat"
include_recipe "tomcat::users"

# Set default connection info for PostgreSQL
postgresql_connection_info = {
  :host => node[:dspace][:database][:host],
  :port => node[:dspace][:database][:port],
  :username => "postgres",
  :password => node[:postgresql][:password][:postgres]
}

# Create PostgreSQL user for DSpace database
postgresql_database_user node[:dspace][:database][:user] do
 connection postgresql_connection_info
 password node[:dspace][:database][:password]
 action :create
end

# Create PostgreSQL database for DSpace with UNICODE encoding
#   option and owned by the DSpace PostgreSQL user
postgresql_database node[:dspace][:database][:name] do
  connection postgresql_connection_info
  encoding node[:dspace][:database][:encoding]
  collation node[:dspace][:database][:collation]
  template node[:dspace][:database][:template]
  owner node[:dspace][:database][:user]
  action :create
end

# @note PostgreSQL JDBC driver is included as part of the
#   default DSpace build.

# Switch out Tomcat server.xml file for provided template
# @note DSpace requires URIEncoding="UTF-8" in Connector
#   setting of Tomcat server.xml. Tomcat recipe includes
#   UTF-8 encoding by default, but we also need to add some
#   extra settings to that file so we've got our own
#   template.
# @see https://github.com/opscode-cookbooks/tomcat
template "#{node[:tomcat][:config_dir]}/server.xml" do
  source "server.xml.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, resources(:service => "tomcat")
end


# Shared variables for DSpace installation tasks
base_src_dir     = "#{node[:dspace][:dir]}/src"
release_src_dir  = "#{base_src_dir}/DSpace-dspace-#{node[:dspace][:version]}"
release_name     = "DSpace #{node[:dspace][:version]}"

# Create the DSpace home and source directories
[node[:dspace][:dir], base_src_dir].each do |dir|
  directory dir do
    # @note DSpace needs to run as the same user as Tomcat
    #   We could create a separate user, for now lets just use
    #   Tomcat settings.
    owner node[:tomcat][:user]
    group node[:tomcat][:group]
    mode 0755
    action :create
  end
end

# Fetch DSpace source code. Alternative would be to get default
#   release that does not include the source code.
execute "download #{release_name} and extract source code" do
  user node[:tomcat][:user]
  cwd base_src_dir
  targz = "dspace-#{node[:dspace][:version]}.tar.gz"
  url   = "https://github.com/DSpace/DSpace/archive/#{targz}"
  command "wget #{url} && tar -xvzf #{targz} && rm #{targz}"
  not_if { FileTest.exists?(release_src_dir) }
end

# Switch out DSpace config file for provided template
# @todo If config files differ between versions we may need version specific templates.
template "#{release_src_dir}/dspace/config/dspace.cfg" do
  source "dspace.cfg.erb"
end

# Hard coding symbolic link because of JAVA_HOME is not defined correctly bug in Java cookbook
# @see http://tickets.opscode.com/browse/COOK-1626
link "/usr/lib/jvm/default-java" do
  to "/usr/lib/jvm/java-6-openjdk"
end

# Creating missing directories from DSpace source due to bug with 1.8.2
# @see https://wiki.duraspace.org/display/DSPACE/Development+with+Git
%w{ dspace-sword-client/dspace-sword-client-xmlui-webapp/src/main/webapp
 dspace/modules/jspui/src/main/webapp
 dspace/modules/jspui/src/main/webapp
 dspace/modules/lni/src/main/webapp
 dspace/modules/lni/src/main/webapp
 dspace/modules/oai/src/main/webapp
 dspace/modules/solr/src/main/webapp
 dspace/modules/sword/src/main/webapp
 dspace/modules/swordv2/src/main/webapp
 dspace/modules/xmlui/src/main/webapp }.each do |dir|
  directory "#{release_src_dir}/#{dir}" do
    owner node[:tomcat][:user]
    group node[:tomcat][:group]
    mode 0755
    recursive true
    action :create
  end
end


# Compile DSpace from human readable source into machine code using maven.
execute "compile #{release_name}" do
  cwd release_src_dir
  command "mvn package"
end

# Install DSpace using ant
# ant fresh_install will populate the dspace database and directory with new
#   information and overwrite any existing installations of DSpace,
# ant update will not alter the database or modify the assetstore
execute "build #{release_name}" do
  # WARNING ant fresh_install is destructive
  # @todo should we not do this if DSpace already installed?
  Chef::Log.debug("#{release_src_dir}/dspace/target/dspace-#{node[:dspace][:version]}-build")
  cwd "#{release_src_dir}/dspace/target/dspace-#{node[:dspace][:version]}-build"
  command "ant fresh_install"
end

# Fix permissions on DSpace directory
directory node[:dspace][:dir] do
  owner node[:tomcat][:user]
  group node[:tomcat][:group]
  mode 0755
  recursive true
  # @fixme recursive didn't work owner on subdirectories is root
  action :create
  notifies :restart, resources(:service => "tomcat")
end

