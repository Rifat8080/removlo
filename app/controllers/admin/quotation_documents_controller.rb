module Admin
  class QuotationDocumentsController < BaseController
    before_action :set_quotation
    before_action :set_document, only: %i[update destroy]

    def create
      document = @quotation.quotation_documents.new(document_params)
      authorize! :create, document
      document.save!
      notify_customer("Document added", "A document was added to #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Document added."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def update
      authorize! :update, @document
      @document.update!(document_params)
      notify_customer("Document updated", "A document was updated on #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Document updated."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_quotation_path(@quotation), alert: e.record.errors.full_messages.to_sentence
    end

    def destroy
      authorize! :destroy, @document
      @document.destroy
      notify_customer("Document removed", "A document was removed from #{@quotation.reference}.")
      redirect_to admin_quotation_path(@quotation), notice: "Document removed."
    end

    private

    def set_quotation
      @quotation = Quotation.find(params[:quotation_id])
    end

    def set_document
      @document = @quotation.quotation_documents.find(params[:id])
    end

    def document_params
      params.require(:quotation_document).permit(:title, :document_type, :url, :notes)
    end

    def notify_customer(title, body)
      ::ActivityNotifier.call(
        recipients: @quotation.customer,
        event_type: "quotation.document",
        title: title,
        body: body,
        url: quotation_path(@quotation),
        actor: current_user,
        notifiable: @quotation
      )
    end
  end
end
