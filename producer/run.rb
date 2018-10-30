STDOUT.sync = true # Output to STDOUT immediately

require 'bunny'
require 'securerandom'
require 'json'
require 'bigdecimal'
require 'bigdecimal/util'

# Start a communication session with RabbitMQ
conn = Bunny.new('amqp://mq:5672')
begin
  conn.start
rescue # RabbitMQ is not ready
  puts 'Cannot connect, retrying...'
  sleep(3)
  retry
end

ch = conn.create_channel
q  = ch.queue('neat-txn')

producer_id = SecureRandom.uuid

while true
  transaction_id = SecureRandom.uuid
  amount = ((SecureRandom.random_number - 0.5) * 200).to_d.round(2) # Random amount between -$100 - $100
  q.publish({
    producer_id: producer_id,
    account_id: SecureRandom.random_number(3) + 1,
    transaction_id: transaction_id,
    amount: amount
  }.to_json)
  sleep(SecureRandom.random_number(4) + 1) # Sleep 1-5 seconds
end

# close the connection
conn.stop
