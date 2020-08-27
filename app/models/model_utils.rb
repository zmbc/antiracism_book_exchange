module ModelUtils
  module_function

  def easypost_rate_to_total_price_cents(ep_rate)
    rate_cents = ep_rate.rate.to_d * 100
    add_cc_processing_fees(rate_cents)
  end

  def add_cc_processing_fees(amount_cents)
    # https://support.stripe.com/questions/passing-the-stripe-fee-on-to-customers
    ((amount_cents + 30) / (1 - 0.029)).ceil
  end
end
