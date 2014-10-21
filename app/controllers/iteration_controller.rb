class IterationController < ApplicationController
  before_filter :check_api_token

  def index
    redirect_to :action => :view if @api_token
  end

  def view
    return redirect_to :action => :index unless @api_token

    @iteration_presenter = cached_iteration_presenter
    @iteration_presenter.selected_project_id = params[:project_id].try(:to_i)
    @iteration_presenter.my_stories_only = !!params[:my_stories_only]
    @iteration_presenter.show_last_week = !!params[:show_last_week]
  end

  def refresh
    session.delete :iteration_presenter

    redirect_to :action => :view
  end

  private

    def check_api_token
      session[:api_token] = params[:api_token] if params[:api_token]
      @api_token          = session[:api_token]
    end

    def cached_iteration_presenter
      unless session[:iteration_presenter] && session[:iteration_presenter_created].try(:>, 12.hours.ago)
        session[:iteration_presenter] = IterationPresenter.new(@api_token)
        session[:iteration_presenter_created] = Time.now
      end
      session[:iteration_presenter]
    end
end
