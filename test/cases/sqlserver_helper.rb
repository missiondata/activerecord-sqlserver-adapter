SQLSERVER_TEST_ROOT       = File.expand_path(File.join(File.dirname(__FILE__),'..'))
SQLSERVER_ASSETS_ROOT     = File.expand_path(File.join(SQLSERVER_TEST_ROOT,'assets'))
SQLSERVER_FIXTURES_ROOT   = File.expand_path(File.join(SQLSERVER_TEST_ROOT,'fixtures'))
SQLSERVER_MIGRATIONS_ROOT = File.expand_path(File.join(SQLSERVER_TEST_ROOT,'migrations'))
SQLSERVER_SCHEMA_ROOT     = File.expand_path(File.join(SQLSERVER_TEST_ROOT,'schema'))
ACTIVERECORD_TEST_ROOT    = File.expand_path(File.join(Gem.loaded_specs['activerecord'].full_gem_path,'test'))
AREL_TEST_ROOT            = File.expand_path(File.join(Gem.loaded_specs['arel'].full_gem_path,'test'))

ENV['ARCONFIG']           = File.expand_path(File.join(SQLSERVER_TEST_ROOT,'config.yml'))

$:.unshift ACTIVERECORD_TEST_ROOT
$LOAD_PATH.unshift AREL_TEST_ROOT

require 'rubygems'
require 'bundler'
Bundler.setup
require 'simplecov'
SimpleCov.start do
  add_filter "/test/"
end
require 'turn'
Turn.config do |c|
  c.format = :dot
  #c.trace = 10
  # c.natural = true
c.verbose = true
end

require 'mocha/api'
require 'active_support/dependencies'
require 'active_record'
require 'active_record/version'
require 'active_record/connection_adapters/abstract_adapter'
require 'minitest-spec-rails'
require 'minitest-spec-rails/init/mini_shoulda'
require 'cases/helper'
require 'models/topic'
GC.copy_on_write_friendly = true if GC.respond_to?(:copy_on_write_friendly?)

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.logger = Logger.new(File.expand_path(File.join(SQLSERVER_TEST_ROOT,'debug.log')))
ActiveRecord::Base.logger.level = 0


# A module that we can include in classes where we want to override an active record test.

module SqlserverCoercedTest
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods

    def self.extended(base)
      base.class_eval do
        Array(coerced_tests).each do |method_name|
          undef_method(method_name) rescue nil
          STDOUT.puts("Info: Undefined coerced test: #{self.name}##{method_name}")
        end
      end
    end
    
    def coerced_tests
      self.const_get(:COERCED_TESTS) rescue nil
    end
    
    def method_added(method)
      if coerced_tests && coerced_tests.include?(method)
        undef_method(method) rescue nil
        STDOUT.puts("Info: Undefined coerced test: #{self.name}##{method}")
      end
    end
  end
end

# #Our changes/additions to ActiveRecord test helpers specific for SQL Server.
# module ActiveRecord
#   class SQLCounter
#      sqlserver_ignored =  [%r|SELECT SCOPE_IDENTITY|, %r{INFORMATION_SCHEMA\.(TABLES|VIEWS|COLUMNS)},%r|SELECT @@version|, %r|SELECT @@TRANCOUNT|, %r{(BEGIN|COMMIT|ROLLBACK|SAVE) TRANSACTION}]
#      ignored_sql.concat sqlserver_ignored
#   end

#   puts ActiveSupport::Notifications.subscribed('sql.active_record')
#   # ActiveSupport::Notifications.unsubscribe('sql.active_record')
#   ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
# end

module ActiveRecord
  class TestCase < ActiveSupport::TestCase
    class << self
      def connection_mode_dblib? ; ActiveRecord::Base.connection.instance_variable_get(:@connection_options)[:mode] == :dblib ; end
      def connection_mode_odbc? ; ActiveRecord::Base.connection.instance_variable_get(:@connection_options)[:mode] == :odbc ; end
      def sqlserver_2005? ; ActiveRecord::Base.connection.sqlserver_2005? ; end
      def sqlserver_2008? ; ActiveRecord::Base.connection.sqlserver_2008? ; end
      def sqlserver_azure? ; ActiveRecord::Base.connection.sqlserver_azure? ; end
    end
    def connection_mode_dblib? ; self.class.connection_mode_dblib? ; end
    def connection_mode_odbc? ; self.class.connection_mode_odbc? ; end
    def sqlserver_2005? ; self.class.sqlserver_2005? ; end
    def sqlserver_2008? ; self.class.sqlserver_2008? ; end
    def sqlserver_azure? ; self.class.sqlserver_azure? ; end
    def with_enable_default_unicode_types?
      ActiveRecord::ConnectionAdapters::SQLServerAdapter.enable_default_unicode_types.is_a?(TrueClass)
    end
    def with_enable_default_unicode_types(setting)
      old_setting = ActiveRecord::ConnectionAdapters::SQLServerAdapter.enable_default_unicode_types
      old_text = ActiveRecord::ConnectionAdapters::SQLServerAdapter.native_text_database_type
      old_string = ActiveRecord::ConnectionAdapters::SQLServerAdapter.native_string_database_type
      ActiveRecord::ConnectionAdapters::SQLServerAdapter.enable_default_unicode_types = setting
      ActiveRecord::ConnectionAdapters::SQLServerAdapter.native_text_database_type = nil
      ActiveRecord::ConnectionAdapters::SQLServerAdapter.native_string_database_type = nil
      yield
    ensure
      ActiveRecord::ConnectionAdapters::SQLServerAdapter.enable_default_unicode_types = old_setting
      ActiveRecord::ConnectionAdapters::SQLServerAdapter.native_text_database_type = old_text
      ActiveRecord::ConnectionAdapters::SQLServerAdapter.native_string_database_type = old_string
    end

    def with_auto_connect(boolean)
      existing = ActiveRecord::ConnectionAdapters::SQLServerAdapter.auto_connect
      ActiveRecord::ConnectionAdapters::SQLServerAdapter.auto_connect = boolean
      yield
      ensure
        ActiveRecord::ConnectionAdapters::SQLServerAdapter.auto_connect = existing
    end
  end
end

    # Core AR.
    schema_file = "#{ACTIVERECORD_TEST_ROOT}/schema/schema.rb"
    eval(File.read(schema_file))
 
    # SQL Server.
    sqlserver_specific_schema_file = "#{SQLSERVER_SCHEMA_ROOT}/sqlserver_specific_schema.rb"
    eval(File.read(sqlserver_specific_schema_file))

