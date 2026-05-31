module Accounting
  class SeedCategories
    DEFAULTS = [
      { name: "Moving services", slug: "moving-services", category_type: :income, description: "Revenue from customer moves" },
      { name: "Packing materials sales", slug: "packing-materials-sales", category_type: :income, description: "Revenue from material shop orders" },
      { name: "Salaries", slug: "salaries", category_type: :expense, description: "Staff and admin payroll" },
      { name: "Commissions", slug: "commissions", category_type: :expense, description: "Driver and sales commissions" },
      { name: "Fuel", slug: "fuel", category_type: :expense, description: "Vehicle fuel costs" },
      { name: "Rent", slug: "rent", category_type: :expense, description: "Office and depot rent" },
      { name: "Marketing", slug: "marketing", category_type: :expense, description: "Advertising and promotions" },
      { name: "Vehicle maintenance", slug: "vehicle-maintenance", category_type: :expense, description: "Fleet servicing and repairs" },
      { name: "Loan repayment", slug: "loan-repayment", category_type: :expense, description: "Loan principal and interest" },
      { name: "Investments", slug: "investments", category_type: :income, description: "Capital investments received" },
      { name: "Refunds", slug: "refunds", category_type: :expense, description: "Customer refunds issued" },
      { name: "Tax", slug: "tax", category_type: :expense, description: "Tax payments" },
      { name: "Miscellaneous", slug: "miscellaneous", category_type: :both, description: "Other income and expenses" }
    ].freeze

    def self.call
      DEFAULTS.each do |attrs|
        AccountingCategory.find_or_create_by!(slug: attrs[:slug]) do |category|
          category.assign_attributes(attrs)
        end
      end
    end
  end
end
