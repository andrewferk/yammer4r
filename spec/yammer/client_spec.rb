require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'ostruct'

describe Yammer::Client do

  context "initialize" do

    describe 'proxy' do

      it "should allow setting of proxy" do
        OAuth::Consumer.should_receive('new').with(nil, nil, {:proxy=>"http://www.example_proxy.com:8484", :site=>"https://www.yammer.com"})
        @client = Yammer::Client.new(:consumer => {}, :access => {}, :proxy => 'http://www.example_proxy.com:8484')
      end

      it 'should load without any proxy set' do
        OAuth::Consumer.should_receive('new').with(nil, nil, {:site=>"https://www.yammer.com"})
        @client = Yammer::Client.new(:consumer => {}, :access => {})
      end

    end

    it "should allow setting of consumer and access via config" do
      OAuth::Consumer.should_receive('new').with("SOME_CLIENT_KEY", "A_NOT_SO_SECRET_SECRET", {:site=>"https://www.yammer.com"})
      @client = Yammer::Client.new(:config => File.expand_path(File.dirname(__FILE__) + '/../fixtures/oauth_test.yml'))
    end

    it "should allow setting of yammer url" do
      OAuth::Consumer.should_receive('new').with(nil, nil, {:site=>"http://www.some_custom_yammer_host.com"})
      @client = Yammer::Client.new(:consumer => {}, :access => {}, :yammer_host => 'http://www.some_custom_yammer_host.com')
    end


  end


  context "creating" do

    before(:each) do
      mock_consumer = mock(OAuth::Consumer)
      OAuth::Consumer.stub!("new").and_return(mock_consumer)
      @mock_http = mock("http")
      mock_consumer.stub!("http").and_return(@mock_http)
    end

    it "can be configured to be verbose" do
      @mock_http.should_receive("set_debug_output").with($stderr)
      Yammer::Client.new(:consumer => {}, :access => {}, :verbose => true)
    end

    it "should not be configured to be verbose unless asked to be" do
      @mock_http.should_not_receive("set_debug_output")
      Yammer::Client.new(:consumer => {}, :access => {})
    end

    it "should not be configured to be verbose if asked not to be" do
      @mock_http.should_not_receive("set_debug_output")
      Yammer::Client.new(:consumer => {}, :access => {}, :verbose => false)
    end

  end

  context "users" do

    before(:each) do
      @mock_access_token = mock(OAuth::AccessToken)
      @response = OpenStruct.new(:code => 200, :body => '{}')
      OAuth::AccessToken.stub!("new").and_return(@mock_access_token)
      @client = Yammer::Client.new(:consumer => {}, :access => {})
    end

    it "should request the first page by default" do
      @mock_access_token.should_receive("get").with("/api/v1/users.json").and_return(@response)
      @client.users
    end

    it "can request a specified page" do
      @mock_access_token.should_receive("get").with("/api/v1/users.json?page=2").and_return(@response)
      @client.users(:page => 2)
    end

  end

  # 'messages'
   # 'messages/sent'
   # 'messages/received'
   # 'messages/following'
   # 'messages/from_user/id'
   # 'messages/from_bot/id'
   # 'messages/tagged_with/id'
   # 'messages/in_group/id'
   # 'messages/favorites_of/id'
   # 'messages/in_thread/id'

  context "messages" do

    before(:each) do
      @mock_access_token = mock(OAuth::AccessToken)
      @response = OpenStruct.new(:code => 200, :body => "{}")
      JSON.stub!(:parse).and_return({'meta' => {'older_available' => 'no'}, 'messages' => [{}]})
      OAuth::AccessToken.stub!("new").and_return(@mock_access_token)
      @additional_params = {}
      @client = Yammer::Client.new(:consumer => {}, :access => {})
    end

    it "should request all messages by default" do
      @mock_access_token.should_receive("get").with("/api/v1/messages.json").and_return(@response)
    end

    ['messages', 'messages/sent', 'messages/received', 'messages/following'].each do |without_id_endpoint|
      it "should load non-id specific API endpoints such as '#{without_id_endpoint}' when specified" do
        @additional_params = {:resource => without_id_endpoint}
        @mock_access_token.should_receive("get").with("/api/v1/#{without_id_endpoint}.json").and_return(@response)
      end
    end

    ['messages/from_user/123', 'messages/from_bot/843', 'messages/tagged_with/273', 'messages/in_group/923', 'messages/favorites_of/383', 'messages/in_thread/102'].each do |with_id_endpoint|
      it "should load id specific API endpoints such as '#{with_id_endpoint}' when specified" do
        @additional_params = {:resource => with_id_endpoint}
        @mock_access_token.should_receive("get").with("/api/v1/#{with_id_endpoint}.json").and_return(@response)
      end
    end

    ['/messages', '/messages/sent', '/messages/received'].each do |with_forward_slash_endpoint|
      it "should strip any forward slash prefix such as '#{with_forward_slash_endpoint}' when specified" do
        @additional_params = {:resource => with_forward_slash_endpoint}
        @mock_access_token.should_receive("get").with("/api/v1/#{with_forward_slash_endpoint}.json".gsub(/\/\//,'/')).and_return(@response)
      end
    end

    after(:each) do
      @client.messages(:all, @additional_params)
    end


  end

end