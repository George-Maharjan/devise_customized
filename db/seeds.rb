# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Clearing existing data..."
Blog.destroy_all
User.destroy_all

puts "Creating sample users..."

# Create sample users with different profiles
users = [
  {
    email: "john.doe@example.com",
    username: "johndoe",
    password: "password123",
    password_confirmation: "password123"
  },
  {
    email: "jane.smith@example.com",
    username: "janesmith",
    password: "password123",
    password_confirmation: "password123"
  },
  {
    email: "bob.wilson@example.com",
    username: "bobwilson",
    password: "password123",
    password_confirmation: "password123"
  },
  {
    email: "alice.johnson@example.com",
    username: "alicejohnson",
    password: "password123",
    password_confirmation: "password123"
  },
  {
    email: "charlie.brown@example.com",
    username: "charliebrown",
    password: "password123",
    password_confirmation: "password123"
  }
]

created_users = users.map do |user_data|
  user = User.create!(user_data)
  puts "Created user: #{user.email} (username: #{user.username})"
  user
end

puts "\nCreating sample blogs..."

# Sample blog data
blog_topics = [
  {
    title: "Getting Started with Ruby on Rails",
    description: "Ruby on Rails is a powerful web application framework. In this post, we'll explore the basics of Rails and why it's loved by developers worldwide. We'll cover MVC architecture, conventions over configuration, and the Rails philosophy that makes development enjoyable."
  },
  {
    title: "Understanding PostgreSQL in Production",
    description: "PostgreSQL is a robust database system perfect for production applications. Learn about indexing strategies, query optimization, backup procedures, and how to handle millions of records efficiently. We'll also discuss connection pooling and monitoring best practices."
  },
  {
    title: "Devise Authentication Deep Dive",
    description: "A comprehensive guide to implementing authentication in Rails using Devise. We'll cover all the modules, customization options, and security best practices to keep your users' data safe. Plus advanced topics like custom controllers and API authentication."
  },
  {
    title: "CSS Grid vs Flexbox: When to Use Each",
    description: "Modern CSS offers two powerful layout systems. This article breaks down the differences between CSS Grid and Flexbox, showing real-world examples of when to use each. Learn how to build responsive layouts that work across all devices with ease."
  },
  {
    title: "JavaScript ES6+ Features You Should Know",
    description: "JavaScript has evolved significantly with ES6 and beyond. Discover arrow functions, destructuring, spread operators, async/await, and more. We'll show practical examples of how these features make your code cleaner and more maintainable."
  },
  {
    title: "Building RESTful APIs with Rails",
    description: "REST APIs are the backbone of modern web applications. Learn how to design and build robust APIs in Rails, including proper HTTP status codes, authentication, versioning, rate limiting, and comprehensive documentation with tools like Swagger."
  },
  {
    title: "Testing in Rails: A Complete Guide",
    description: "Quality software requires thorough testing. Explore RSpec, FactoryBot, and Capybara to test your Rails applications. We'll cover unit tests, integration tests, system tests, and best practices for maintaining a fast test suite that gives you confidence."
  },
  {
    title: "Docker for Rails Developers",
    description: "Containerization simplifies deployment and development environments. This guide shows Rails developers how to use Docker and Docker Compose for local development, CI/CD pipelines, and production deployments. Includes real-world configuration examples."
  },
  {
    title: "Active Record Performance Optimization",
    description: "Active Record is powerful but can be slow if not used correctly. Learn about N+1 queries, eager loading, counter caches, database indexes, and other techniques to make your Rails application blazingly fast. Real benchmarks included!"
  },
  {
    title: "Building Real-time Features with Action Cable",
    description: "Action Cable brings WebSocket support to Rails for real-time features. Build chat applications, live notifications, collaborative editing, and more. We'll cover channels, broadcasting, authentication, and scaling considerations for production systems."
  },
  {
    title: "Rails Background Jobs with Sidekiq",
    description: "Long-running tasks shouldn't block your web requests. Learn how to use Sidekiq for background job processing in Rails. We'll cover job queues, retries, scheduling, monitoring, and common patterns for reliable asynchronous processing."
  },
  {
    title: "Security Best Practices for Rails Apps",
    description: "Security should never be an afterthought. This comprehensive guide covers CSRF protection, SQL injection prevention, XSS attacks, secure password storage, authentication best practices, and how to keep your Rails application secure against common vulnerabilities."
  },
  {
    title: "Hotwire: The Future of Rails Frontend",
    description: "Hotwire (Turbo + Stimulus) brings SPA-like experiences without heavy JavaScript frameworks. Learn how to build reactive interfaces with minimal JavaScript. We'll build real examples including infinite scroll, live search, and dynamic forms."
  },
  {
    title: "Deploying Rails Apps to Production",
    description: "Taking your Rails app from development to production involves many considerations. We'll cover deployment platforms (Heroku, AWS, DigitalOcean), environment variables, database migrations, asset compilation, SSL certificates, and monitoring setup."
  },
  {
    title: "GraphQL with Rails: Modern API Development",
    description: "GraphQL offers flexibility that REST APIs can't match. Learn how to implement GraphQL in Rails with the graphql-ruby gem. We'll cover queries, mutations, subscriptions, N+1 prevention with dataloader, and authentication strategies."
  }
]

# Assign blogs to users randomly
blog_topics.each_with_index do |blog_data, index|
  user = created_users[index % created_users.length]

  blog = user.blogs.create!(
    title: blog_data[:title],
    description: blog_data[:description]
  )

  puts "Created blog: '#{blog.title}' by #{user.username}"
end

puts "\n" + "="*60
puts "Seed data created successfully!"
puts "="*60
puts "\nSummary:"
puts "- #{User.count} users created"
puts "- #{Blog.count} blogs created"
puts "\nSample login credentials:"
puts "Email: john.doe@example.com"
puts "Password: password123"
puts "\nAll users have the password: password123"
