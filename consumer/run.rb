STDOUT.sync = true # Output to STDOUT immediately

require 'sinatra'

class Consumer
  require 'bunny'
  require 'securerandom'
  require 'json'
  require 'bigdecimal'
  require 'bigdecimal/util'

  def run
    # Initial balance
    accounts = {
      1 => { balance: (SecureRandom.random_number * 1000).to_d.round(2) },
      2 => { balance: (SecureRandom.random_number * 1000).to_d.round(2) },
      3 => { balance: (SecureRandom.random_number * 1000).to_d.round(2) },
    }

    transactions = {}

    # Start a communication session with RabbitMQ
    conn = Bunny.new('amqp://mq:5672')
    begin
      conn.start
    rescue # RabbitMQ is not ready
      puts 'Cannot connect, retrying...'
      sleep(3)
      retry
    end

    puts "Consumer started"
    puts "Starting Balance:"
    accounts.each do |account_id, account|
      puts "Account ID: #{account_id}, Balance: #{account[:balance].to_f}"
    end
    begin
      ch = conn.create_channel
      q  = ch.queue('neat-txn')

      while true
        # fetch a message from the queue
        q.subscribe(manual_ack: true) do |delivery_info, metadata, payload|
          txn = JSON.parse(payload)
          account = accounts[txn['account_id']]
          raise "Unknown Account ID: #{txn['account_id']}" if account.nil? # or handle gracefully
          if transactions[txn['transaction_id']].nil?
            # wrap in transaction if working with database - start
            transactions[txn['transaction_id']] = txn
            account[:balance] += txn['amount'].to_d
            # wrap in transaction if working with database - end
            puts "Producer ID: #{txn['producer_id']}, Account ID: #{txn['account_id']}, Transaction ID: #{txn['transaction_id']}, Amount: #{txn['amount'].to_f}, Balance: #{account[:balance].to_f}"
          else
            raise "Duplicated Transaction ID: #{txn['transaction_id']}" # or handle gracefully
          end
          ch.acknowledge(delivery_info.delivery_tag, false)
        end
      end
    ensure
      # close the connection
      conn.stop
      puts "Processed Transactions:"
      transactions.each do |transaction_id, txn|
        puts "Producer ID: #{txn['producer_id']}, Account ID: #{txn['account_id']}, Transaction ID: #{txn['transaction_id']}, Amount: #{txn['amount'].to_f}"
      end
      puts "Ending Balance:"
      accounts.each do |account_id, account|
        puts "Account ID: #{account_id}, Balance: #{account[:balance].to_f}"
      end
      puts "Consumer stopped"
    end
  end
end

consumer = Thread.new do
  Consumer.new.run
end

set :bind, '0.0.0.0'

get '/' do
  if consumer != nil
    erb :stop_form
  else
    erb :start_form
  end
end

delete '/stop' do
  Thread.kill(consumer)
  consumer = nil
  redirect '/'
end

post '/start' do
  consumer = Thread.new do
    Consumer.new.run
  end
  redirect '/'
end

__END__

@@ stop_form
<form method="post" action="/stop">
  <input type="hidden" name="_method" value="DELETE">
  <input type="submit" value="Stop">
</form>

@@ start_form
<form method="post" action="/start">
  <input type="submit" value="Start">
</form>
