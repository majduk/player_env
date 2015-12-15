require 'generic_ws'

class MppsSmpWSClient < GenericWsClient

  def initialize
      super
      @applicationId="SMP"
      @channel='SMP'
      @applicationId = @config[:applicationId] unless @config[:applicationId].blank?
      @channel = @config[:channel] unless @config[:channel].blank? 
  end

  def deactivate(options)
     execute('DEACTIVATE',options)
  end

  def activate(options)
     execute('ACTIVATE',options)
  end
  
  protected
  def execute(operationType,options)    
    result=performAnOrder( :msisdn => options[:msisdn], :serviceName => options[:service], :operationType => operationType, :imsi => options[:msisdn], :applicationId => @applicationId, :channel => @channel )
    Rails.logger.debug("MppsSmpWSClient.#{operationType}#{options.inspect} returned #{result}")
    return result
  end
    
  def soap_envelope(options, &block)
    xsd = 'http://www.w3.org/2001/XMLSchema'
    env = 'http://schemas.xmlsoap.org/soap/envelope/'
    xsi = 'http://www.w3.org/2001/XMLSchema-instance'
    xml = Builder::XmlMarkup.new
    xml.env(:Envelope, 'xmlns:xsd' => xsd, 'xmlns:env' => env, 'xmlns:xsi' => xsi, 'xmlns:smp' => self.target_namespace ) do
      xml.env(:Body) do          
          yield xml if block_given?          
      end
    end    
    xml
  end

  def build_perform_an_order(options)
    
    soap_envelope(options) do |xml|
  	 xml.tag!("smp:orderRequest") do
  	   xml.order do
         xml.msisdn options[:msisdn]
         xml.imsi options[:imsi]
         xml.serviceName options[:serviceName]
         xml.operationType options[:operationType]
         xml.applicationId options[:applicationId]          
         xml.channel options[:channel]
       end
  	 end
    end
  end
  
  def parse_perform_an_order(response)
    r = Nokogiri.XML(response.body).xpath("//orderResult")
    Rails.logger.debug("MppsSmpWSClient result #{r}")
    0 == ( r.xpath("//resultCode").first.child.to_s  =~ /2../ )   
  end

end

class MppsCustomerCareWSClient < GenericWsClient

  attr_accessor :transactionId

  def initialize
      super
      @cc_app_id = @config[:app_id]      
  end

  def log_info(options)     
    execute("INFO", "1", options)
  end
  
  def log_error(options)     
    execute("ERROR", "1", options)
  end
  
  def log_pending(options)     
    execute("PENDING", "1", options)
  end  
  
  def execute(state,accessLevel,options)
    if self.class.enabled?
      begin
        options[:transactionId]=@transactionId if options[:transactionId].blank?     
        result=logCustomerOperation( :logLevel => "INFO", :msisdn => options[:msisdn], :transactionId => options[:transactionId], :appId => @cc_app_id, :title => options[:title], :description => options[:description], :state => state, :accessLevel=> accessLevel )
      rescue Exception => e
        result=false
        Rails.logger.debug("MppsCustomerCareWSClient.#{state} Exception while calling MppsCusromerCareWS #{e.inspect}")
      end
      Rails.logger.debug("MppsCustomerCareWSClient.#{state} AppId: #{@cc_app_id} #{options.inspect} returned #{result}")
    else
      result=true
      Rails.logger.debug("MppsCustomerCareWSClient.#{state} AppId: #{@cc_app_id} #{options.inspect} skipped, result #{result}")      
    end    
    return result
  end
    
  def soap_envelope(options, &block)
    xsd = 'http://www.w3.org/2001/XMLSchema'
    env = 'http://schemas.xmlsoap.org/soap/envelope/'
    xsi = 'http://www.w3.org/2001/XMLSchema-instance'
    xml = Builder::XmlMarkup.new
    xml.env(:Envelope, 'xmlns:xsd' => xsd, 'xmlns:env' => env, 'xmlns:xsi' => xsi, 'xmlns:cus' => self.target_namespace ) do
      xml.env(:Body) do          
          yield xml if block_given?          
      end
    end    
    xml
  end

  def build_log_customer_operation(options)
    
    soap_envelope(options) do |xml|
  	 xml.tag!("cus:logRequest") do
  	   xml.logParams do
         xml.msisdn options[:msisdn]         
         xml.transactionId options[:transactionId] unless options[:transactionId].blank? 
         xml.appId options[:appId]
         xml.title options[:title]
         xml.description options[:description]          
         xml.state options[:state]
         xml.logLevel options[:logLevel]
         xml.accessLevel options[:accessLevel]
       end
  	 end
    end
  end
  
  def parse_log_customer_operation(response)
    r = Nokogiri.XML(response.body).xpath("//logResult")    
    if 0 == ( r.xpath("//resultCode").first.child.to_s  =~ /2../ )
      @transactionId=r.xpath("//transactionId").first.child.to_s
      return @transactionId
    end
    Rails.logger.error("MppsCustomerCareWSClient logResult error #{r}")
    return nil 
  end  
