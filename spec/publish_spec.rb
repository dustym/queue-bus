require 'spec_helper'

describe "Publishing an event" do

  before(:each) do
    Timecop.freeze
    QueueBus.stub(:generate_uuid).and_return("idfhlkj")
  end
  after(:each) do
    Timecop.return
  end
  let(:bus_attrs) { {"bus_class_proxy"=>"QueueBus::Driver",
                     "bus_published_at" => Time.now.to_i,
                     "bus_id"=>"#{Time.now.to_i}-idfhlkj",
                     "bus_app_hostname" =>  `hostname 2>&1`.strip.sub(/.local/,'')} }

  it "should add it to Redis" do
    hash = {:one => 1, "two" => "here", "id" => 12 }
    event_name = "event_name"

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    val.should == nil

    QueueBus.publish(event_name, hash)

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    hash = JSON.parse(val)
    hash["class"].should == "QueueBus::Worker"
    hash["args"].size.should == 1
    JSON.parse(hash["args"].first).should == {"bus_event_type" => event_name, "two"=>"here", "one"=>1, "id" => 12}.merge(bus_attrs)

  end

  it "should use the id if given" do
    hash = {:one => 1, "two" => "here", "bus_id" => "app-given" }
    event_name = "event_name"

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    val.should == nil

    QueueBus.publish(event_name, hash)

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    hash = JSON.parse(val)
    hash["class"].should == "QueueBus::Worker"
    hash["args"].size.should == 1
    JSON.parse(hash["args"].first).should == {"bus_event_type" => event_name, "two"=>"here", "one"=>1}.merge(bus_attrs).merge("bus_id" => 'app-given')
  end

  it "should add metadata via callback" do
    myval = 0
    QueueBus.before_publish = lambda { |att|
      att["mine"] = 4
      myval += 1
    }

    hash = {:one => 1, "two" => "here", "bus_id" => "app-given" }
    event_name = "event_name"

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    val.should == nil

    QueueBus.publish(event_name, hash)


    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    hash = JSON.parse(val)
    att = JSON.parse(hash["args"].first)
    att["mine"].should == 4
    myval.should == 1
  end

  it "should set the timezone and locale if available" do
    defined?(I18n).should be_nil
    Time.respond_to?(:zone).should eq(false)

    stub_const("I18n", Class.new)
    I18n.stub(:locale).and_return("jp")

    Time.stub(:zone).and_return(double('zone', :name => "EST"))

    hash = {:one => 1, "two" => "here", "bus_id" => "app-given" }
    event_name = "event_name"

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    val.should == nil

    QueueBus.publish(event_name, hash)

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    hash = JSON.parse(val)
    hash["class"].should == "QueueBus::Worker"
    att = JSON.parse(hash["args"].first)
    att["bus_locale"].should == "jp"
    att["bus_timezone"].should == "EST"
  end

end
