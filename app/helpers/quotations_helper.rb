module QuotationsHelper
  def quotation_status_badge(status)
    classes = {
      "requested" => "bg-violet-100 text-violet-700 ring-violet-200",
      "draft" => "bg-slate-100 text-slate-700 ring-slate-200",
      "quoted" => "bg-blue-100 text-blue-700 ring-blue-200",
      "negotiating" => "bg-fuchsia-100 text-fuchsia-700 ring-fuchsia-200",
      "accepted" => "bg-emerald-100 text-emerald-700 ring-emerald-200",
      "rejected" => "bg-rose-100 text-rose-700 ring-rose-200",
      "scheduled" => "bg-indigo-100 text-indigo-700 ring-indigo-200",
      "in_progress" => "bg-amber-100 text-amber-800 ring-amber-200",
      "completed" => "bg-green-100 text-green-700 ring-green-200",
      "cancelled" => "bg-slate-200 text-slate-700 ring-slate-300"
    }.fetch(status.to_s, "bg-slate-100 text-slate-700 ring-slate-200")

    tag.span(status.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 #{classes}")
  end

  def quotation_payment_badge(status)
    classes = {
      "unpaid" => "bg-rose-100 text-rose-700 ring-rose-200",
      "deposit_paid" => "bg-amber-100 text-amber-800 ring-amber-200",
      "paid" => "bg-emerald-100 text-emerald-700 ring-emerald-200",
      "refunded" => "bg-slate-100 text-slate-700 ring-slate-200"
    }.fetch(status.to_s, "bg-slate-100 text-slate-700 ring-slate-200")

    tag.span(status.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 #{classes}")
  end

  def money_from_cents(cents)
    number_to_currency(cents.to_i / 100.0, unit: "£")
  end

  def customer_workflow_steps
    [
      [:request_quote, "Request quote"],
      [:receive_quote, "Receive quote"],
      [:accept_quote, "Accept quote"],
      [:pay_deposit, "Pay deposit"],
      [:track_booking, "Track booking"]
    ]
  end

  def customer_workflow_step_index(step)
    customer_workflow_steps.index { |key, _| key == step.to_sym } || 0
  end
end
