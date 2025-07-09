# Admin Users Seed Data

```ruby
# db/seeds/admin_users_seed.rb
AdminUser.create!([
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
    created_at: '2021-08-04 06:44:47.196544',
    updated_at: '2021-08-25 06:39:10.420381'
  },
  # Additional users would follow the same pattern...
  {
    email: 'amos.lin@think-bridge.com',
    encrypted_password: '$2a$12$L/Jep7NJdtQoyXQiOhQL1.Czu5FH5KxoNlnm0iHfvrv3/1GgsnuUu',
    name: 'Amos Lin',
    telephone: '',
    role: 'admin',
    created_at: '2021-11-26 07:56:15.625963',
    updated_at: '2021-12-29 03:05:37.043060'
  }
])
```

To run:
1. Execute migration: `rails db:migrate`
2. Load seeds: `rails db:seed`