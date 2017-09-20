# order-processing
# Considerations

Just realized I may have approached this incorrectly. I thought the trades would be executed immediately, not that my quote would be added to the bid/ask side. This led to a solution that grabbed the 10 the orders willing to pay ~4k for .01 BTC instead of looking at all the people selling 1 BTC and trying to find a 'best price' there. 

I wanted to split the concerns of managing data from generating a quote. Data can come in batches, there can be multiple sources, third party sources may need to be formatted so all other services can use it, etc.. I started to play around with adding Resque workers to parallelize my digestion of the websocket stream but my computer started heating up and it seemed better to focus on the problem over spinning up servers to handle more workers for the jobs(kudos on the quick stream!).

My quote generation algorithm uses dynamic programming(DP) to find the minimal distance between a combination of orders and the requested amount. If there is a tie in the distance, the best profit for you is taken. This gets a bit odd, as this approach allows you to sell `1` BTC to 10 `0.1` bids for BTC, each costing ~4k(data taken from the level 2 websocket stream). Likely means I missed some details(sorry!), would be good for future devs to have a dedicated data set of inputs and outputs. Even something small like 10 or 15 bids/asks. The generator ended up using the 'best 50' supplied by the GDAX polling API because it was too slow with the full stream, but I've left it in as I was actively working on optimizations. One of them that Has been included is avoiding many of the steps required when updating the increment of a DP problem. Instead, we store the previous results in a dynamic hash of ranges, and compare ranges only when the changes are likely to occur. Still too slow for the full stream, but progress!

What would I have done with more time:

Made an easy to use client form w/ react and webpack
Dockerized the services
Put them in a vagrant instance
Tests for days


# How to start

Add the necessary gdax auth data to `./services/data_manager/config/config.yml`
Install ruby(latest stable)
Install bundler(latest default)
run `bundle install` to install gems
run `foreman start`

access Quote Generator service via localhost:8180
access Data Manager service via localhost:8181


# Services

##

### Data Manager

#### Technology

Sinatra app, thin rack server, faye websocket, eventmachine for processing events

#### Endpoints

GET `/products/<product_id>/`

###### Returns:

Attempts to return the inverse of the product id if no matching product id is found

fields from the GDAX [get-product](https://docs.gdax.com/#get-products) endpoint.

`order-book` (Object) - If `best=50` is added as a query string, returns the level 2 order book provided by (see GDAX [get-product-order-book](https://docs.gdax.com/#get-product-order-book). Otherwise it returns a current snapshot of the GDAX [level 2 websocket channel](https://docs.gdax.com/#the-code-classprettyprintlevel2code-channel)

##

### Quote Generator


#### Technology

Sinatra app, thin rack server

#### Endpoints

POST `/quote`

###### Accepts:

`action  ` (String) - either 'buy' or 'sell'

`base_currency  ` (String) - The currency to be bought or sold

`quote_currency  ` (String) - The currency to quote the price in

`amount  ` (String) - The amount of the base currency to be traded

###### Returns:

`price` (String) - The per-unit cost of the base currency. If the `base_currency` matches a GDAX product, the unit size will be the `base_min_size` of that product. If it matches the base it will be the `quote_increment`. See [get-product](https://docs.gdax.com/#get-products) for field definitions.

`cost` (String) - Total quantity of the `quote_currency`

`currency` (String) - Quote currency
