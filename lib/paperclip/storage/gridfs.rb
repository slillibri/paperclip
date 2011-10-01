module Paperclip
  module Storage
    # This is an experimental storage module for using MongoDB's GridFS as
    # storage.
    # * +gridfs+: YAML file containing mongo options
    #      development:
    #        db_name:
    #        root_collection:  default => *fs*
    module Gridfs
      def self.extended base
        begin
          require 'mongo'
          require 'bson_ext'
        rescue LoadError => e
          e.message << "(You may need to install the mongo gem)"
          raise e
        end unless defined?(Mongo)
        
        ##TODO Add validations to options configuration
        base.instance_eval do
          @db_name = @options[:db_name] || 'images'
          @fs_name = @options[:fs_name] || 'fs'

          @db = Mongo::Connection.new.db(@db_name)
          @fs = Mongo::GridFileSystem.new(@db, @fs_name)
          log("Connected to MongoDB database #{@db_name} for filesystem #{@fs_name}")
        end
      end
      
      def exists?(style = default_style)
        if original_filename
          filename = path(style)
          begin
            @fs.open("#{style}/#{filename}", "r")
          rescue Mongo::GridFileNotFound => e
            return false
          end
          true
        else
          false
        end
      end
      
      def to_file style = default_style
        return @queued_for_write[style] if @queued_for_write[style]
        begin
          filename = File.basename(path(style))
          extname = File.extname(filename)
          file = TempFile.new([filename, extname])
          file.binmode
          @fs.open("#{style}/#{filename}", "r") do |f|
            file.write f
          end
          file.rewind
          return file
        rescue Exception => e
          log("Error getting file from Mongo: #{e.message}")
          raise e
        end
      end
      
      def flush_writes        
        @queued_for_write.each do |style, file|
          begin
            log("Flushing write for #{style} -> #{file.path}")
            filename = File.basename(path(style))
            @fs.open("#{style}/#{filename}", "w") do |f|
              f.write file
            end
          rescue Exception => e
            log("Error saving #{style}:#{path(style)} -> #{e.message}")
            raise e
          end
        end
        @queued_for_write = {}
      end
      
      def flush_deletes
        @queued_for_delete.each do |path|
          begin
            log("deleting #{path}")
            @fs.delete(path)
          rescue Exception => e
            log("Error deleting #{path} -> #{e.message}")
            raise e
          end          
        end
      end
    end
  end
end
