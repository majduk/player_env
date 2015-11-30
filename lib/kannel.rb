class KannelClient
  require 'net/http'
  require 'net/https'
  require 'uri'

  def initialize()
      @kanneluri = APP_CONFIG[:kannel_uri]
      @kanneluser =  APP_CONFIG[:kannel_user]
      @kannelpassword = APP_CONFIG[:kannel_password]
      @kannelfrom = APP_CONFIG[:kannel_sender]
      Rails.logger.debug("Created new kannel client #{self.inspect}")
  end
 
  def sendsms(from,to,text)
    begin
      from = @kannelfrom if from.blank?
      utext= CGI::escape(text)
      Rails.logger.debug("Sending message from=#{from} to=#{to} text=\"#{text}\" encoded=#{utext}")
      url = URI.parse(@kanneluri + "?username=" + @kanneluser + "&password=" + @kannelpassword + "&from=" + from + "&to=" + to + "&text=" + utext)      
      res = Net::HTTP.get_response(url)
      
      case res
        when Net::HTTPSuccess
          return true
        else
          Rails.logger.error("Error #{res} while connecting to #{url.inspect}")
          return false
      end
      rescue Exception  => exc
        Rails.logger.error("Exception #{exc.inspect} while connecting to #{url.inspect}")
        return false
    end    
  end
end