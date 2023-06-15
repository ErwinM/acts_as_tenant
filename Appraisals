appraise "rails-5" do
  gem "rails", "~> 5.2.0", ">= 5.2.6"
end

appraise "rails-6" do
  gem "rails", "~> 6.0.0", ">= 6.0.4.1"
end

appraise "rails-6-1" do
  gem "rails", "~> 6.1.0", ">= 6.1.4.1"
end

appraise "rails-7" do
  gem "rails", "~> 7.0.0", ">= 7.0.0"
end

appraise "rails-main" do
  gem "rails", github: "rails/rails", branch: :main
  %w[rspec rspec-core rspec-expectations rspec-mocks rspec-support rspec-rails].each do |lib|
    gem lib, git: "https://github.com/rspec/#{lib}.git", branch: "main"
  end
end

appraise "sidekiq-6" do
  gem "sidekiq", "~> 6.0"
end

appraise "sidekiq-7" do
  gem "sidekiq", "~> 7.0"
end
