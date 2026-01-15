# == Schema Information
#
# Table name: blogs
#
#  id          :bigint           not null, primary key
#  description :text
#  published   :boolean
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_blogs_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Blog < ApplicationRecord
  belongs_to :user

  validates :title, presence: true
  validates :description, presence: true

  # Scopes for querying by status
  scope :published, -> { where(published: true) }
  scope :drafts, -> { where(published: false) }

  # Instance methods for status checking
  def draft?
    !published
  end

  def published?
    published
  end
end
