module Admin
  class QuotationNotesController < BaseController
    before_action :set_quotation
    before_action :set_note, only: %i[update destroy]

    def create
      note = @quotation.quotation_notes.new(note_params.merge(user: current_user))
      authorize! :create, note
      note.save!
      notify_note_recipients(note)
      redirect_to admin_quotation_path(@quotation), notice: "Note added."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      authorize! :update, @note
      @note.update!(note_params)
      notify_note_recipients(@note)
      redirect_to admin_quotation_path(@quotation), notice: "Note updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      authorize! :destroy, @note
      @note.destroy
      redirect_to admin_quotation_path(@quotation), notice: "Note deleted."
    end

    private

    def set_quotation
      @quotation = Quotation.find(params[:quotation_id])
    end

    def set_note
      @note = @quotation.quotation_notes.find(params[:id])
    end

    def note_params
      params.require(:quotation_note).permit(:content, :internal)
    end

    def notify_note_recipients(note)
      if note.internal?
        ::ActivityNotifier.call(
          recipients: User.operators,
          event_type: "quotation.internal_note",
          title: "Internal note added",
          body: "An internal note was added to #{@quotation.reference}.",
          url: admin_quotation_path(@quotation),
          actor: current_user,
          notifiable: @quotation
        )
      else
        ::ActivityNotifier.call(
          recipients: @quotation.customer,
          event_type: "quotation.customer_note",
          title: "Message from Removlo",
          body: "A message was added to #{@quotation.reference}.",
          url: quotation_path(@quotation),
          actor: current_user,
          notifiable: @quotation
        )
      end
    end
  end
end
