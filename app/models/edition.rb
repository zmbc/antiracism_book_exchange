class Edition < ApplicationRecord
  belongs_to :book
  has_many :copies

  validates_presence_of :name, :width_inches, :length_inches,
                        :height_inches, :weight_ounces

  def create_easypost_parcel
    EasyPost::Parcel.create(
      width: width_inches,
      length: length_inches,
      height: height_inches,
      weight: weight_ounces
    )
  end
end
