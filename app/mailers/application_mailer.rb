class ApplicationMailer < ActionMailer::Base
  default from: %(Boidat <#{ENV.fetch("MAIL_FROM", "no-reply@boidat.tiumpower.com")}>)
  layout "mailer"
end
