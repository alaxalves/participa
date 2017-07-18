ActiveAdmin.register UserVerification do
  filter :status , label: "Estado"
  menu :parent => "Users"
  config.sort_order = 'created_at_asc'
  permit_params do
    params = [:user_id, :processed_at, :publisher_id, :front_vatid, :back_vatid, :wants_card]
    params.push :status, :comment, if: proc {current_user.is_admin?}
    params
  end

  #actions :all, except: [:new, :create, :destroy]
  actions :index, :show, :edit, :update

  scope "Todas", :all
  scope "Pendientes", :pending
  scope "Aceptadas", :accepted, if: proc {current_user.is_admin?}
  scope "Con Problemas", :issues, if: proc {current_user.is_admin?}
  scope "Rechazadas", :rejected, if: proc {current_user.is_admin?}

  index do |verification|
    column "persona" do |verification|
      verification.user.full_name
    end

    column "fecha petición", :created_at

    column "estado" do |verification|

      case verification.status
        when 0
          status_tag("Pendiente", :warning)
        when 1
          status_tag("Verificado", :ok)
        when 2
          status_tag("con Problemas", :important)
        when 3
          status_tag("Rechazado", :error)
      end
    end

    #column "numDNI" do |verification|
    #  verification.user.document_vatid
    #end
    #column "DNI" do |verification|
    #  image_tag images_user_verification_path(id:verification.id,attachment:"front_vatid", filename:verification.front_vatid_file_name, size: "150x150")
    #end

    actions defaults: false do |verification|
      link_to t("procesar"), edit_admin_user_verification_path(verification.id)
    end
  end

  show do |verification|
    columns do
      column do
        render partial: "personal_data"
      end

      column do
        span do
          image_tag images_user_verification_path(id:verification.id,attachment:"front_vatid", filename:verification.front_vatid_file_name.match(/[^\/.]*/), size: :thumb)
        end
        span do
          image_tag images_user_verification_path(id:verification.id,attachment:"back_vatid", filename:verification.back_vatid_file_name.match(/[^\/.]*/), size: :thumb)
        end
      end
    end
  end

  form title: "Verificar Identidad", decorate: true do |f|
    columns do
      column do
        render partial: "personal_data"
        panel "verificar" do
          f.inputs :class => "remove-padding-top" do
            f.input :status, :label => "Estado", :as => :radio, :collection => current_user.is_admin? ? {"Pendiente":0, "Aceptado":1, "Con problemas":2, "Rechazado":3} : {"Pendiente":0, "Aceptado":1, "Con problemas":2}
            f.input :comment, :label => "Comentarios", as: :text, :input_html => {:rows => 2}
          end
          f.actions
        end
      end
      column do
          span do
            image_tag images_user_verification_path(id:user_verification.id,attachment:"front_vatid", filename:user_verification.front_vatid_file_name.match(/[^\/.]*/), size: :thumb)
          end
          span do
            image_tag images_user_verification_path(id:user_verification.id,attachment:"back_vatid", filename:user_verification.back_vatid_file_name.match(/[^\/.]*/), size: :thumb)
          end
      end
    end
  end

  controller do
    def update
      if current_user.verifier? or current_user.is_admin?
        super do |format|
          verification = UserVerification.find(params[:id])
          UserVerificationMailer.on_accepted(verification.user_id).deliver_now if verification.status == 1 and (current_user.is_admin? or current_user.verfier?)
          UserVerificationMailer.on_rejected(verification.user_id).deliver_now if verification.status == 3 and current_user.is_admin?
        end
      end
    end
  end
end

