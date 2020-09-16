class ShipmentMailer < ApplicationMailer
  before_action {
    @shipment = params[:shipment].reload
    @copy = @shipment.copy
  }

  def pending_email_to_sender
    raise "Something's not right here!" unless @shipment.pending?

    mail(
      to: @shipment.from_user.email,
      subject: "Please ship your copy of #{@copy.book.title}"
    )
  end

  def pending_email_to_receiver
    raise "Something's not right here!" unless @shipment.pending?

    mail(
      to: @shipment.to_user.email,
      subject: "Your copy of #{@copy.book.title} will be on its way shortly"
    )
  end

  def shipping_email_to_sender
    raise "Something's not right here!" unless @shipment.shipping?

    mail(
      to: @shipment.from_user.email,
      subject: "Thanks for shipping your copy of #{@copy.book.title}"
    )
  end

  def shipping_email_to_receiver
    raise "Something's not right here!" unless @shipment.shipping?

    mail(
      to: @shipment.to_user.email,
      subject: "Your copy of #{@copy.book.title} is on its way"
    )
  end

  def did_not_ship_email_to_sender
    raise "Something's not right here!" unless @shipment.did_not_ship?

    mail(
      to: @shipment.from_user.email,
      subject: "We didn't receive your copy of #{@copy.book.title}"
    )
  end

  def did_not_ship_email_to_receiver
    raise "Something's not right here!" unless @shipment.did_not_ship?

    mail(
      to: @shipment.to_user.email,
      subject: "Your copy of #{@copy.book.title} was not shipped"
    )
  end
end
