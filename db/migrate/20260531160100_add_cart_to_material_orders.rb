class AddCartToMaterialOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :material_orders, :cart, type: :uuid, foreign_key: true
  end
end
