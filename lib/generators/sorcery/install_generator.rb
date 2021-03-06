require 'rails/generators/migration'

module Sorcery
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      
      source_root File.expand_path('../templates', __FILE__)
      
      argument :submodules, :optional => true, :type => :array, :banner => "submodules"
      
      class_option :model, :optional => true, :type => :string, :banner => "model",
                   :desc => "Specify the model class name if you will use anything other than 'User'"
                           
      class_option :migrations, :optional => true, :type => :boolean, :banner => "migrations",
                   :desc => "Specify if you want to add submodules to an existing model\n\t\t\t     # (will generate migrations files, and add submodules to config file)"
      
      
      # Copy the initializer file to config/initializers folder.
      def copy_initializer_file
        template "initializer.rb", "config/initializers/sorcery.rb" unless options[:migrations]
      end

      def configure_initializer_file
        # Add submodules to the initializer file.
        if submodules
          submodule_names = submodules.collect{ |submodule| ':' + submodule }

          gsub_file "config/initializers/sorcery.rb", /submodules = \[.*\]/ do |str|
            current_submodule_names = (str =~ /\[(.*)\]/ ? $1 : '').delete(' ').split(',')
            "submodules = [#{(current_submodule_names | submodule_names).join(', ')}]"
          end
        end

        # Generate the model and add 'authenticates_with_sorcery!' unless you passed --migrations
        unless options[:migrations]
          generate "model #{model_class_name} --skip-migration"
          insert_into_file "app/models/#{model_class_name.underscore}.rb", "  authenticates_with_sorcery!\n", :after => "class #{model_class_name} < ActiveRecord::Base\n"
        end

        if submodules && submodules.include?("access_token")
          generate_access_token_model
        end

      end

      # Copy the migrations files to db/migrate folder
      def copy_migration_files
        # Copy core migration file in all cases except when you pass --migrations.
        return unless defined?(Sorcery::Generators::InstallGenerator::ActiveRecord)
        migration_template "migration/core.rb", "db/migrate/sorcery_core.rb" unless options[:migrations]

        if submodules
          submodules.each do |submodule|
            unless submodule == "http_basic_auth" || submodule == "session_timeout" || submodule == "core"
              migration_template "migration/#{submodule}.rb", "db/migrate/sorcery_#{submodule}.rb"
            end
          end
        end
        

      end
      
      # Define the next_migration_number method (necessary for the migration_template method to work)
      def self.next_migration_number(dirname)
        if ActiveRecord::Base.timestamped_migrations
          sleep 1 # make sure each time we get a different timestamp
          Time.new.utc.strftime("%Y%m%d%H%M%S")
        else
          "%.3d" % (current_migration_number(dirname) + 1)
        end
      end
      
      private

      # Either return the model passed in a classified form or return the default "User".
      def model_class_name
        options[:model] ? options[:model].classify : "User"
      end

      def generate_access_token_model
        access_token_class_name = 'AccessToken'
        access_token_model_file = "app/models/#{access_token_class_name.underscore}.rb"
        template "models/access_token.rb", access_token_model_file

        insert_into_file("app/models/#{model_class_name.underscore}.rb",
                         "\n  has_many :access_tokens, :dependent => :delete_all\n",
                         :after => "  authenticates_with_sorcery!")
      end
    end
  end
end
