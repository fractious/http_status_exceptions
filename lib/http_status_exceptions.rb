module HTTPStatus
  
  class Base < StandardError

    # The path from which the error documents are loaded.
    cattr_accessor :template_path
    @@template_path = 'shared/http_status'

    # The layout in which the error documents are rendered
    cattr_accessor :template_layout

    attr_reader :status, :details
    
    # Creates the exception with a message and some optional other info.
    def initialize(message = nil, details = nil)
      @status = self.class.to_s.split("::").last.underscore.to_sym rescue :internal_server_error
      @details = details
      super(message)
    end
    
    # The numeric status code corresponding to this exception
    def status_code
      ActionController::StatusCodes::SYMBOL_TO_STATUS_CODE[@status]
    end
    
    # The name of the template that should be used as error page for this exception
    def template
      "#{@@template_path}/#{@status}"
    end
  end

  # Creates all the exception classes based on Rails's list of available status code and
  # registers the exception handler using the rescue_from method.
  def self.included(base)
    ActionController::StatusCodes::STATUS_CODES.each do |code, name|
      const_set(name.to_s.gsub(/[^A-Za-z]/, '').camelize, Class.new(HTTPStatus::Base)) if code >= 400
    end
    
    base.send(:rescue_from, HTTPStatus::Base, :with => :http_status_exception)
  end

  # The default handler for raised HTTP status exceptions. 
  # It will render a template if available, or respond with an empty response
  # with the HTTP status correspodning to the exception.
  def http_status_exception(exception)
    @exception = exception
    render_options = {:template => exception.template, :status => exception.status}
    render_options[:layout] = exception.template_layout if exception.template_layout
    render(render_options)
  rescue ActionView::MissingTemplate
    head(exception.status)
  end
end

ActionController::Base.send(:include, HTTPStatus)