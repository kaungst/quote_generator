require 'bigdecimal'
require 'json' 
require 'active_support/core_ext/hash/keys'

class QuoteGenerator
  class QuoteState
    def initialize(**kwargs)
      kwargs.each { |k, v| self.send("#{k}=", v) }
    end

    attr_accessor :target, :increment, :max_range, :comparator, :matches,
      :orders, :previous_order_index, :current_order, :previous_matches, 
      :last_match, :last_match_index, :first_altered_start, :best_distance
  end

  def initialize(data_client = nil)
    raise ArgumentError.new('Missing data client') if data_client.nil?
    self.data_client = data_client
  end

  def quote(action:, base_currency:, quote_currency:, amount:)
    trade_data = data_client.product(base_currency, quote_currency, best: 50)
    amount = number(amount)

    if base_currency == trade_data[:quote_currency]
      reverse = false
      increment = number(trade_data[:quote_increment])
      unit_size = increment
        
      if action == 'buy'
        comparator = :min
        orders = trade_data[:order_book][:bids]
      else
        comparator = :max
        orders = trade_data[:order_book][:asks]
      end
    else
      reverse = true
      unit_size = number(trade_data[:base_min_size])

      if action == 'buy'
        comparator = :min
        orders = trade_data[:order_book][:asks]
      else
        comparator = :max
        orders = trade_data[:order_book][:bids]
      end

      increment = find_increment(orders.map { |order| order[1] })
    end

    matching_orders = find_matching_orders(number(amount), increment, orders, comparator, reverse)
    
    return {} if matching_orders.empty?

    total_weight = 0
    weighted_prices = matching_orders.map do |order|
      total_weight += order[:weight]
      order[:weight] * order[:value]
    end.sum

    price = ((weighted_prices/total_weight) * unit_size) / increment

    {
      price: price.to_f.to_s,
      total: (price * (amount / unit_size)).to_f.to_s,
      currency: quote_currency
    }
  end

  private 

  attr_accessor :data_client, :quote_state

  def find_increment(numbers)
    specificity = 1

    numbers.each do |number|
      point_index = number.index('.')
      next if point_index.nil?

      specificity = [specificity, number.length - point_index - 1].max
    end

    number(1) / number(10**specificity)
  end

  def format_orders(orders, comparator, increment, reverse)
    formatted_orders = []
    orders.each do |order| 
      weight = number(order[0])
      value = number(order[1])
      count = order[2]

      weight, value = [value, weight] if reverse 

      Array.new(count) do 
        formatted_orders << { weight: weight, value: value, steps: weight/increment } 
      end
    end
    
    count = -1

    formatted_orders.sort_by! { |a| [a[:weight], a[:value]] }

    formatted_orders.each do |order|
      count += 1
      order[:index] = count
    end

    formatted_orders
  end 

  def initialize_matches(quote_state)
    quote_state.matches = Hash.new { |h, k| h[k] = {} }

    current_order = quote_state.orders.first

    quote_state.matches[current_order[:index]][number(0)] = { 
      distance: quote_state.target,
      value: number(0), 
      range: { start: number(0), end: current_order[:steps] - number(1) }, 
      order_path: { include_current: false, previous_step: number(0) }
    }

    quote_state.matches[current_order[:index]][current_order[:steps]] = { 
      distance: (quote_state.target - current_order[:steps]).abs,
      value: current_order[:value], 
      range: { start: current_order[:steps], end: quote_state.max_range },
      order_path: { include_current: true, previous_step: number(0) }
    }
  end

  def update_previous_matches(quote_state)
    previous_matches = 
      quote_state.matches[quote_state.previous_order_index].to_a.sort_by { |a| a[0] }

    quote_state.best_distance = (quote_state.target - previous_matches[-1][0]).abs

    last_match_index = 0
    last_match_start, last_match_data = previous_matches[last_match_index]

    until last_match_data[:range][:end] > quote_state.current_order[:steps] ||
          last_match_data[:range][:end] == quote_state.max_range

      order_path = { include_current: false, previous_step: last_match_start }

      quote_state.matches[quote_state.current_order[:index]][last_match_start] = 
        last_match_data.merge(order_path: order_path)

      last_match_index += 1
      last_match_start, last_match_data = previous_matches[last_match_index]
    end

    quote_state.previous_matches = previous_matches
    quote_state.last_match_index = last_match_index
  end

  def process_new_combinations(quote_state)
    last_match_start, last_match_data = quote_state.previous_matches[quote_state.last_match_index]
    target = quote_state.target
    previous_distance = quote_state.target + quote_state.max_range

    for possible_combination in quote_state.previous_matches
      possible_combination_start, possible_combination_data = possible_combination
      combined_steps = quote_state.current_order[:steps] + possible_combination_data[:range][:start]
      distance = (target - combined_steps).abs

      break if distance > previous_distance || 
               combined_steps >= last_match_data[:range][:end]

      next if combined_steps < last_match_data[:range][:start]

      combined_value = quote_state.current_order[:value] + possible_combination_data[:value]
      use_order = if distance != last_match_data[:distance]
                    distance < last_match_data[:distance]
                  else
                    self.send(quote_state.comparator, combined_value, last_match_data[:value])
                  end

      if use_order
        value = combined_value
        order_path = { 
          include_current: true, previous_step: possible_combination_start
        }
      else
        distance = last_match_data[:distance]
        value = last_match_data[:value]
        order_path = { include_current: false, previous_step: last_match_start }
      end

      quote_state.matches[quote_state.current_order[:index]][combined_steps] = {
        distance: distance,
        value: value, 
        range: { start: combined_steps },
        order_path: order_path
      }

      previous_distance = distance
    end
  end

  def initialized_quote_state(target, increment, orders, comparator, reverse)
    orders = format_orders(orders, comparator, increment, reverse)
    return if orders.empty?

    self.quote_state = QuoteState.new(
      target: target/increment, 
      increment: increment, 
      orders: orders, 
      comparator: comparator, 
      max_range: orders.sum { |order| order[:steps] },
    ).tap do |quote_state|
      initialize_matches(quote_state)
      quote_state.previous_order_index = quote_state.orders[0][:index]
    end

    quote_state
  end

  def find_matching_orders(target, increment, orders, comparator, reverse)
    quote_state = initialized_quote_state(target, increment, orders, comparator, reverse)
    return [] if quote_state.nil?

    quote_state.orders.drop(1).each_with_index do |order, index|
      quote_state.current_order = order

      update_previous_matches(quote_state)

      until quote_state.last_match_index == quote_state.previous_matches.length
        process_new_combinations(quote_state)
        quote_state.last_match_index += 1
      end

      cleanup_ranges(quote_state)

      quote_state.previous_order_index += 1
    end

    relevant_orders(quote_state)
  end

  def cleanup_ranges(quote_state)
    current_orders = quote_state.matches[quote_state.current_order[:index]]
    current_order_keys = current_orders.keys.sort

    current_orders[number(0)][:range][:end] = 
      current_orders[current_order_keys[1]][:range][:start] - number(1) 

    for key_index in 1...current_order_keys.length
      end_range = if key_index + 1 == current_order_keys.length
                    quote_state.max_range
                  else
                    current_orders[current_order_keys[key_index + 1]][:range][:start]   
                  end

      end_range -= number(1) if key_index == 0

      current_orders[current_order_keys[key_index]][:range][:end] = end_range
    end
  end

  def relevant_orders(quote_state)
    result = []
    matches = quote_state.matches
    order_index = quote_state.previous_order_index
    order_path = matches[order_index][matches[order_index].keys.max][:order_path]
    
    until order_index < 0 
      result << quote_state.orders[order_index] if order_path[:include_current]
      break if order_path[:previous_step] == 0

      order_index -= 1
      order_path = matches[order_index][order_path[:previous_step]][:order_path]
    end

    result
  end

  def min(a, b)
    a < b
  end

  def max(a, b)
    a > b
  end

  def number(value)
    BigDecimal.new(value)
  end
end
