require "rake"

module OngrDeploy

  class Application < Rake::Application

    def initialize
      super
      @rakefiles = [File.expand_path( "../../tasks/ongr_bin.rake", __FILE__ )]
    end

    def run
      Rake.application = self
      super
    end

  end

end
