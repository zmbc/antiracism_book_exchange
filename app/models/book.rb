class Book < ApplicationRecord
  has_many :editions

  validates_presence_of :title, :author, :year, :copies_available,
                        :waitlist_length

  def waitlist?
    waitlist_length.positive?
  end

  def recalculate_copies_and_waitlist
    self.copies_available = copies.where(status: :available).count
    if copies_available.zero?
      # Calculate waitlist length
    else
      self.waitlist_length = 0
    end
  end
end
