require "rails/railtie"
require "trailblazer/loader"

module Trailblazer
  class Railtie < ::Rails::Railtie
    def self.load_concepts(app)
      engines = ::Rails::Engine.subclasses.map(&:instance)
      engines.each do |engine|
        Dir.chdir(engine.root) do # Loader has no concept for base dir, must chdir so that it can find files
          Loader.new.({debug: false, insert: [ModelFile, before: Loader::AddConceptFiles]}) { |file|
            root = engine.root.to_s.include?('dummy') ? engine.root.to_s.gsub('spec/dummy', '') : engine.root
            require_dependency("#{root}/#{file}")
          }
        end
      end

      Dir.chdir(app.root) do  # necessary to guarantee context for tests
        Loader.new.({debug: false, insert: [ModelFile, before: Loader::AddConceptFiles]}) { |file|
          require_dependency("#{app.root}/#{file}")
        }
      end
    end

    # This is to autoload Operation::Dispatch, etc. I'm simply assuming people find this helpful in Rails.
    initializer "trailblazer.library_autoloading" do
      require "trailblazer/autoloading"
    end

    # thank you, http://stackoverflow.com/a/17573888/465070
    initializer 'trailblazer.install', after: :load_config_initializers do |app|
      # the trb autoloading has to be run after initializers have been loaded, so we can tweak inclusion of features in
      # initializers.
      reloader_class.to_prepare do
        Trailblazer::Railtie.load_concepts(app)
      end
    end

    # initializer "trailblazer.roar" do
    #   require "trailblazer/rails/roar" #if Object.const_defined?(:Roar)
    # end

    initializer "trailblazer.application_controller" do
      ActiveSupport.on_load(:action_controller) do
        include Trailblazer::Operation::Controller
      end
    end

    # Prepend model file, before the concept files like operation.rb get loaded.
    ModelFile = ->(input, options) do
      model = "app/models/#{options[:name]}.rb"
      File.exist?(model) ? [model]+input : input
    end

    private

    def reloader_class
      # Rails 5.0.0.rc1 says:
      # DEPRECATION WARNING: to_prepare is deprecated and will be removed from Rails 5.1
      # (use ActiveSupport::Reloader.to_prepare instead)
      if ActiveSupport.version.release >= Gem::Version.new('5')
        ActiveSupport::Reloader
      else
        ActionDispatch::Reloader
      end
    end
  end
end
