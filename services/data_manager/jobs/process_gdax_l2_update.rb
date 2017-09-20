require './helpers/gdax_data_parsers'

class ProcessGdaxL2Update
  include GdaxDataParsers

  @queue = :l2_update

  def self.perform(product, update_data)
    update_data[:changes].each do |change|
      side_key, price, size = change
      
      if size.to_f.zero?
        product[:order_book][side_key.to_sym].delete(price)
      else
        product[:order_book][side_key.to_sym][price] = size
      end
    end
  end
end
