module Yammer
  class Client

    def initialize(options={})
      options.assert_has_keys(:consumer, :access) unless options.has_key?(:config)

      yammer_url = options.delete(:yammer_host) || "https://www.yammer.com"
      proxy      = options.delete(:proxy)

      @api_path   = "/api/v1/"

      if options[:config]
        config              = YAML.load(open(options[:config]))
        options[:consumer]  = config['consumer'].symbolize_keys
        options[:access]    = config['access'].symbolize_keys
      end

      consumer_attributes = {:site => yammer_url}
      consumer_attributes.update(:proxy => proxy) if proxy

      consumer = OAuth::Consumer.new(options[:consumer][:key], options[:consumer][:secret], consumer_attributes)
      consumer.http.set_debug_output($stderr) if options[:verbose] == true
      @access_token = OAuth::AccessToken.new(consumer, options[:access][:token], options[:access][:secret])
    end

    # TODO: modularize message and user handling
    def messages(action = :all, params = {})
      #Default optional parameters
      # => older_than, newer_than, threaded

      params.symbolize_keys!
      #Resource for messages defined
      #Available options at time of writing:
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
      resource = params.keys.include?(:resource) ? params[:resource].to_s.gsub(/^\//,'') : :messages

      params.update(:resource => resource)
      params.merge!(:action => action) unless action == :all

      parsed_response = JSON.parse(yammer_request(:get, params).body)
      older_available = parsed_response['meta']['older_available']

      ml = parsed_response['messages'].map do |m|
         mash(m)
      end
        Yammer::MessageList.new(ml, older_available, self)
    end

    # POST or DELETE a message
    def message(action, params)
      params.merge!(:resource => :messages)
      yammer_request(action, params)
    end

    def users(params = {})
      params.merge!(:resource => :users)
      JSON.parse(yammer_request(:get, params).body).map { |u| Yammer::User.new(mash(u), self) }
    end

    def user(id)
      u = JSON.parse(yammer_request(:get, {:resource => :users, :id => id}).body)
      Yammer::User.new(mash(u), self)
    end

    def current_user
      u = JSON.parse(yammer_request(:get, {:resource => :users, :action => :current}).body)
      Yammer::User.new(mash(u), self)
    end
    alias_method :me, :current_user

    private

    def yammer_request(http_method, options)
      request_uri = @api_path + options.delete(:resource).to_s
      [:action, :id].each {|k| request_uri += "/#{options.delete(k)}" if options.has_key?(k) }
      request_uri += ".json"

      if options.any?
        request_uri += "?#{create_query_string(options)}" unless http_method == :post
      end

      if http_method == :post
        handle_response(@access_token.send(http_method, request_uri, options))
      else
        handle_response(@access_token.send(http_method, request_uri))
      end
    end

    def create_query_string(options)
      options.map {|k, v| "#{OAuth::Helper.escape(k)}=#{OAuth::Helper.escape(v)}"}.join('&')
    end

    def mash(json)
      Mash.new(json)
    end

    def handle_response(response)
      # TODO: Write classes for exceptions
      case response.code.to_i
        when 200..201
          response
        when 400
          raise "400 Bad request"
        when 401
          raise  "Authentication failed. Check your username and password"
        when 503
          raise "503: Service Unavailable"
        else
          raise "Error. HTTP Response #{response.code}"
        end
    end

  end
end
