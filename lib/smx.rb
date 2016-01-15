require 'generic_ws'

class ComponentState 
  
  attr_reader :response,:error,:activate_available,:deactivate_available,:raw,:code,:exception,:message,:name,:desc,:price,:billing_type
    
  def initialize(response)
    @response = response
    @raw = response.body
    @error = false
    @activate_available = false
    @deactivate_available = false
    @error = true unless @response.kind_of? Net::HTTPSuccess
    xml=Nokogiri.XML(response.body)
    xml.remove_namespaces!
    ccr=xml.xpath("//checkComponentResponse").first
    scr=xml.xpath("//setComponentResponse").first
    if @error==false
      if not ccr.blank?
        node=ccr.xpath("//billingPrice").first
        @price=node.child.to_s  unless node.blank?
        node=ccr.xpath("//status/code").first
        @code=node.child.to_s  unless node.blank?
        node=ccr.xpath("//billingType").first
        @billing_type=node.child.to_s  unless node.blank?
        node=ccr.xpath("//name").first
        @name=node.child.to_s  unless node.blank?
        node=ccr.xpath("//desc").first
        @desc=node.child.to_s  unless node.blank?
        node=ccr.xpath("//status/desc").first
        @message=node.child.to_s  unless node.blank?
        @activate_available=true unless ccr.xpath("//activateAvailable").first.blank?
        @deactivate_available=true unless ccr.xpath("//deactivateAvailable").first.blank?
      elsif not scr.blank?
        node=scr.xpath("//price").first
        @price=node.child.to_s  unless node.blank?
        node=scr.xpath("//postMessage").first
        @message=node.child.to_s  unless node.blank?
      else
        @error=true
      end
    else
      @code=xml.xpath("//code").first.child.to_s
      @exception=xml.xpath("//exceptionClass")
      if not @exception.blank?
        @exception=@exception.first.child.to_s
      end
      @message=xml.xpath("//message").first.child.to_s
    end
  end
  
  def error?
      return @error
  end
  
  def active?
      return @code==1
  end

  def in_transition?
      if @code==2
        return true
      end
      if @code=="4.3" and @message =~ /Usluga w trakcie realizacji/
        return true
      end      
      return false
  end

  def available?
      return (@code==0 or @code==1)
  end

  def not_permitted?
      if @code=="4.2.1"
        return true
      end
      if @code=="4.3" and @message =~ /4.6.0/
        return true
      end  
      return false
  end
  
  def activate_available?
    return @activate_available
  end

  def deactivate_available?
    return @activate_available
  end
    
end

class ComponentsClient < GenericWsClient
  
  def initialize
      super
      @system_name=@config[:system_name]
  end

  def deactivate(params)
     executeSetComponent('DEACTIVATE',params)
  end

  def activate(params)
     executeSetComponent('ACTIVATE',params)
  end

  def check(params)
     return executeCheckComponent(params)
  end
  
  protected
  def executeCheckComponent(p)
    params=p.with_indifferent_access
    result=Rails.cache.fetch("#{self.class.config_name}/#{params[:msisdn]}/short_display/#{params[:short_display]}", force: @no_cache, expires_in: @cache_validity ) do
      checkComponent( :msisdn => params[:msisdn],  :userName => params[:msisdn], :systemName => @system_name, :shortDisplay => params[:short_display] )
    end
    Rails.logger.debug("ComponentsClient.executeCheckComponent #{params.inspect} returned #{result.inspect}")
    return result
  end

  def executeSetComponent(opcode,p)
    params=p.with_indifferent_access    
    result=setComponent( :operationName => opcode, :msisdn => params[:msisdn],  :userName => params[:msisdn], :systemName => @system_name, :shortDisplay => params[:short_display] )
    Rails.logger.debug("ComponentsClient.#{opcode} #{params.inspect} returned #{result.inspect}")
    return result
  end
    
  def soap_envelope(options, &block)
    xsd = 'http://www.w3.org/2001/XMLSchema'
    env = 'http://schemas.xmlsoap.org/soap/envelope/'
    xsi = 'http://www.w3.org/2001/XMLSchema-instance'
    sal = 'http://playmobile.pl/sms/sales'
    sch = 'http://playmobile.pl/common/schema'
    xml = Builder::XmlMarkup.new
    xml.env(:Envelope, 'xmlns:xsd' => xsd, 'xmlns:env' => env, 'xmlns:xsi' => xsi, 'xmlns:sal' => sal, 'xmlns:sch' => sch  ) do
      xml.env(:Body) do          
          yield xml if block_given?          
      end
    end  
    xml
  end

  def build_check_component(options)    
    soap_envelope(options) do |xml|
  	  xml.tag!("sal:checkComponent") do
             xml.sal :msisdn, options[:msisdn]
             xml.sal :shortDisplay, options[:shortDisplay]
             xml.sch :systemName, options[:systemName]
             xml.sch :userName, options[:userName]
  	 end
    end
  end
  
  def parse_check_component(response)
    return ComponentState.new response
  end

  def build_set_component(options)    
    soap_envelope(options) do |xml|
  	  xml.tag!("sal:setComponent") do
             xml.sal :msisdn, options[:msisdn]
             xml.sal :shortDisplay, options[:shortDisplay]
             xml.sal :operationName, options[:operationName]
             xml.sch :systemName, options[:systemName]
             xml.sch :userName, options[:userName]
             xml.sal :auditData do
                xml.sal :price, options[:price]               
                xml.sal :componentName, options[:shortDisplay]
                xml.sal :executionTime, Time.new.strftime("%Y-%m-%dT%H:%M:%S")
             end
  	 end
    end
  end
  
  def parse_set_component(response)
    return ComponentState.new response
  end

end
