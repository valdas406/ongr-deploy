module OngrDeploy

  module Core

    def ongr_setup
      set :stage_config_path,  "app/deploy"
      set :deploy_config_path, "app/deploy.rb"

      require "capistrano/setup"

      stages.each do |stage|
        Rake::Task[stage].clear_actions

        Rake::Task.define_task( stage ) do
          invoke "load:defaults"

          load deploy_config_path
          load stage_config_path.join "#{stage}.rb"

          begin
            load File.expand_path( "../scm/#{fetch( :scm )}.rb", __FILE__ )
          rescue LoadError
            load "capistrano/#{fetch( :scm )}.rb"
          end

          I18n.locale = fetch :locale, :en

          configure_backend
        end
      end
    end

  end

end
