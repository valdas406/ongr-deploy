module OngrDeploy

  def setup
    set :stage_config_path,  "app/deploy"
    set :deploy_config_path, "app/deploy.rb"

    require "capistrano/setup"

    stages.each do |stage|
      Rake::Task[stage].clear_actions

      Rake::Task.define_task( stage ) do
        invoke "load:defaults"

        load deploy_config_path
        load stage_config_path.join "#{stage}.rb"

        load File.expand_path( "../ongr_deploy/scm/#{fetch( :scm )}.rb", __FILE__ )

        I18n.locale = fetch :locale, :en

        configure_backend
      end
    end
  end

end

self.extend OngrDeploy

setup