end

class MppsTpuiClient < GenericWsClient
  def initialize
    super
    @app_id=@config[:app_id]
  end
  def deactivate(params)
     execute('DEACTIVATE',params)
  end

  def activate(params)
     execute('ACTIVATE',params)
  end

  def modify(params)
     execute('MODIFY',params)
  end

  def service(params)
    result=Rails.cache.fetch("#{self.class.config_name}/#{params[:msisdn]}/service/#{params[:service]}", force: @no_cache, expires_in: @cache_validity ) do
      getInfo( :msisdn => params[:msisdn], :serviceCode => params[:service], :imsi => params[:imsi], :externalApplicationId => @app_id )
    end  
    Rails.logger.debug("MppsTpuiClient.service #{params.inspect} returned #{result}")
    return result
  end

  def services(params)
    return service( :msisdn => params[:msisdn], :service => 'ALL', :imsi => params[:imsi])
  end
  
  def execute(operationType,params)    
    result=provisionService( :msisdn => params[:msisdn], :serviceCode => params[:service], :operationType => operationType, :imsi => params[:imsi], :externalApplicationId => @app_id, :params => params[:params] )
    Rails.logger.debug("MppsTpuiClient.#{operationType}#{params.inspect} returned #{result}")
    return result
  end
    
  def soap_envelope(options, &block)
    xsd = 'http://www.w3.org/2001/XMLSchema'
    env = 'http://schemas.xmlsoap.org/soap/envelope/'
    xsi = 'http://www.w3.org/2001/XMLSchema-instance'
    xml = Builder::XmlMarkup.new
    xml.env(:Envelope, 'xmlns:xsd' => xsd, 'xmlns:env' => env, 'xmlns:xsi' => xsi, 'xmlns:tel' => self.target_namespace ) do
      xml.env(:Body) do          
          yield xml if block_given?          
      end
    end    
    xml
  end

  def build_provision_service(options)
    
    soap_envelope(options) do |xml|
  	 xml.tag!("tel:provisionServiceRequest") do
  	   xml.serviceCallClientData do
             xml.msisdn options[:msisdn]
             xml.imsi options[:imsi]
             xml.serviceCode options[:serviceCode]
             xml.operationType options[:operationType]
             xml.externalApplicationId options[:externalApplicationId]
       end
  	   xml.serviceCallParams do
          options[:params].each do |key,value|
             xml.params{
              xml.paramKey key
              xml.paramValue value
             }
          end
       end       
  	 end
    end
  end

  def build_get_info(options)    
    soap_envelope(options) do |xml|
  	 xml.tag!("tel:getInfo") do
  	   xml.serviceCallBaseClientData do
             xml.msisdn options[:msisdn]
             xml.imsi options[:imsi]
             xml.serviceCode options[:serviceCode]
             xml.externalApplicationId options[:externalApplicationId]
       end       
  	 end
    end
  end
  
  def parse_get_info(response)
    Rails.logger.debug("MppsTpuiClient.getInfo: #{response.inspect}")
          
    if response.kind_of? Net::HTTPSuccess and not response.body.blank? 
      xml = Nokogiri.XML(response.body).xpath("//resultCode")
      resultCode=xml.xpath("//resultCode").first.child.to_s and 
      if 0 == ( resultCode =~ /2../ )
        prof=OpenStruct.new(:error? => false)
        xml.xpath("//userServices").each do |service|      
          n=service.xpath("serviceName").first.child.to_s
          active=service.xpath("status").first.child.to_s=="ACTIVE"
          params={}.with_indifferent_access                       
          service.xpath("serviceParams").each do |param|
            key=param.xpath("paramKey").first.child.to_s
            value=param.xpath("paramValue").first.child.to_s
            params[key]=value
          end
          prof[n]=OpenStruct.new(
            :active? => active,
            :params => params
          )
        end
        return prof
      else
        Rails.logger.debug("MppsTpuiClient.getInfo: #{response.body}")
        raise Exception.new "MppsTpuiClient.getInfoResponse::resultCode::#{resultCode}"      
      end       
    end
    Rails.logger.debug("MppsTpuiClient.getInfo: #{response.body}")
    raise Exception.new "MppsTpuiClient.getInfoResponse::#{response}"
  end
  
  def parse_provision_service(response)
    r = Nokogiri.XML(response.body).xpath("//resultCode")
    Rails.logger.debug("MppsTpuiClient result #{r}")
    0 == ( r.xpath("//resultCode").first.child.to_s  =~ /2../ )   
  end

end
