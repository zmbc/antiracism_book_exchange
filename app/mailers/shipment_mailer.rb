class ShipmentMailer < ApplicationMailer
  def please_ship_email
    @shipment = params[:shipment].reload
    raise "Something's not right here!" unless @shipment.pending?

    @copy = @shipment.copy
    mail(
      to: @shipment.from_user.email,
      subject: "Please ship your copy of #{@copy.book.title}"
    )
  end

  def reservation_confirmation_email
    @shipment = params[:shipment].reload
    raise "Something's not right here!" unless @shipment.pending?

    @copy = @shipment.copy
    mail(
      to: @shipment.to_user.email,
      subject: "Your copy of #{@copy.book.title} will be on its way shortly"
    )
  end
end
