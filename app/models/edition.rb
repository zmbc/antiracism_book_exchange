class Edition < ApplicationRecord
  belongs_to :book

  validates_presence_of :name, :width_inches, :length_inches,
                        :height_inches, :weight_ounces
end
