# Admin Users Migration from Old System
# Run with: rails runner "load 'db/seeds/admin_users_seed.rb'"

puts "Creating admin users from old system..."

admin_users_data = [
  {
    email: 'alex.lu@think-bridge.com',
    encrypted_password: '$2a$12$eyJtvA.5/Tjf.lh4A3EPbOoh//g5QbVZYttTrupZwVbU77izsJ6Ym',
    name: 'Alex Lu',
    telephone: '(021) 6375 8318 - 225',
    role: 'admin',
    created_at: '2021-08-04 06:29:34.503322',
    updated_at: '2021-09-06 04:00:46.578501'
  },
  {
    email: 'jojo.sun@think-bridge.com',
    encrypted_password: '$2a$12$qKsMVW0NB0fr8ZN7qILqgeXlnKHGcnkVC8EXdkwfCOSHbQPcpCdjm',
    name: 'Jojo Sun',
    telephone: '(021) 6375 8318 - 307',
    role: 'admin',
    remember_created_at: '2021-08-17 07:22:40',
    created_at: '2021-08-04 06:44:47.196544',
    updated_at: '2021-08-25 06:39:10.420381'
  },
  {
    email: 'steve.zhou@think-bridge.com',
    encrypted_password: '$2a$12$ISbvUlLJPfqQa/HPe5eK8.NytA60VcdKWlFeEi4vMZfEizwa4HfGa',
    name: 'Steve Zhou',
    telephone: '(021) 6375 8318 - 296',
    role: 'admin',
    remember_created_at: '2021-09-18 01:50:15',
    created_at: '2021-08-04 06:45:34.902109',
    updated_at: '2021-09-18 01:50:15.561981'
  },
  {
    email: 'cheng.qian@think-bridge.com',
    encrypted_password: '$2a$12$XJTu132oJY2wZ8e.oBM/7OHUWr1.sib7kL3mWHdJ8Dy0isSWuIAhq',
    name: 'Cheng Qian',
    telephone: '(021) 6375 8318 - 308',
    role: 'admin',
    created_at: '2021-08-04 06:47:24.874135',
    updated_at: '2021-08-11 06:13:26.372598'
  },
  {
    email: 'ken.wang@think-bridge.com',
    encrypted_password: '$2a$12$l30GaQhtBvKVU8wvSNWxoOAIWh2oU503co5/wWxQs7Y6ysZyNFiq2',
    name: 'Ken Wang',
    telephone: '',
    role: 'admin',
    created_at: '2021-08-04 06:47:52.920098',
    updated_at: '2021-09-07 08:24:37.189338'
  },
  {
    email: 'zedong.wu@think-bridge.com',
    encrypted_password: '$2a$12$85HPuPnaaq0Zxc.haTYhYOGFCH92o08x0itZljHa0gea0bQ3PbpkG',
    name: 'Zedong Wu',
    telephone: '(021) 6375 8318 - 307',
    role: 'admin',
    created_at: '2021-08-04 06:48:35.856757',
    updated_at: '2021-11-02 01:39:20.571875'
  },
  {
    email: 'ada.qiu@think-bridge.com',
    encrypted_password: '$2a$12$Z4mBzSCipRhIeq4CWA1dZ.7y1xb9ADW.7I2Suwl3lE4.LIvuRUoO.',
    name: 'Ada Qiu',
    telephone: '(021) 6375 8318 - 307',
    role: 'admin',
    remember_created_at: '2021-08-11 03:26:57',
    created_at: '2021-08-04 06:49:06.943097',
    updated_at: '2021-08-11 06:13:52.411326'
  },
  {
    email: 'dora.yang@think-bridge.com',
    encrypted_password: '$2a$12$RhKR3ggxSNahkFXbaRRfr.cqRaWVGt3scu6ksqNTh3QAeylIVaTZC',
    name: 'Dora Yang',
    telephone: '(021) 6375 8318 - 307',
    role: 'admin',
    remember_created_at: '2021-09-02 01:32:22',
    created_at: '2021-08-04 06:49:53.485901',
    updated_at: '2021-09-02 01:32:22.589324'
  },
  {
    email: 'amy.wu@think-bridge.com',
    encrypted_password: '$2a$12$9xKNx4kjLdMntMc94PzKZOHiZOSZFZHjxjkkeY4e9JM0Uc0j5dOO2',
    name: 'Amy Wu',
    telephone: '(021) 6375 8318 - 307',
    role: 'admin',
    remember_created_at: '2021-08-10 10:40:27',
    created_at: '2021-08-04 06:55:40.996635',
    updated_at: '2021-08-11 06:14:16.268672'
  },
  {
    email: 'lily.dai@think-bridge.com',
    encrypted_password: '$2a$12$G2Eg9nvGJIlYFTk92UnEH.6A37tBDlGZ2Wzu6mZYGaLx0dcqXKMia',
    name: 'Lily Dai',
    telephone: nil,
    role: 'admin',
    created_at: '2021-08-04 06:56:25.002716',
    updated_at: '2021-08-06 10:02:29.490348'
  },
  {
    email: 'jack.wang@think-bridge.com',
    encrypted_password: '$2a$12$bjt0AQoKTRRiq7k/DNo2O.2W8VuzwM16SB7NevC6D9lqiMVzmk6SS',
    name: 'Jack Wang',
    telephone: '(021) 6375 8318 - 307',
    role: 'admin',
    created_at: '2021-10-19 03:59:02.261688',
    updated_at: '2021-11-04 01:34:15.826515'
  },
  {
    email: 'dshen.gu@think-bridge.com',
    encrypted_password: '$2a$12$oSlXXxy9KwgFSWMnf8HKNudQaSJJ9hvQ0a83yXhGVYXf9h9u/kxOW',
    name: 'Dshen Gu',
    telephone: '(021) 6375 8318 - 307',
    role: 'admin',
    created_at: '2021-10-20 05:24:49.262982',
    updated_at: '2021-11-02 01:44:20.779253'
  },
  {
    email: 'bob.wang@think-bridge.com',
    encrypted_password: '$2a$12$eMVQI7j4kAMpDrFpFEh.DOelfNTEKBALmjiVOsyGSCiQ5RP9KSP2y',
    name: 'Bob Wang',
    telephone: '(021) 6375 8318 - 307',
    role: 'admin',
    remember_created_at: '2021-11-12 10:05:49',
    created_at: '2021-10-20 05:26:03.321747',
    updated_at: '2021-11-12 10:05:49.629114'
  },
  {
    email: 'amos.lin@think-bridge.com',
    encrypted_password: '$2a$12$L/Jep7NJdtQoyXQiOhQL1.Czu5FH5KxoNlnm0iHfvrv3/1GgsnuUu',
    name: 'Amos Lin',
    telephone: '',
    role: 'admin',
    created_at: '2021-11-26 07:56:15.625963',
    updated_at: '2021-12-29 03:05:37.043060'
  }
]

created_count = 0
skipped_count = 0

admin_users_data.each do |user_data|
  if AdminUser.exists?(email: user_data[:email])
    puts "Skipping #{user_data[:email]} - already exists"
    skipped_count += 1
  else
    # Create user without validations since we have encrypted passwords
    user = AdminUser.new(user_data)
    user.save!(validate: false)
    puts "Created admin user: #{user_data[:email]} (#{user_data[:name]})"
    created_count += 1
  end
end

puts "\nMigration completed:"
puts "- Created: #{created_count} users"
puts "- Skipped: #{skipped_count} users (already existed)"
puts "- Total admin users in system: #{AdminUser.count}"