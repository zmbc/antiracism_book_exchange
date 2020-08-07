class BooksController < ApplicationController
  def index
    @books = Book.order(:copies_available).all
  end
end
