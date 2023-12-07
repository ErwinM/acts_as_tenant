class UserMailer < ApplicationMailer
  def comment_notification
    mail(body: "")
  end

  def welcome_email
    mail to: params[:user].email
  end
end
