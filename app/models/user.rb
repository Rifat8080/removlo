class User < ApplicationRecord
  ROLES = {
    admin: "admin",
    staff: "staff",
    customer: "customer"
  }.freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, ROLES, default: :customer, validate: true

  before_validation :set_default_role, on: :create

  private

  def set_default_role
    self.role ||= "customer"
  end
end
