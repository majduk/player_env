class SmpClient
  require 'net/http'
  require 'net/https'
  require 'uri'
  
  def self.activate_req(params)
    op="activate-req"
    return operation(op, params)
  end

  def self.activate_rej(params)
    op="activate-rej"
    return operation(op, params)
  end

  def self.deactivate(params)
    op="deactivate-req"
    return operation(op, params)
  end
  
  def self.activate_ind(params)
    op="activate-ind"
    return operation(op, params)
  end  

  def self.query_req(params)
    op="query-req"
    return query(op, params)
  end 
  
  protected
  def self.operation(operation,params)
      response=execute operation,params
     if response.kind_of? Net::HTTPSuccess
        json=JSON.parse(response.body)
        st=json["api"]["items"][0]["status"]
        return (st>199 and st < 300 )       
     else
      return false
     end      
  end

  def self.query(operation,params)
     response=execute operation,params
     if response.kind_of? Net::HTTPSuccess
        return JSON.parse(response.body)               
     else
      return nil
     end      
  end
    
  def self.execute(operation, p)
     params=p.with_indifferent_access 
     smp_params={ :msisdn => "#{params[:msisdn]}", :imsi => "#{params[:imsi]}", :service => "#{params[:service]}" }
     if not params[:smp_params].blank?
      smp_params[:params]=params[:smp_params] 
     end        
     uriStr="/internal/smx/#{operation}?" + smp_params.to_param
     uri =  URI.parse(APP_CONFIG[:smp_uri] + uriStr)
     http = Net::HTTP.new(uri.host, uri.port)
     request = Net::HTTP::Get.new(uri.request_uri, 
      initheader = {
        'X-Oapi-Auth'  => APP_CONFIG[:smp_auth]
      }
      )

     Rails.logger.debug("SmpClient #{operation} request #{uri.inspect}")
     response = http.request(request)     
     Rails.logger.debug("SmpClient #{operation} response #{response.inspect} #{response.body}")
     return response     
  end
  
end