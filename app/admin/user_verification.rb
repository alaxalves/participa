ActiveAdmin.register UserVerification do
  filter :status , label: "Estado"
  menu :parent => "Users"
  config.sort_order = 'created_at_asc'
  permit_params do
    params = [:user_id, :processed_at, :publisher_id, :front_vatid, :back_vatid, :wants_card]
    params.push :status, :comment, if: proc {current_user.is_admin?}
    params
  end

  actions :index, :show, :edit, :update
  action_item "Procesar", only: :index do
    link_to "Procesar", params.merge(:action => :get_first_free)
  end

  scope "Todas", :all
  scope "Pendientes", :pending, default: true
  scope "Aceptadas", :accepted, if: proc {current_user.is_admin?}
  scope "Aceptadas por Email", :accepted_by_email, if: proc {current_user.is_admin?}
  scope "Con Problemas", :issues, if: proc {current_user.is_admin?}
  scope "Rechazadas", :rejected, if: proc {current_user.is_admin?}
  scope "Descartadas", :discarded, if: proc {current_user.is_admin?}

  filter :status , label: "Estado"
  filter :user_document_vatid, as: :string, label: "Número de documento"
  filter :user_first_name, as: :string, label: "Nombre"
  filter :user_last_name, as: :string, label: "Apellidos"
  filter :user_email, as: :string, label: "Email"

  collection_action :get_first_free, :method => :get do
    self.clean_redis_hash
    $redis = $redis || Redis::Namespace.new("podemos_queue_validator", :redis => Redis.new)

    ids = $redis.hkeys(:processing)
    verification = UserVerification.pending.where.not(id: ids).first
    if verification
      $redis.hset(:processing,verification.id,{author_id: current_user.id,locked_at: DateTime.now.utc.strftime("%d/%m/%Y %H|%M")})
      redirect_to edit_admin_user_verification_path(verification.id)
    else
      redirect_to(admin_user_verifications_path, flash: {warning: "No hay Usuarios que Verificar en Este momento. Muchisimas Gracias por tu colaboración. Intentalo más tarde." })
    end
  end

  index do |verification|
    column "persona" do |verification|
      verification.user.full_name
    end

    column "fecha petición", :created_at

    column "estado" do |verification|
      case UserVerification.statuses[verification.status]
        when UserVerification.statuses[:pending]
          status_tag("Pendiente", :warning)
        when UserVerification.statuses[:accepted]
          status_tag("Verificada", :ok)
        when UserVerification.statuses[:accepted_by_email]
          status_tag("Verificada por Email", :ok)
        when UserVerification.statuses[:issues]
          status_tag("con Problemas", :important)
        when UserVerification.statuses[:rejected]
          status_tag("Rechazada", :error)
        when UserVerification.statuses[:discarded]
          status_tag("Descartada", :error)
      end
    end

    #column "numDNI" do |verification|
    #  verification.user.document_vatid
    #end
    #column "DNI" do |verification|
    #  image_tag images_user_verification_path(id:verification.id,attachment:"front_vatid", filename:verification.front_vatid_file_name, size: "150x150")
    #end

    actions defaults: false do |verification|
      #link_to t("procesar"), edit_admin_user_verification_path(verification.id)
      #link_to "Procesar", get_first_free_path
    end
  end

  show do |verification|
    columns do
      column do
        render partial: "personal_data"
      end
      column class: "column attachments" do
        [:front, :back].each do |attachment|
          div class: "attachment" do
            a class: "preview", target: "_blank", href: view_image_admin_user_verification_path(user_verification, attachment: attachment, size: :original) do
              image_tag view_image_admin_user_verification_path(user_verification, attachment: attachment, size: :thumb)
            end
            div class: "rotate" do
              span "ROTAR"
              [0, 90, 180, 270].reverse.each do |degrees|
                a class: "degrees-#{degrees}", href: rotate_admin_user_verification_path(user_verification, attachment: attachment, degrees: degrees), "data-method" => :patch do
                  fa_icon "id-card-o"
                end
              end
            end
          end
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
            f.input :status, :label => "Estado", :as => :radio, :collection => current_user.is_admin? ? {
                "Pendiente": UserVerification.statuses.keys[ UserVerification.statuses[:pending]],
                "Aceptado": UserVerification.statuses.keys[ UserVerification.statuses[:accepted]],
                "Con problemas": UserVerification.statuses.keys[ UserVerification.statuses[:issues]],
                "Rechazado": UserVerification.statuses.keys[ UserVerification.statuses[:rejected]]} : {
                "Pendiente": UserVerification.statuses.keys[ UserVerification.statuses[:pending]],
                "Aceptado": UserVerification.statuses.keys[ UserVerification.statuses[:accepted]],
                "Con problemas": UserVerification.statuses.keys[ UserVerification.statuses[:issues]]}
            f.input :comment, :label => "Comentarios", as: :text, :input_html => {:rows => 2}
          end
          f.actions
        end
      end
      column class: "column attachments" do
        more_pending = resource.user.user_verifications.not_discarded
        if more_pending.any? { |verification| verification!=resource }
          div class: "flash flash_error" do
            "ATENCIÓN: Este usuario ha enviado varias solicitudes de verificación. Si se acepta esta solicitud, se descartará el resto."
          end
          table_for more_pending do
            column "fecha creación", :created_at
            column "estado" do |verification|
              t("podemos.user_verification.status.#{verification.status}")
            end
            column :descartable?
            column do |verification|
              if verification.id == resource.id
                span "actual"
              else
                link_to "procesar", edit_admin_user_verification_path(verification.id)
              end
            end
          end
        end

        [:front, :back].each do |attachment|
          div class: "attachment" do
            a class: "preview", target: "_blank", href: view_image_admin_user_verification_path(user_verification, attachment: attachment, size: :original) do
              image_tag view_image_admin_user_verification_path(user_verification, attachment: attachment, size: :thumb)
            end
            div class: "rotate" do
              span "ROTAR"
              [0, 90, 180, 270].reverse.each do |degrees|
                a class: "degrees-#{degrees}", href: rotate_admin_user_verification_path(user_verification, attachment: attachment, degrees: degrees), "data-method" => :patch do
                  fa_icon "id-card-o"
                end
              end
            end
          end
        end
      end
    end
  end

  member_action :rotate, method: :patch do
    verification = UserVerification.find(params[:id])
    attachment = "#{params[:attachment]}_vatid"
    degrees = -params[:degrees].to_i
    verification.rotate[attachment] = degrees
    verification.send(attachment).reprocess!
    redirect_to :back
  end

  member_action :view_image do
    verification = UserVerification.find(params[:id])
    attachment = "#{params[:attachment]}_vatid"
    size = params[:size].to_sym
    send_file verification.send(attachment).path(size), disposition: 'inline'
  end

  # def get_first_free
  #   byebug
  #   $redis = $redis || Redis::Namespace.new("podemos_queue_validator", :redis => Redis.new)
  #   ids = $redis.hkeys(:processing)
  #   verification = UserVerification.pending.where.not(id: ids).first
  #   $redis.hset(:processing,:id,{author_id: current_user.id,locked_at: DateTime.now})
  #   if verification
  #     verification
  #   else
  #     redirect_to(index_admin_user_verification_path, flash: {warning: "No hay Usuarios que Verificar en Este momento. Muchisimas Gracias por tu colaboración. Intentalo más tarde." })
  #   end
  # end

  controller do

    def capture_redish_hash id
      if current_user.is_admin?

      end
    end

    def verification_active id
      $redis = $redis || Redis::Namespace.new("podemos_queue_validator", :redis => Redis.new)
      current_hash = $redis.hget(:processing,id)
      current_verification = UserVerification.find(id) if UserVerification.where(id: id).any?
      if current_verification && current_hash
        # convert hash in string to hash
        current_hash = current_hash.gsub(/[{}:]/,'').split(', ').map{|h| h1,h2 = h.split('=>'); {h1 => h2}}.reduce(:merge)
        current_hash = Hash[current_hash.map{ |k, v| [k.to_sym, v] }]
        # end convert hash in string to hash
        #current_user.id == current_hash[:author_id].to_i  && DateTime.now.utc < (current_hash[:locked_at].gsub(/[\"]/,'').gsub(/[|]/,':').to_datetime + Rails.application.secrets.user_verifications["time_to_expire_session"].minutes)
        DateTime.now.utc <= (current_hash[:locked_at].gsub(/[\"]/,'').gsub(/[|]/,':').to_datetime + Rails.application.secrets.user_verifications["time_to_expire_session"].minutes)
      else
        false
      end
    end

    def remove_redis_hash id
      $redis = $redis || Redis::Namespace.new("podemos_queue_validator", :redis => Redis.new)
      current = $redis.hget(:processing,id)
      $redis.hdel(:processing,id)
    end

    def clean_redis_hash

      $redis = $redis || Redis::Namespace.new("podemos_queue_validator", :redis => Redis.new)
      ids = $redis.hkeys :processing
      ids.each do |i|
        $redis.hdel(:processing, i) if !verification_active i
      end
    end

    def update
      if (current_user.verifier? or current_user.is_admin?) and verification_active(permitted_params[:id])
        super do |format|
          resource.user.user_verifications.discardable.each do |verification|
            verification.status = :discarded
            verification.save!
          end

          verification = UserVerification.find(permitted_params[:id])
          case UserVerification.statuses[verification.status]
            when UserVerification.statuses[:accepted]
              if current_user.is_admin? or current_user.verfier?
                u = User.find( verification.user_id )
                u.verified = true
                u.banned = false
                u.save
                UserVerificationMailer.on_accepted(verification.user_id).deliver_now
              end
            when UserVerification.statuses[:rejected]
              UserVerificationMailer.on_rejected(verification.user_id).deliver_now if current_user.is_admin?
          end

          remove_redis_hash verification.id
        end
      elsif (current_user.verifier? or current_user.is_admin?) and !verification_active(permitted_params[:id])
        redirect_to(admin_user_verifications_path,flash: {error: "Has perdido el derecho de Verificar este usuario. Pulsa en Procesar para verificar uno nuevo." })
      end
    end
  end
end

