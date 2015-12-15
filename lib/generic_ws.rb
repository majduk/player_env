require 'service_proxy/base'
require 'hpricot'

class GenericWsClient < ServiceProxy::Base

  def self.enabled?
    return ((not config.blank?) and (not config[:wsdl].blank?))
  end

  def self.config
    return APP_CONFIG[config_name]
  end

  def self.config_name
    return "#{self}".underscore.to_sym
  end

  def initialize
      @config=self.class.config   
      raise Exception.new "Unconfigured: #{self.class.config_name}" if @config.blank?   
      super( @config[:wsdl] ) unless @config[:wsdl].blank?
      if self.class.enabled? 
        self.http.read_timeout = 20
        self.http.read_timeout = @config[:read_timeout] unless @config[:read_timeout].blank?
      end       
      @no_cache=( @config[:no_cache]==true )
      @cache_validity=30.seconds
      @cache_validity='#{config[:cache_validity_seconds]'.to_i.seconds unless @config[:cache_validity_seconds].blank?         
  end

end
