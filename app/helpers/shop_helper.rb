module ShopHelper
  include QuotationsHelper

  def material_order_status_badge(status)
    classes = {
      "pending" => "bg-slate-100 text-slate-700 ring-slate-200",
      "paid" => "bg-emerald-100 text-emerald-700 ring-emerald-200",
      "processing" => "bg-blue-100 text-blue-700 ring-blue-200",
      "ready_for_collection" => "bg-amber-100 text-amber-800 ring-amber-200",
      "dispatched" => "bg-indigo-100 text-indigo-700 ring-indigo-200",
      "delivered" => "bg-green-100 text-green-700 ring-green-200",
      "collected" => "bg-green-100 text-green-700 ring-green-200",
      "cancelled" => "bg-rose-100 text-rose-700 ring-rose-200",
      "refunded" => "bg-slate-100 text-slate-700 ring-slate-200"
    }.fetch(status.to_s, "bg-slate-100 text-slate-700 ring-slate-200")

    tag.span(status.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 #{classes}")
  end

  def shop_payment_badge(status)
    classes = {
      "unpaid" => "bg-amber-100 text-amber-800 ring-amber-200",
      "paid" => "bg-emerald-100 text-emerald-700 ring-emerald-200",
      "refunded" => "bg-slate-100 text-slate-700 ring-slate-200",
      "failed" => "bg-rose-100 text-rose-700 ring-rose-200"
    }.fetch(status.to_s, "bg-slate-100 text-slate-700 ring-slate-200")

    tag.span(status.to_s.humanize, class: "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ring-1 #{classes}")
  end
end
