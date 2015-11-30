class OauthClient
  require 'net/http'
  require 'net/https'
  require 'uri'
 
  def self.enabled?
    return (not APP_CONFIG[:oauth_profile_uri].blank?)
  end 
  
  def self.msisdn(token)
    profile = self.profile(token)
    if not profile.blank?
      msisdn = profile
      msisdn = nil if profile.blank?
      ret = profile["msisdn"]
      msisdn = nil if ret.blank?
      if ret.size == 9
        ret = "48" + ret
      end
      msisdn = nil if ret.size != 11
    else
      msisdn = nil
    end
    msisdn = ret unless msisdn == nil
      
    Rails.logger.debug("OauthClient msisdn #{msisdn}")
    return msisdn  
  end
      
  def self.profile(token)
     return nil if token.blank?
     uri = URI.parse(APP_CONFIG[:oauth_profile_uri] + "?access_token=" + token )
     Rails.logger.debug("OauthClient #{uri.inspect}")
     http = Net::HTTP.new(uri.host, uri.port)
     request = Net::HTTP::Get.new(uri.request_uri)
     response = http.request(request)     
     Rails.logger.debug("OauthClient server returned #{response.body}")      
     
     if response.kind_of? Net::HTTPSuccess     
        res=JSON.parse(response.body)
     else 
        res=nil
     end
     
     Rails.logger.debug("OauthClient returned #{res.inspect}")
     return res  
  end
end