require 'service_proxy/base'
require 'hpricot'

class GenericWsClient < ServiceProxy::Base

  module ServiceProxy
    class Base  
      def parse_wsdl
        parser = ServiceProxy::Parser.new
        sax_parser = Nokogiri::XML::SAX::Parser.new(parser)
        sax_parser.parse(self.wsdl)
        self.service_methods = parser.service_methods.sort
        self.target_namespace = parser.target_namespace
        self.soap_actions = parser.soap_actions
        raise RuntimeError, "Could not parse WSDL" if self.service_methods.empty?
      end      
    end
  end
  
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
