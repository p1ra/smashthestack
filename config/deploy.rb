require 'bundler/capistrano'
require 'json'
require 'erb'

set :bundle_dir, ''

stages = %w{demo staging production}
set :environment, stages.include?(ARGV[0]) ? ARGV[0] : 'staging'
set :rails_env, stages.include?(ARGV[0]) ? ARGV[0] : 'staging'

set :user, "root"
set :use_sudo, false

set :scm, :git
set :repository, "git@github.com:kingdomsite/wallstreet.git"
set :branch, "master"
set :application, "wallstreet"
set :domain, 'transcribr.com'
set :deploy_to, "/var/apps/#{domain}/#{environment}"
set :cron_file, "#{release_path}/config/cronjobs"
set :cron_entry, "* * * * * #{release_path}/app/models/watcher.rb > /dev/null 2>&1"

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, roles: :app, except: { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
  task :nginx do
    template = ERB.new(File.read('config/wallstreet.conf.erb'), nil, '<>').result(binding)
    put(template, "/etc/nginx/sites.d/#{environment}.#{domain}.conf")
    run "service nginx restart"
  end
  task :logrotate do
    template = ERB.new(File.read('config/logrotate.erb'), nil, '<>').result(binding)
    put(template, "/etc/logrotate.d/#{domain}")
  end
  task :add_cronjob do
    run "touch #{cron_file}"
    run "echo '#{cron_entry}' > #{cron_file}"
    run "crontab -u root #{cron_file}"
  end	
  task :elasticsearch_config do
    run "cp #{release_path}/config/elasticsearch_production.yml /etc/elasticsearch/elasticsearch.yml"
  end
  after "deploy:setup","deploy"
  after "deploy:setup","deploy:logrotate"
  after "deploy:setup", "deploy:nginx"
  after "deploy:restart", "deploy:cleanup"
  after "deploy:restart", "deploy:add_cronjob"
end

def get_servers(environment, location="*", role='app')
  query = "name:#{role}*.#{location}.#{environment}.#{domain} AND chef_environment:#{environment}"
  result = `bash -c -l 'knife search -a name node "#{query}" -Fj'`
  JSON.parse(result)['rows'].map { |row| row['id'] }
end

task(environment) { [:web, :app].each { |r| role r, *get_servers(environment) } }
