#
#  plm_participant.rb
#  sylrplm
#
#  Created by Sylvère on 2012-02-02.
#  Copyright 2012 Sylvère. All rights reserved.
#
require 'ruote'
require 'ruote/sylrplm/plm_process_exception'

class Ruote::PlmParticipant
  include OpenWFE::LocalParticipant
  include Models::SylrplmCommon
  #
  # By default, returns false. When returning true the dispatch to the
  # participant will not be done in his own thread.
  #
  def do_not_thread
    name="PlmParticipant.do_not_thread:"
    true
  end

  def initialize(work=nil, opts=nil)
    name="PlmParticipant.initialize"
    LOG.info (name){"opts="+opts.nil?.to_s+" work="+work.inspect}
    @opts = opts
  end

  def consume(workitem)
    name="PlmParticipant.consume:"
    puts name+"debut *******************************************"
    #puts "PlmParticipant.consume:workitem="+workitem.inspect+" opts="+@opts.nil?.to_s
    #puts "PlmParticipant.consume:attributes="+workitem.attributes.inspect
    begin
      unless workitem.attributes.nil?
        unless workitem.attributes["params"].nil?
          task = get_param(workitem, "task")
          step = get_param(workitem, "step")
          relation_name = get_param(workitem, "relation", nil)
        end
      end
      msg="task(#{task}), step(#{step}), relation(#{relation_name})"
      LOG.info(name){msg}
      unless task.nil? || step.nil? || relation_name.nil?
        fexpid=workitem.flow_expression_id
        #puts name+"instance_id:"+fexpid.workflow_instance_id
        #puts name+"expression_id:"+fexpid.expression_id
        #Ruote::Sylrplm::ArWorkitem.all.each { |ar| puts ar.wfid }
        arworkitem = Ruote::Sylrplm::ArWorkitem.find_by_wfid(fexpid.workflow_instance_id)
        unless arworkitem.nil?
          unless step == "exec"
            #
            # tout sauf exec
            #
            check_objects(arworkitem, task, step, relation_name)
            reply_to_engine (workitem)
          else
          #
          # phase execution
          #
          #puts "PlmParticipant.consume:promote_exec:arworkitem_id="+arworkitem.id.to_s
            obj=nil
            # recherche des liens dont le pere est une tache ayant le meme wfid et ayant la relation requise
            #
            # liens dont le pere est une tache
            execute(task, Link.find_by_father_plmtype_(Ruote::Sylrplm::HistoryEntry.model_name), arworkitem, relation_name)
            reply_to_engine (workitem)
          end
        else
          msg=name+"arworkitem("+fexpid.workflow_instance_id+") non trouve"
          raise PlmProcessException.new(msg, 10008)
        end
      else
        msg=name+"task(#{task}) or step(#{step}) or relation(#{relation_name}) undefined"
        raise PlmProcessException.new(msg, 10009)
      end
    rescue Exception => e
      stack=""
      e.backtrace.each do |x|
        stack+= x+"\n"
      end
      LOG.error (name){"exception:#{task}/#{step}:err=#{e}:stack=\n#{stack}"}
      pe = get_error_journal.record_error(OpenWFE::ProcessError.new(fexpid, e.to_s, workitem, "fatal", stack))
      get_engine.replay_at_error(pe)
      get_engine.cancel_process(fexpid)
    end
    puts name+"fin *******************************************"
  end

  private

  def check_objects(arworkitem, task, step, relation_name)
    name="#{self.class.name}.#{__method__}"
    #prise en compte des objets transmis par le ar_workitem
    nb_applicable=0
    unless arworkitem.field_hash.nil?
      fields = arworkitem.field_hash
      LOG.info(name){"params avant replace=#{fields['params'].inspect}"}
      # voir workitems_controller pour la construction de ce parametre
      # /activity : rien a faire
      # /documents/3 : document(3)
      # apres split:
      # 0 = ""
      # 1 = plmtype de l'objet, par exemple "document"
      # 2 = id de l'objet, par exemple 3
      #puts "PlmParticipant.consume:url="+url
      fields["params"].keys.each do |url|
        v = fields["params"][url]
        sv = v.split("#")
        # url non encore traitee
        if sv.size == 1
          sp = url.split("/")
          #puts "PlmParticipant.consume:sp "+sp.size.to_s+":"+sp[0].to_s
          if sp.size == 3 && sp[0] != url
            #puts "PlmParticipant.consume:"+sp[1]+"("+sp[1].size.to_s+"):"+sp[2]
            cls=sp[1].chop
            id=sp[2]
            #rel=sp[3]
            #puts "v.consume:cls=#{cls.inspect} id=#{id.inspect}"
            #link_=add_object(arworkitem, cls, id, relation_name)
            v = relation_name+"#"+v
            # verif si on peut appliquer la methode sur l'objet
            if relation_name=="applicable"
              obj = get_object(cls, id)
              unless obj.nil?
                tst=task+"_by_action?"
                if obj.respond_to?(tst)
                  if obj.send(tst)
                    fields["params"][url] = v
                  nb_applicable+=1
                  else
                    msg="Object #{url} could not be #{task} by action flow"
                    LOG.info(name){msg}
                  end
                else
                  msg=name+"Check Method #{tst} is missing for Object #{url}"
                  LOG.info(name){msg}
                # ce n'est pas bloquant, on executera la fonction quand meme dans execute
                #raise PlmProcessException.new(msg, 10004)
                end
              else
                msg=name+"Object #{url} does not exist"
                raise PlmProcessException.new(msg, 10005)
              end
            else
              fields["params"][url] = v
              nb_applicable+=1
            end
          end
        end
      # enlever le parametre pour ne pas le retrouver sur les taches suivantes
      ###fields["params"].delete(url)
      end
    end
    LOG.info(name){"params avant replace=#{fields['params'].inspect} nb_applicable=#{nb_applicable}"}
    #
    # on doit avoir au moins un objet sur lequel s'applique le processus
    #
    if step!= "exec" && relation_name == "applicable" && nb_applicable==0
      msg=name+"No applicable object for task(#{task}) and step(#{step})"
      raise PlmProcessException.new(msg, 10006)
    end
    arworkitem.replace_fields(fields) unless fields.nil?
  end

  def execute(task, alinks, arworkitem, relation_name)
    name="PlmParticipant.execute:"
    #puts name+arworkitem.wfid+":"+relation_name+":"+alinks.inspect
    if alinks.is_a?(Array)
    links = alinks
    else
    links = []
    links << alinks unless alinks.nil?
    end
    #puts name+arworkitem.wfid+":"+relation_name+":"+links.count.to_s+" links"
    links.each do |link|
    #puts name+"link="+link.ident
      father = get_object(link.father_plmtype, link.father_id)
      #puts name+"father="+father.wfid + "==" + arworkitem.wfid
      # bon wfid du pere
      unless father.nil? ||  father.wfid != arworkitem.wfid
        # bonne relation
        if link.relation.name == relation_name
          obj = get_object(link.child_plmtype, link.child_id)
          LOG.info(name){"avant exec:obj="+obj.inspect}
          unless obj.nil?
            obj.send(task)
            obj.save
            LOG.info(name){"apres exec:obj="+obj.inspect}
          else
            msg=name+"Object #{url} does not exist"
            raise PlmProcessException.new(msg, 10010)
          end
        else
        #LOG.info(name){"link.relation.name(#{link.relation.name}) != relation_name(#{relation_name})"}
        end
      else
      #LOG.info(name){"father(#{father.to_s})=nil or father.wfid(#{father.wfid}) != arworkitem.wfid(#{arworkitem.wfid})" }
      end
    end
  end

  def get_param(workitem, param, default=nil)
    ret=workitem.attributes["params"][param] unless workitem.attributes["params"][param].nil?
    if ret.nil?
    ret=default
    end
    ret
  end

end

