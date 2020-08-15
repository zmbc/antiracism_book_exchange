class BooksController < ApplicationController
  load_and_authorize_resource

  def index
    @books = @books.order(copies_available: :desc)
  end

  def list_copy; end

  def post_list_copy
    authorize! :create, Copy

    e = Edition.find(params[:edition_id])
    redirect_to request.path, alert: 'Please try again.' unless e.book == @book

    @book.recalculate_copies_and_waitlist
    Copy.create!(
      user: current_user,
      edition: e,
      status: @book.waitlist? ? :pending_waitlist_match : :available
    )

    NotifyWaitlistJob.perform_later(@book) if @book.waitlist?
  end

  # Rewrite this to be two separate actions: reserving a copy and joining waitlist
  def reserve_copy; end

  def post_reserve_copy
    authorize! :reserve, Copy
  end
end
