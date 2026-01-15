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
require "test_helper"

class BlogTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
