class ApplicationController < ActionController::Base
  protect_from_forgery

  include Pundit
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  after_action :verify_authorized, unless: :devise_controller?

  before_action :configure_permitted_parameters, if: :devise_controller?
  force_ssl if: -> { Rails.env.production? }, unless: :allow_insecure?
  before_action :redirect_to_host_url

  before_action do
    if current_user.try(:admin?)
      Rack::MiniProfiler.authorize_request
    end
  end

  rescue_from(ActionView::MissingTemplate) do |e|
    if request.format != :html
      head(:not_acceptable)
    else
      raise
    end
  end

  def after_sign_in_path_for(resource)
    params[:return_to] || super
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit(policy(User).permitted_attributes + [region_ids: []])
    end
  end

  def allow_insecure?
    false
  end

  def user_not_authorized
    flash[:error] = "You are not authorized to perform this action."
    redirect_to(request.referer || root_path)
  end

  # we redirect to host url only after force_ssl to support hsts
  def redirect_to_host_url
    return unless Rails.env.production?
    host_url = ENV['HOST_URL']
    # don't redirect if we're already there
    return if request.host.downcase.starts_with?(host_url.downcase)
    # don't redirect if not ssl and not allow_insecure
    if ssl?
      redirect_to("https://#{host_url}#{request.fullpath}", status: :moved_permanently)
    elsif allow_insecure?
      redirect_to("http://#{host_url}#{request.fullpath}", status: :moved_permanently)
    end
  end
end
