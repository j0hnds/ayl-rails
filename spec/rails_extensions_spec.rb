require 'spec_helper'

module ClassMethod; end

class ClassMethod::MyModel < ActiveRecord::Base

  def self.the_async_method(arg1, arg2)
    WhatHappened.instance << "the static async method(#{arg1}, #{arg2})"
  end

end


module InstanceMethod; end

class InstanceMethod::MyModel < ActiveRecord::Base

  def the_async_method(arg1, arg2)
    WhatHappened.instance << "the instance async method(#{arg1}, #{arg2})"
  end

end

module AfterSave; end

# Setup the class to deal with a before_save callback
class AfterSave::MyModel < ActiveRecord::Base
  ayl_after_save :handle_after_save

  private

  def handle_after_save
    WhatHappened.instance << "handle after save"
  end
end

module AfterUpdate; end

# Setup the class to deal with a before_save callback
class AfterUpdate::MyModel < ActiveRecord::Base
  ayl_after_update :handle_after_update

  private

  def handle_after_update
    WhatHappened.instance << "handle after update"
  end
end

module AfterCreate; end

# Setup the class to deal with a before_save callback
class AfterCreate::MyModel < ActiveRecord::Base
  ayl_after_create :handle_after_create

  private

  def handle_after_create
    WhatHappened.instance << "handle after create"
  end
end

module MessageOptions; end

class MessageOptions::MyModel < ActiveRecord::Base

  ayl_after_create :handle_after_create, :message_options => { :delay => 20 }
  ayl_after_update :handle_after_update

end

module ConditionalCallbacks; end

class ConditionalCallbacks::MyModel < ActiveRecord::Base
  attr_accessor :do_callback

  ayl_after_create :handle_after_create, :if => :should_do_callback?

  ayl_after_update :handle_after_update, :unless => :should_do_callback?

  private

  def handle_after_create
    WhatHappened.instance << "handle after create"
  end

  def handle_after_update
    WhatHappened.instance << "handle after update"
  end

  def should_do_callback?
    @do_callback
  end
end

describe "Rails Extensions" do

  before(:each) do
    # Set up a null logger
    Ayl::Logger.instance.logger = Ayl::NullLogger.new

    # Set up an in-memory database so that we can quickly do ActiveRecord
    # tests.
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3',
                                            :database => ":memory:")

    ActiveRecord::Schema.define do
      create_table :my_models do |t|
        t.column :name, :string
      end
    end

  end

  after(:each) do
    WhatHappened.instance.clear
  end

  context "when handling lifecycle callbacks" do
    it "the ayl_after_save handler should fire when the model is saved" do
      
      model = AfterSave::MyModel.new(:name => 'spud')
      model.save.should be_true

      WhatHappened.instance.what_ran.should == [ 'handle after save' ] 
      WhatHappened.instance.clear

      model.update_attribute(:name, 'joan')

      WhatHappened.instance.what_ran.should == [ 'handle after save' ] 
    end

    it "the ayl_after_update handler should fire when the model is updated" do
      
      model = AfterUpdate::MyModel.new(:name => 'spud')
      model.save.should be_true

      WhatHappened.instance.what_ran.should be_nil

      model.update_attribute(:name, 'joan')

      WhatHappened.instance.what_ran.should == [ 'handle after update' ]
    end

    it "the ayl_after_create handler should fire when the model is created" do
      
      model = AfterCreate::MyModel.new(:name => 'spud')
      model.save.should be_true

      WhatHappened.instance.what_ran.should == [ 'handle after create' ]
      WhatHappened.instance.clear

      model.update_attribute(:name, 'joan')

      WhatHappened.instance.what_ran.should be_nil
    end

  end

  context "when using the instance extensions" do

    it "should represent the instance of a particular model using a 'find'" do
      model = InstanceMethod::MyModel.create(:name => 'loud')

      model.to_rrepr.should == "InstanceMethod::MyModel.unscoped.find(#{model.id})"
    end

    it "should invoke the instance method asynchronously with no options" do
      model = InstanceMethod::MyModel.create(:name => 'loud')

      model.ayl_send(:the_async_method, "first", "second")
      
      WhatHappened.instance.what_ran.should == [ "the instance async method(first, second)" ]
    end

    it "should invoke the instance method asynchronously with options" do
      model = InstanceMethod::MyModel.create(:name => 'loud')

      model.ayl_send_opts(:the_async_method, {}, "first", "second")
      
      WhatHappened.instance.what_ran.should == [ "the instance async method(first, second)" ]
    end

  end

  context "when using the class extensions" do

    it "should invoke the static method asynchronously with no options" do
      ClassMethod::MyModel.ayl_send(:the_async_method, "first", "second")
      
      WhatHappened.instance.what_ran.should == [ "the static async method(first, second)" ]
    end

    it "should invoke the instance method asynchronously with options" do
      ClassMethod::MyModel.ayl_send_opts(:the_async_method, {}, "first", "second")
      
      WhatHappened.instance.what_ran.should == [ "the static async method(first, second)" ]
    end

  end

  context "when using conditional callbacks" do

    it "should invoke the after_create but not the after_update callbacks when the flag is true" do
      model = ConditionalCallbacks::MyModel.new(:name => "spud")
      model.do_callback = true # Should allow after_create to be called, but not after_update
      model.save
      model.update_attribute(:name, "dog")
      WhatHappened.instance.what_ran.should == [ "handle after create" ]
    end

    it "should invoke the after_update but not the after_create callbacks when the flag is false" do
      model = ConditionalCallbacks::MyModel.new(:name => "spud")
      model.do_callback = false # Should allow after_update to be called, but not after_create
      model.save
      model.update_attribute(:name, "dog")
      WhatHappened.instance.what_ran.should == [ "handle after update" ]
    end
  end

  context "when using message parameters" do

    it "should pass the message options to the ayl_after_create, but not to the ayl_after_update" do
      model = MessageOptions::MyModel.new(:name => "spud")
      MessageOptions::MyModel.should_receive(:ayl_send_opts).with(:_ayl_after_create, { :delay => 20 }, model)
      MessageOptions::MyModel.should_receive(:ayl_send_opts).with(:_ayl_after_update, { }, model)

      model.save
      model.update_attribute(:name, "dog")
    end

  end

end
