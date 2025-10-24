namespace :fee_types do
  desc 'Remove uniqueness constraint from fee_types.code'
  task remove_code_uniqueness: :environment do
    puts 'Removing uniqueness constraint from fee_types.code...'

    ActiveRecord::Base.connection.execute('DROP INDEX IF EXISTS index_fee_types_on_code')
    ActiveRecord::Base.connection.execute('CREATE INDEX index_fee_types_on_code ON fee_types(code)')

    puts 'Uniqueness constraint removed. Now fee_types.code is no longer required to be unique.'
  end
end
