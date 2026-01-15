class AddPublishedToBlogs < ActiveRecord::Migration[7.1]
  def change
    add_column :blogs, :published, :boolean, default: false, null: false
  end
end
