class MnpClient
  require 'net/http'
  require 'net/https'
  require 'uri'

  def self.enabled?
    return (not APP_CONFIG[:mnp_api_uri].blank?)
  end
  
  def self.query(msisdn)
     appkey=APP_CONFIG[:mnp_appkey]
     uri = URI.parse(APP_CONFIG[:mnp_api_uri] + "?output=json&show_imsi=true&appkey=" + appkey + "&target=" + msisdn)
     Rails.logger.debug("MnpClient #{uri.inspect}")
     http = Net::HTTP.new(uri.host, uri.port)
     request = Net::HTTP::Get.new(uri.request_uri)
     response = http.request(request)     
     Rails.logger.debug("MnpClient server returned #{response.body}")      
     
     if response.kind_of? Net::HTTPSuccess
        json=JSON.parse(response.body)
        res=json["api"]["request"]["mnp"]
     else 
        #error returned
        res=nil
     end
     
     Rails.logger.debug("MnpClient returned #{res.inspect}")
     return res  
  end
end