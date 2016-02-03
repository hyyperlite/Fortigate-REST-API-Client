require 'rest-client'
require 'json'

class FgtApi
  attr_reader :connected

  def initialize(host, username, secretkey, debug=1)
    @hosturl = 'http://' + host.sub(/^https?\:\/\//,'')
    @apiurl = @hosturl + '/api/v2'
    @username = username
    @secretkey = secretkey
    @debug = debug
    @loginuri = '/logincheck'
    @logouturi = '/logout'
    @connected = false
    @cookies = nil
    @headers = nil

    ## Destroy... will finish this later to ensure the connection is logged out from upon instance destruction
    #ObjectSpace.define_finalizer( self, logout)

    ## Initiate Login to FortiGate and get cookies for subsequent queries
    @loginurl = @hosturl + @loginuri

    unless @debug == 0
      p "Attempting authentiation to: #{@loginurl} as #{@username}"
    end

    begin
      res = RestClient.post @loginurl, {:username => @username,:secretkey => @secretkey}
    rescue Exception => e
      fgt_rescue(e)
      return e
    end

    if res.cookies['ccsrftoken']
      @connected = true
      p "Authentication successful"
    else
      p "Error: Authentication failed"

    end
    res_debug(res) unless @debug == 0
    update_req(res.cookies)
  end

  ##############################################################################
  # logout()
  #
  # Logout of current FortiGate API session
  #############################################################################
  def logout
    p "Logging out" unless @debug == 0
    res = RestClient.post @hosturl + '/logout', nil, @headers
  end

  #############################################################################
  # exec (api, path, name, action, mkey, parameters, data)
  #
  # Execute get for specified API call, parameters, data, etc
  #############################################################################
  def exec(type, api, path, name, action=nil, mkey=nil, parameters=nil, payload=nil)
    url = get_url(api, path, name, action, mkey)

    @headers[:params] = parameters

    case type
      when 'get', :get
        reqtype = :get
      when 'post', :post
        reqtype = :post
      when 'put', :put
        reqtype = :put
      when 'delete', :delete
        reqtype = :delete
      else
        #raise ArgumentError("invalid argument 'type'.")
        #fgt_rescue ("")
        p "ArgumentError: Invalid argument 'type'"
        return e
    end

    req_debug(url, @cookies, parameters, payload) unless @debug == 0

    res = RestClient::Request.execute(
        :method => reqtype,
        :url => url,
        :payload => payload.to_json,
        :headers => @headers,
        :cookies => @cookies,
        :content_type => :json
    )

    #res_debug(res) unless @debug == 0

    #update_req(res.cookies)
    return JSON.parse(res.body)
  end



  ########################################################
  # Methods from this point forward are private methods
  ########################################################
  private
  ########################################################

  def update_req(rescookies)
    begin
      if rescookies['ccsrftoken'] && rescookies['APSCOOKIE_9539865664983730253']
        @cookies = rescookies
        @headers = {:'X-CSRFTOKEN' => @cookies['ccsrftoken']}
      else
        p "cookies['ccsrftoken']:  #{rescookies['ccsrftoken']}"
        p "cookies['APSCOOKIE']:  #{rescookies['APSCOOKIE_9539865664983730253']}"
        raise RuntimeError.new('Response did not include the required cookies "APSCOOKIE" and/or "ccsrftoken"')
      end
    rescue Exception => e
      fgt_rescue(e)
      return e
    end
  end

  def get_url(api, path, name, action, mkey)
    begin
      if %w(monitor cmdb).include? api
        url = @apiurl + '/' + api + '/' + path + '/' + name
        url << '/' << action if action
        url << '/' << mkey if mkey
        return url
      else
        raise ArgumentError.new('api parameter must be either "monitor" or "cmdb" ')
      end
    rescue Exception => e
      fgt_rescue(e)
      return e
    end
  end

  def req_debug(url, cookies, parameters, payload)
    p '---- Pre Request ----'
    p "Req URL: #{url}"
    p "Req Cookies: #{cookies}"
    p "Req Headers: :X-CSRFTOKEN = #{cookies['ccsrftoken']}"
    p "Req Params: #{parameters}"
    p 'Req Payload: '
    if payload
      puts JSON.pretty_generate(payload)
    else
      p '--no payload'
    end
    p '---------------------'
  end

  def res_debug(res)
    p '----- Req Results ----'
    p "Request Arguments Sent: #{res.args}"
    p "Request Request: #{res.request}"
    p "Response Code: #{res.code}"
    p "Response Cookies: #{res.cookies}"
    p "Response Headers: #{res.headers}"
    p "Response Body: #{res.body}"
    p '----------------------'
    return res
  end


  #################################################################################
  ## fgt_rescue
  ##
  ## Provides style for rescue and error messaging
  #################################################################################
  def fgt_rescue(error)
    puts '### Error! ###'
    puts error.message
    puts error.backtrace.inspect
    puts '##############'
    puts ''
  end
end