require 'service_proxy/base'
require 'hpricot'

class GenericWsClient < ServiceProxy::Base

  def self.enabled?
    return ((not config.blank?) and (not config[:wsdl].blank?))
  end

  def initialize
      name=self.class.config_name
      @config=self.class.load_config name
      raise Exception.new "Unconfigured: #{name}" if @config.blank?
      super( @config[:wsdl] ) unless @config[:wsdl].blank?
      if self.class.enabled?
        self.http.read_timeout = 20
        self.http.read_timeout = @config[:read_timeout] unless @config[:read_timeout].blank?
      end
      @no_cache=( @config[:no_cache]==true )
      @cache_validity=30.seconds
      @cache_validity='#{config[:cache_validity_seconds]'.to_i.seconds unless @config[:cache_validity_seconds].blank?
  end

protected
  def self.load_config name
    return APP_CONFIG[name]
  end

  def self.config
    name=config_name
    return APP_CONFIG[name]
  end

  def self.config_name
    name="#{self}".underscore.to_sym
    return name
  end

end
