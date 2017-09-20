module GdaxDataParsers
  PRODUCT_DELIMITER = '-'.freeze

  def generate_product_id(base_currency, quote_currency)
    "#{base_currency}#{PRODUCT_DELIMITER}#{quote_currency}"
  end

  def parse_product_id(product_id)
    product_id.split(PRODUCT_DELIMITER)
  end
end
