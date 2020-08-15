class NotifyWaitlistJob < ApplicationJob
  queue_as :default

  def perform(book)
    book.reload
  end
end
