class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    ActsAsTenant.with_tenant(Account.first) do
      UserMailer.with(user: User.first).welcome_email
    end
  end
end
