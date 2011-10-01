require './test/helper'
require 'mongo'

class GridFSTest < Test::Unit::TestCase
  context "GridFS" do
    setup do
      rebuild_model :db_name => 'test', :root_collection => 'fs'
      @dummy = Dummy.new
      @dummy.avatar = File.open(File.join(File.dirname(__FILE__), "fixtures", "5k.png"))
    end
    
    should "save a file" do
      @dummy.save
    end
  end
end