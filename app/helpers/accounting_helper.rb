module AccountingHelper
  def accounting_transaction_badge(type)
    classes = {
      "income" => "bg-emerald-100 text-emerald-700 ring-emerald-200",
      "expense" => "bg-rose-100 text-rose-700 ring-rose-200",
      "salary" => "bg-indigo-100 text-indigo-700 ring-indigo-200",
      "commission" => "bg-violet-100 text-violet-700 ring-violet-200",
      "loan" => "bg-amber-100 text-amber-800 ring-amber-200",
      "investment" => "bg-blue-100 text-blue-700 ring-blue-200",
      "refund" => "bg-slate-100 text-slate-700 ring-slate-200",
      "adjustment" => "bg-fuchsia-100 text-fuchsia-700 ring-fuchsia-200"
    }.fetch(type.to_s, "bg-slate-100 text-slate-700 ring-slate-200")

    tag.span(type.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 #{classes}")
  end

  def invoice_status_badge(status)
    classes = {
      "draft" => "bg-slate-100 text-slate-700 ring-slate-200",
      "issued" => "bg-blue-100 text-blue-700 ring-blue-200",
      "paid" => "bg-emerald-100 text-emerald-700 ring-emerald-200",
      "refunded" => "bg-amber-100 text-amber-800 ring-amber-200",
      "cancelled" => "bg-rose-100 text-rose-700 ring-rose-200"
    }.fetch(status.to_s, "bg-slate-100 text-slate-700 ring-slate-200")

    tag.span(status.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 #{classes}")
  end

  def payroll_status_badge(status)
    classes = {
      "draft" => "bg-slate-100 text-slate-700 ring-slate-200",
      "finalized" => "bg-blue-100 text-blue-700 ring-blue-200",
      "paid" => "bg-emerald-100 text-emerald-700 ring-emerald-200"
    }.fetch(status.to_s, "bg-slate-100 text-slate-700 ring-slate-200")

    tag.span(status.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 #{classes}")
  end

  def money_from_cents(cents)
    number_to_currency(cents.to_i / 100.0, unit: "£")
  end

  def accounting_amount(amount_cents, transaction_type = nil)
    formatted = money_from_cents(amount_cents)
    if transaction_type.present?
      type = transaction_type.to_s
      if AccountingTransaction::INCOME_TYPES.include?(type)
        tag.span("+#{formatted}", class: "font-semibold text-emerald-700")
      else
        tag.span("-#{formatted}", class: "font-semibold text-rose-700")
      end
    else
      formatted
    end
  end
end
