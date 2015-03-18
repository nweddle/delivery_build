[
  'root',
  'bin',
  'lib',
  'etc',
  'dot_chef'
].each do |dir|
  directory node['delivery_build'][dir] do
    owner "root"
    mode "0755"
    recursive true
  end
end

# The SSH wrapper for Git
template File.join(node['delivery_build']['bin'], 'git_ssh') do
  source 'git_ssh.erb'
  owner 'root'
  mode '0755'
end

# The SSH Known Hosts File
file node['delivery_build']['ssh_known_hosts_file'] do
  owner 'dbuild'
  mode '0644'
end

# Executes a job from pushy
template File.join(node['delivery_build']['bin'], 'delivery-cmd') do
  source 'delivery-cmd.erb'
  owner 'root'
  mode '0755'
end

# a bunch of keys we need for the build
# this is inside the 'if change' block mainly
# because otherwise that would fail on the very-first
# TK-driven run in the dev setup
{'builder_key'  => 'builder_key',
 'delivery_pem' => 'delivery.pem'}.each do |key_name, file_name|
  data_bag_coords = node['delivery_build']['builder_keys'][key_name]
  data_bag_content = DeliveryHelper.encrypted_data_bag_item(data_bag_coords['bag'],
                                             data_bag_coords['item'])
  # TODO: the 'builder_key' should clearly be dependent on the enterprise
  # and so stored at an ent-level workspace dir
  file ::File.join(node['delivery_build']['etc'], file_name) do
    # FIXME: here, for 'delivery_pem', we effectively allow just about
    # any committer (in the delivery sense) to do whatever she wants
    # on the CS server. No need to emphasize how bad that is.
    owner node['delivery_build']['build_user']
    group 'root'
    mode '0600'
    content data_bag_content[data_bag_coords['key']]
  end

  file ::File.join(node['delivery_build']['dot_chef'], file_name) do
    # FIXME: here, for 'delivery_pem', we effectively allow just about
    # any committer (in the delivery sense) to do whatever she wants
    # on the CS server. No need to emphasize how bad that is.
    owner node['delivery_build']['build_user']
    group 'root'
    mode '0600'
    content data_bag_content[data_bag_coords['key']]
  end
end

# the knife file to talk to CS as delivery
delivery_config = ::File.join(node['delivery_build']['etc'], 'delivery.rb')
template delivery_config do
  source "delivery.rb.erb"
  owner node['delivery_build']['build_user']
  group 'root'
  mode '0644'
end

# This is used by the delivery CLI-based build node workflow
knife_config = ::File.join(node['delivery_build']['dot_chef'], 'knife.rb')
template knife_config do
  source "delivery.rb.erb"
  owner node['delivery_build']['build_user']
  mode '0644'
end

# Fetch the SSL certificate for the CS if necessary
execute "fetch_ssl_certificate" do
  command "knife ssl fetch -c #{delivery_config}"
  not_if "knife ssl check -c #{delivery_config}"
end

if node['delivery_build']['api']
  # Fetch the SSL certificate for the Delivery Server
  execute "fetch_delivery_ssl_certificate" do
    command "knife ssl fetch -c #{delivery_config} #{node['delivery_build']['api']}"
    not_if "knife ssl check -c #{delivery_config} #{node['delivery_build']['api']}"
    only_if { node['delivery_build']['api'] =~ /^https/ ? true : false }
  end
end