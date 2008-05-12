class CitationsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def list
    @citations = Citations.find_all
  end

  def show
    @citation = Citation.find(params[:id])
  end

  def new
    @citation = Citation.new
  end

  def create
    unless params[:citation]
      render :text => "Citation text is missing", :status => :bad_request
      return
    end

    @citation = Citation.create_from_string(params[:citation])

    if @citation.save
      respond_to do |wants|
         wants.html
         wants.js 
         wants.xml { render :xml => @citation.to_xml }
      end 
    else 
      render :text => "Error creating citation",
             :status => :internal_server_error
    end
  end

  def edit
    @citation = Citation.find(params[:id])
  end

  def update
    @citation = Citation.find(params[:id])
    if @citation.update_attributes(params[:citation])
      flash[:notice] = 'Citation was successfully updated.'
      redirect_to :action => 'show', :id => @citation
    else
      render :action => 'edit'
    end
  end

  def destroy
    Citation.find(params[:id]).destroy
    redirect_to :action => 'list'
  end
end
