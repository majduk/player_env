require 'generic_ws'

class DcbClient < GenericWsClient

  def initialize      
      super
      @system_identifier={:userName => @config[:system_name], :systemName => @config[:system_name]}
      @no_cache=true
  end

  def is_dcb_allowed?(p)
    params=p.with_indifferent_access
    result=Rails.cache.fetch("#{self.class.config_name}/#{params[:msisdn]}/is_dcb_allowed", force: @no_cache, expires_in: @cache_validity ) do
      isDCBAllowed( params )
    end
    Rails.logger.debug("DcbClient.isDCBAllowed(no_cache:#{@no_cache},validity:#{@cache_validity},#{params.inspect}) returned #{result.inspect}")
    return result
  end

  def dcb_charge(p)
    params=p.with_indifferent_access
    params=@config.merge params
    result=DCBCharge(params)             
    Rails.logger.debug("DcbClient.DCBCharge(#{params.inspect}) returned #{result.inspect}")
    return result
  end

  def dcb_confirm(p)
    params=p.with_indifferent_access
    params=@config.merge params
    result=DCBConfirm(params)             
    Rails.logger.debug("DcbClient.DCBConfirm(#{params.inspect}) returned #{result.inspect}")
    return result
  end

  def dcb_cancel(p)
    params=p.with_indifferent_access
    params=@config.merge params
    result=DCBCancel(params)             
    Rails.logger.debug("DcbClient.DCBCancel(#{params.inspect}) returned #{result.inspect}")
    return result
  end


  def dcb_refund(p)
    params=p.with_indifferent_access
    params=@config.merge params
    result=DCBRefund(params)             
    Rails.logger.debug("DcbClient.DCBRefund(#{params.inspect}) returned #{result.inspect}")
    return result
  end

  def soap_envelope(options, &block)
    xsd = 'http://www.w3.org/2001/XMLSchema'
    env = 'http://schemas.xmlsoap.org/soap/envelope/'
    xsi = 'http://www.w3.org/2001/XMLSchema-instance'
    sch = 'http://playmobile.pl/common/schema'
    dcb = 'http://project4.pl/dcb'
    xml = Builder::XmlMarkup.new
    xml.env(:Envelope, 'xmlns:xsd' => xsd, 'xmlns:env' => env, 'xmlns:xsi' => xsi, 'xmlns:dcb' => dcb, 'xmlns:sch' => sch  ) do
      xml.env(:Body) do          
          yield xml if block_given?          
      end
    end  
    xml
  end

  def build_system_identifier(xml)
        [:systemName, :userName].each do |tag_name|
          xml.tag!("sch:#{tag_name}",@system_identifier[tag_name])
        end    
  end

  def build_chargeId_tag(params,xml)
      cid=string_to_chargeId params[:charge_id]
      xml.tag!("dcb:chargeId", cid )
  end

  def build_out_tag(params,xml)
      out=string_to_out params[:out]
      xml.tag!("dcb:OUT", out )
  end

  def build_effectiveDate_tag(params,xml)
      time=Time.parse params[:effectiveDate].to_s      
      xml.tag!("dcb:effectiveDate", time.iso8601 )
  end

  def build_dcb_charge(options)    
    soap_envelope(options) do |xml|
  	  xml.tag!("dcb:DCBCharge", :txId=>options[:id]) do
        build_system_identifier xml
        build_out_tag options, xml
        build_effectiveDate_tag options, xml 
        [:type, :cancellable,:net,:tax,:gross,:title,:contactInfo].each do |tag_name|
          xml.tag!("dcb:#{tag_name}",options[tag_name]) unless options[tag_name].blank? 
        end                    
  	 end
    end
  end

  def build_dcb_request(clazz,options)
    soap_envelope(options) do |xml|
  	  xml.tag!("dcb:#{clazz}", :txId=>options[:id]) do
        build_system_identifier xml
        build_out_tag options, xml
        build_chargeId_tag options, xml                   
  	  end
    end
  end

  def build_dcb_cancel(options)    
    return build_dcb_request "DCBCancel",options
  end

  def build_dcb_refund(options)    
    return build_dcb_request "DCBRefund",options
  end

  def build_dcb_confirm(options)    
    return build_dcb_request "DCBConfirm",options
  end

  def parse_dcb_response(response,clazz)
    Rails.logger.debug("DcbClient.#{clazz}: #{response.inspect}")
    if response.kind_of? Net::HTTPSuccess
      begin
        xml=Nokogiri.XML(response.body)      
        xml.remove_namespaces!
        dcb=xml.xpath("//#{clazz}").first
        cid=dcb.xpath("//chargeId").first
        return OpenStruct.new(
          :error?       => false,
          :tx_id        =>  dcb['txId'],
          :charge_id    => chargeId_to_string( cid.attributes ) 
        ) unless cid.blank?
        return OpenStruct.new(
          :error?       => false,
          :tx_id        =>  dcb['txId'],
        )
      rescue StandardError => e
        Rails.logger.warn("DcbClient.#{clazz} exception \"#{e}\": #{response.body}")        
        raise e                
      end           
    end
    if response.kind_of? Net::HTTPInternalServerError  and  not response.body.blank?
        xml=Nokogiri.XML(response.body)      
        xml.remove_namespaces!
        code_node=xml.xpath("//Fault//code").first
        unless code_node.blank?
          message=xml.xpath("//Fault//message")
          unless message.blank?
            message=message.first.child.to_s
          end          
          exception=xml.xpath("//Fault//exceptionClass")
          unless exception.blank?
            exception=exception.first.child.to_s
          end
          code=code_node.child.to_s
          return OpenStruct.new( :error? => true, :code => code, :message => message, :exception => exception) unless code=="UNKNOWN_ERROR" 
        end
    end    
    Rails.logger.debug("DcbClient.#{clazz}: #{response.body}")        
    raise Exception.new "#{clazz}::#{response}"      
  end

  def parse_dcb_charge(response)
    return parse_dcb_response response,"DCBChargeResponse"
  end

  def parse_dcb_cancel(response)
    return parse_dcb_response response,"DCBCancelResponse"
  end

  def parse_dcb_confirm(response)
    return parse_dcb_response response,"DCBConfirmResponse"
  end

  def parse_dcb_refund(response)
    return parse_dcb_response response,"DCBRefundResponse"
  end

  def build_is_dcb_allowed(options)    
    soap_envelope(options) do |xml|
  	  xml.tag!("dcb:isDCBAllowed") do             
             build_system_identifier xml
             xml.dcb :msisdn, options[:msisdn] unless options[:msisdn].blank?
             xml.dcb :imsi, options[:imsi] unless options[:imsi].blank?             
  	 end
    end
  end

  def parse_is_dcb_allowed(response)
    Rails.logger.debug("DcbClient.isDCBAllowedResponse: #{response.inspect}")
    if response.kind_of? Net::HTTPSuccess
      begin
        xml=Nokogiri.XML(response.body)      
        xml.remove_namespaces!
        dcb=xml.xpath("//isDCBAllowedResponse").first
        return OpenStruct.new(
          :error?       => false,
          :msisdn       => dcb.xpath("//msisdn").first.child.to_s,
          :imsi         => dcb.xpath("//imsi").first.child.to_s,
          :billing_model => dcb.xpath("//billingModel").first.child.to_s,
          :category     => dcb.xpath("//category").first.child.to_s,
          :brand        => dcb.xpath("//brand").first.child.to_s,
          :allowed      => (dcb.xpath("//allowed").first.child.to_s=="true"),
          :out          => out_to_string( dcb.xpath("//OUT").first.attributes )
        )
      rescue StandardError => e
        Rails.logger.warn("DcbClient.isDCBAllowedResponse exception \"#{e}\": #{response.body}")        
        raise e        
      end      
    end
    if response.kind_of? Net::HTTPInternalServerError  and  not response.body.blank?
        xml=Nokogiri.XML(response.body)      
        xml.remove_namespaces!
        code_node=xml.xpath("//Fault//code").first
        unless code_node.blank?
          code=code_node.child.to_s
          return OpenStruct.new( :error? => true, :code => code) unless code=="UNKNOWN_ERROR" 
        end
    end
    Rails.logger.debug("DcbClient.isDCBAllowedResponse: #{response.body}")        
    raise Exception.new "DcbClientResponse::#{response}"
  end

  def self.config
    return APP_CONFIG[:dcb_ws]
  end

  def chargeId_to_string(cid)
    return cid['trackingIdServ'].to_s + "." +cid['trackingId'].to_s  
  end

  def string_to_chargeId(cid_string)
    cid=cid_string.split('.')
    return { 'trackingIdServ' => cid[0],'trackingId' => cid[1]}  
  end

  def out_to_string(out)
    return out['subscrNo'].to_s + "." +out['subscrNoResets'].to_s + "." + out['accountNo'].to_s
  end

  def string_to_out(out_string)
    out=out_string.split('.')
    return { 'subscrNo' => out[0],'subscrNoResets' => out[1],'accountNo' => out[2] }
  end

end
