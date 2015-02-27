#
# Cookbook Name:: delivery_build
# Spec:: workspace
#
# Copyright 2015 Chef Software, Inc.
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

require 'spec_helper'

describe 'delivery_build::workspace' do
  context "by default" do
    before do
      default_mocks
    end

    cached(:chef_run) do
      runner = ChefSpec::SoloRunner.new
      runner.converge("delivery_build::workspace")
    end

    it 'converges successfully' do
      chef_run
    end

    ['/var/opt/delivery/workspace',
     '/var/opt/delivery/workspace/bin',
     '/var/opt/delivery/workspace/lib',
     '/var/opt/delivery/workspace/etc',
     '/var/opt/delivery/workspace/.chef'
    ].each do |dir|
      it "should create #{dir}" do
        expect(chef_run).to create_directory(dir).with(
          owner: 'root',
          mode: '0755',
          recursive: true
        )
      end
    end

    it "writes the ssh wrapper" do
      filename = '/var/opt/delivery/workspace/bin/git_ssh'
      expect(chef_run).to create_template(filename).with(
        owner: 'root',
        mode: '0755',
      )
      [
       Regexp.new("-o UserKnownHostsFile=/var/opt/delivery/workspace/etc/delivery-git-ssh-known-hosts"),
       Regexp.new("-o IdentityFile=/var/opt/delivery/workspace/etc/builder_key"),
       Regexp.new("-l builder")
      ].each do |check|
        expect(chef_run).to render_file(filename).with_content(check)
      end
    end

    it "creates the known hosts file" do
      expect(chef_run).to create_file('/var/opt/delivery/workspace/etc/delivery-git-ssh-known-hosts')
    end

    it "creates the delivery-cmd" do
      filename = '/var/opt/delivery/workspace/bin/delivery-cmd'
      expect(chef_run).to create_template(filename).with(
        owner: 'root',
        mode: '0755'
      )
      expect(chef_run).to render_file(filename).with_content(
        /class Streamy/
      )
    end

    it "creates the builder ssh key" do
      ["/var/opt/delivery/workspace/etc/builder_key",
       "/var/opt/delivery/workspace/.chef/builder_key"
      ].each do |filename|
        expect(chef_run).to create_file(filename).with(
          owner: 'dbuild',
          mode: '0600'
        )
        # This means you got it from the data bag
        expect(chef_run).to render_file(filename).with_content(
          'rocks_is_aerosmiths_best_album'
        )
      end
    end

    it "creates the delivery.pem for the chef server" do
      ["/var/opt/delivery/workspace/etc/delivery.pem",
       "/var/opt/delivery/workspace/.chef/delivery.pem"
      ].each do |filename|
        expect(chef_run).to create_file(filename).with(
          owner: 'dbuild',
          mode: '0600'
        )
        # This means you got it from the data bag
        expect(chef_run).to render_file(filename).with_content(
          'toys_in_the_attic_is_aerosmiths_best_album'
        )
      end
    end

    it "creates the knife.rb" do
      filename = "/var/opt/delivery/workspace/.chef/knife.rb"
      expect(chef_run).to create_template(filename).with(
        owner: 'dbuild',
        mode: '0644'
      )
      [
        Regexp.new('node_name\s+"delivery"'),
        Regexp.new('client_key\s+"#{current_dir}/delivery.pem"'),
        Regexp.new('trusted_certs_dir\s+"/etc/chef/trusted_certs"')
      ].each do |check|
        expect(chef_run).to render_file(filename).with_content(check)
      end
    end

    it "fetches the delivery chef server ssl key" do
      expect(chef_run).to run_execute("fetch_ssl_certificate").with(
        command: "knife ssl fetch -c /var/opt/delivery/workspace/etc/delivery.rb"
      )
    end

    it "fetches the ssl certificate of the delivery server" do
      expect(chef_run).to run_execute("fetch_delivery_ssl_certificate").with(
        command: "knife ssl fetch -c /var/opt/delivery/workspace/etc/delivery.rb https://192.168.33.1"
      )
    end
  end
end
