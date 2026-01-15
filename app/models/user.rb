# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer          default("reader")
#  username               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_username              (username) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles: reader (0), author (1), admin (2)
  enum role: { reader: 0, author: 1, admin: 2 }

  # Associations
  has_many :blogs, dependent: :destroy

  # Scopes for status
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # Instance methods for status
  def active?
    active
  end

  def inactive?
    !active
  end

  def deactivate!
    update(active: false)
  end

  def activate!
    update(active: true)
  end
end
