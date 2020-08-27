class WaitlistEntry < ApplicationRecord
  belongs_to :user
  belongs_to :book
  has_one :copy, required: false

  validates_presence_of :notified_at, if: :copy?
  validate :book_matches

  protected

  def book_matches
    errors.add(:base, 'Copy must be of the correct book') if copy.present? && copy.book != book
  end
end
