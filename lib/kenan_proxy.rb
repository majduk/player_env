class KenanProxy
  require 'net/http'
  require 'net/https'
  require 'uri'

  def self.enabled?
    return (not APP_CONFIG[:kenan_uri].blank?)
  end

  def self.find_by_imsi(imsi)
    return find_by_field("imsi",imsi)
  end
  
  def self.find_by_msisdn(msisdn)
    return find_by_field("msisdn",msisdn)
  end
  
  def self.find_by_field(fieldname,fieldvalue)
     param=fieldname.downcase
     meth="getDataBy" + fieldname.upcase
     uri = URI.parse(APP_CONFIG[:kenan_uri] + "/"+meth+"?"+param+"=" + fieldvalue)
     Rails.logger.debug("KenanProxyClient #{uri.inspect}")
     http = Net::HTTP.new(uri.host, uri.port)
     request = Net::HTTP::Get.new(uri.request_uri)
     request.basic_auth(APP_CONFIG[:kenan_user], APP_CONFIG[:kenan_password])
     response = http.request(request)     
     Rails.logger.debug("KenanProxy server returned #{response.body}")      
     
     if response.body =~ /^[0-9] [A-Za-z]+/
        #error returned
        res=nil
     else
        lines = response.body.split("\n")
        #we take only headers and first line
        header=lines[0].split(";")
        data=lines[1].split(";")        
        res=Hash.new        
        header.each_index { |i|
          res[header[i]] = data[i]
        }
     end
     Rails.logger.debug("KenanProxyClient returned #{res.inspect}")
     return res  
  end
end