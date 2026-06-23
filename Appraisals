appraise "rails-7-2" do
  gem "rails", "~> 7.2.0"
end

appraise "rails-8-0" do
  gem "rails", "~> 8.0.0"
end

appraise "rails-8-1" do
  gem "rails", "~> 8.1.0"
end

appraise "rails-main" do
  gem "rails", github: "rails/rails", branch: :main
  %w[rspec-core rspec-expectations rspec-mocks rspec-support rspec-rails].each do |lib|
    gem lib, git: "https://github.com/rspec/#{lib}.git", branch: "main"
  end
end

appraise "sidekiq-6" do
  gem "sidekiq", "~> 6.0"
end

appraise "sidekiq-7" do
  gem "sidekiq", "~> 7.0"
end
