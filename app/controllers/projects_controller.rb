#require 'lib/controllers/plm_object_controller_module'
#require 'lib/controllers/plm_init_controller_module'
class ProjectsController < ApplicationController
  include Controllers::PlmObjectControllerModule
  include Controllers::PlmInitControllerModule
  before_filter :check_init, :only=>[:new]
  access_control (Access.find_for_controller(controller_class_name()))
  
  #before_filter :authorize, :only => [ :show, :edit , :new, :destroy ]
  
  # GET /projects
  # GET /projects.xml
  # liste de tous les projets
  # les lignes sont tries d'apres le parametre sort
  # les objets sont filtres d'apres le parametre query (requete simple d'egalite 
  #   sur tous les attributs)
  def index   
    @projects = Project.find_paginate({:page=>params[:page],:query=>params[:query],:sort=>params[:sort], :nb_items=>get_nb_items(params[:nb_items])}) 
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @projects[:recordset] } 
    end
  end
  
  # GET /projects/1
  # GET /projects/1.xml
  # affichage d'un projet
  # liste des attributs avec leur valeur
  # arbre montrant la structure du projet: le client et les parts
  def show
    @project = Project.find(params[:id])
    @relation_types_document=Typesobject.get_types_names(:relation_document)
    @relation_types_part=Typesobject.get_types_names(:relation_part)
    @tree=create_tree(@project)
    @tree_up=create_tree_up(@project)

    @documents=@project.documents
    @parts=@project.parts
    @customers=@project.customers
    

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @project }
    end
  end
  
  # GET /projects/new
  # GET /projects/new.xml
  # nouveau projet
  # le owner est attribue avant la saisie, voir Project.create_new
  # on definit les listes de valeur pour le type et le statut 
  def new
    @project = Project.create_new(nil, @user)
    @types=Project.get_types_project
    @status= Statusobject.find_for("project")
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @project }
    end
  end
  
  # GET /projects/1/edit
  # modification d'un projet
  def edit
    @project = Project.find_edit(params[:id])
    @types=Project.get_types_project
    @status= Statusobject.find_for("project")
  end
  
  # POST /projects
  # POST /projects.xml
  # creation d'un projet (apres validation du new)
  def create
    @project = Project.create_new(params[:project], @user)
    @types=Project.get_types_project
    @status= Statusobject.find_for("project")
    respond_to do |format|
      if @project.save
        flash[:notice] = t(:ctrl_object_created,:object=>t(:ctrl_project),:ident=>@project.ident)
        format.html { redirect_to(@project) }
        format.xml  { render :xml => @project, :status => :created, :location => @project }
      else
        flash[:notice] = t(:ctrl_object_not_created,:object=>t(:ctrl_project),:ident=>@project.ident)
        format.html { render :action => "new" }
        format.xml  { render :xml => @project.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  # PUT /projects/1
  # PUT /projects/1.xml
  # maj d'un projet (apres validation du edit)
  def update
    @project = Project.find(params[:id])
    @types=Project.get_types_project
    @status= Statusobject.find_for("project")
    respond_to do |format|
      if @project.update_attributes(params[:project])
        flash[:notice] = t(:ctrl_object_updated,:object=>t(:ctrl_project),:ident=>@project.ident)
        format.html { redirect_to(@project) }
        format.xml  { head :ok }
      else
        flash[:notice] = t(:ctrl_object_not_updated,:object=>t(:ctrl_project),:ident=>@project.ident)
        format.html { render :action => "edit" }
        format.xml  { render :xml => @project.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  # DELETE /projects/1
  # DELETE /projects/1.xml
  def destroy
    @project = Project.find(params[:id])
    @project.destroy
    respond_to do |format|
      flash[:notice] = t(:ctrl_object_deleted,:object=>t(:ctrl_project),:ident=>@project.ident)
      format.html { redirect_to(projects_url) }
      format.xml  { head :ok }
    end
  end
  
  #methode: creation de 'arbre du projet  
  def create_tree(obj)
    tree = Tree.new({:label=>t(:ctrl_object_explorer,:object=>t(:ctrl_project)),:open => true})   
    #cnode=tree_project(obj)     
    #tree << cnode     
    session[:tree_object]=obj
    follow_tree_project(tree, obj,self)
    tree
  end
  
  def create_tree_up(obj)
    tree = Tree.new({:label=>t(:ctrl_object_referencer,:object=>t(:ctrl_project)),:open => true})   
    #cnode=tree_project(obj)     
    #tree << cnode     
    session[:tree_object]=obj
    follow_tree_up_project(tree, obj,self)
    tree
  end
  
  def add_docs
    define_variables
    @project = Project.find(params[:id])
    relation=params[:relation][:document]
    respond_to do |format|      
      if @favori_document != nil 
        flash[:notice] = ""
        @favori_document.items.each do |item|
          link_=Link.create_new("project", @project, "document", item, relation)  
          link=link_[:link]
          if(link!=nil) 
            if(link.save)
              flash[:notice] += t(:ctrl_object_added,:object=>t(:ctrl_document),:ident=>item.ident,:relation=>relation,:msg=>t(link_[:msg]))
            else
              flash[:notice] += t(:ctrl_object_not_added,:object=>t(:ctrl_document),:ident=>item.ident,:relation=>relation,:msg=>t(link_[:msg]))
            end
          else
            flash[:notice] += t(:ctrl_object_not_linked,:object=>t(:ctrl_document),:ident=>item.ident,:relation=>relation,:msg=>nil)
          end
        end
        reset_favori_document
      else
        flash[:notice] = t(:ctrl_nothing_to_paste,:object=>t(:ctrl_document))
      end
      format.html { redirect_to(@project) }
      format.xml  { head :ok }
    end
  end
  
  def add_parts
    define_variables
    @project = Project.find(params[:id])
    relation=params[:relation][:part]
    respond_to do |format|      
      if @favori_part != nil 
        flash[:notice] = ""
        @favori_part.items.each do |item|
          #flash[:notice] += "<br>"+ item.ident.to_s
          link_=Link.create_new("project", @project, "part", item, relation)  
          link=link_[:link]
          if(link!=nil) 
            if(link.save)
              flash[:notice] += t(:ctrl_object_added,:object=>t(:ctrl_part),:ident=>item.ident,:relation=>relation,:msg=>t(link_[:msg]))
            else
              flash[:notice] += t(:ctrl_object_not_added,:object=>t(:ctrl_part),:ident=>item.ident,:relation=>relation,:msg=>t(link_[:msg]))
            end
          else
            flash[:notice] += t(:ctrl_object_not_linked,:object=>t(:ctrl_part),:ident=>item.ident,:relation=>relation,:msg=>nil)           
          end
        end
        reset_favori_part
      else
        flash[:notice] = t(:ctrl_nothing_to_paste,:object=>t(:ctrl_part))
      end
      format.html { redirect_to(@project) }
      format.xml  { head :ok }
    end
    #redirect_to_index("add_docs termine")
    
  end  
  
  def promote
    ctrl_promote(Project,false)
  end
  
  def demote
    ctrl_demote(Project,false)
  end
  
  def add_project_to_favori 
    project=Project.find(params[:id])
    @favori_project.add_project(project)
    ##redirect_to(:action => index) 
  end
  
  def empty_favori_project
    session[:favori_project]=nil
    @favori_project=nil
    #flash[:notice] ="Plus de favoris project"
    ##redirect_to :action => :index   
  end
  def new_forum
    puts 'CustomerController.new_forum:id='+params[:id]
    @object = Project.find(params[:id])
    @types=Typesobject.find_for("forum")
    @status= Statusobject.find_for("forum")
    respond_to do |format|      
      flash[:notice] = ""
      @forum=Forum.create_new(nil)
      @forum.subject=t(:ctrl_subject_forum,:object=>t(:ctrl_project),:ident=>@object.ident)
      format.html {render :action=>:new_forum, :id=>@object.id }
      format.xml  { head :ok }
    end
  end
  def add_forum
    @object = Project.find(params[:id])
    ctrl_add_forum(@object,"project")
  end
  
end