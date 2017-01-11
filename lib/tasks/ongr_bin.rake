require "pathname"

task :default do
  puts "Use ongr install to setup capistrano"
end

task :install do
  config_dir = Pathname.new "app"

  deploy_dir = config_dir.join "deploy"
  tasks_dir  = config_dir.join "tasks"

  deploy_rb = File.expand_path "../../templates/deploy.rb", __FILE__
  stage_rb  = File.expand_path "../../templates/stage.rb", __FILE__
  capfile   = File.expand_path "../../templates/Capfile", __FILE__

  mkdir_p deploy_dir
  mkdir_p tasks_dir

  FileUtils.cp deploy_rb, config_dir
  FileUtils.cp stage_rb, deploy_dir
  FileUtils.cp capfile, "Capfile"
end
