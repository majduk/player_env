require 'service_proxy/base'
require 'hpricot'

class MppsTpuiClient < ServiceProxy::Base
  
  def initialize
      super(APP_CONFIG[:mpps_tpui_ws_wsdl])
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
  
  protected
  def execute(operationType,params)    
    result=provisionService( :msisdn => params[:msisdn], :serviceCode => params[:service], :operationType => operationType, :imsi => params[:imsi], :externalApplicationId => APP_CONFIG[:mpps_tpui_ex_app_id], :params => params[:params] )
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
  
  def parse_provision_service(response)
    r = Nokogiri.XML(response.body).xpath("//resultCode")
    Rails.logger.debug("MppsTpuiClient result #{r}")
    0 == ( r.xpath("//resultCode").first.child.to_s  =~ /2../ )   
  end

end

class MppsSmpWSClient < ServiceProxy::Base

  def initialize
      super(APP_CONFIG[:mpps_smp_ws_wsdl])
  end

  def deactivate(options)
     execute('DEACTIVATE',options)
  end

  def activate(options)
     execute('ACTIVATE',options)
  end
  
  protected
  def execute(operationType,options)    
    result=performAnOrder( :msisdn => options[:msisdn], :serviceName => options[:service], :operationType => operationType, :imsi => options[:msisdn], :applicationId => "SMP", :channel => 'SMP' )
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

class MppsCustomerCareWSClient < ServiceProxy::Base

  attr_accessor :transactionId

  def initialize
      @cc_app_id = APP_CONFIG[:mpps_cc_app_id]      
      super(APP_CONFIG[:mpps_cc_ws_wsdl]) unless APP_CONFIG[:mpps_cc_ws_wsdl].blank?      
  end

  def self.enabled?
    return (not APP_CONFIG[:mpps_cc_ws_wsdl].blank?)
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
  
  protected
  def execute(state,accessLevel,options)
    if MppsCustomerCareWSClient.enabled?
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
