class BooksController < ApplicationController
  load_and_authorize_resource

  def index
    @books = @books.order(copies_available: :desc)
  end

  def list_copy; end

  def post_list_copy
    authorize! :create, Copy

    e = Edition.find_by!(id: params[:edition_id], book: @book)
    Copy.create!(
      user: current_user,
      edition: e,
      status: @book.waitlist? ? :pending_waitlist_match : :available
    )

    NotifyWaitlistJob.perform_later(@book) if @book.waitlist?
  end

  # Rewrite this to be two separate actions: reserving a copy and joining waitlist
  def reserve_copy
    if @book.waitlist?
      redirect_to join_waitlist_path(book: @book), notice: 'This book is now waitlisted.'
      return
    end
  end

  def post_reserve_copy
    # TODO: Test this method
    if @book.waitlist?
      redirect_to join_waitlist_path(book: @book), notice: 'This book is now waitlisted.'
      return
    end

    authorize! :reserve, Copy

    Copy.reserve_and_ship_to_user!(@book, current_user, params[:payment_method_id])

    redirect_to books_path, notice: 'Success! We will email you when your book is on its way!'
  end

  def join_waitlist
    unless @book.waitlist?
      redirect_to reserve_copy_path(book: @book), notice: 'This book is now available!'
      nil
    end
  end

  def post_join_waitlist
    authorize! :join_waitlist, @book

    unless @book.waitlist?
      redirect_to reserve_copy_path(book: @book), notice: 'This book is now available!'
      nil
    end
  end
end
