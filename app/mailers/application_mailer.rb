class ApplicationMailer < ActionMailer::Base
  default from: %(Boidat <#{ENV.fetch("MAIL_FROM", "no-reply@boidat.czin.net")}>)
  layout "mailer"
end
