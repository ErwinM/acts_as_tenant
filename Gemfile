source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Declare your gem's dependencies in noticed.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

gem "sqlite3", "~> 1.6.0.rc2"
gem "appraisal", github: "thoughtbot/appraisal", ref: "b200e63"

# Ruby 3.1+ no longer includes these by default
group :development, :test do
  gem "net-imap"
  gem "net-pop"
  gem "net-smtp"
end
