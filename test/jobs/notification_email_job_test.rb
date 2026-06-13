require "test_helper"

class NotificationEmailJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  test "notification creation queues email delivery" do
    user = users(:customer)

    assert_enqueued_with(job: NotificationEmailJob) do
      user.notifications.create!(
        event_type: "quotation.payment",
        title: "Payment received",
        body: "Your payment has been recorded.",
        url: "/notifications"
      )
    end
  end

  test "sends portal notification email to recipient" do
    notification = users(:customer).notifications.create!(
      event_type: "quotation.payment",
      title: "Payment received",
      body: "Your payment has been recorded.",
      url: "/notifications"
    )

    assert_emails 1 do
      NotificationEmailJob.perform_now(notification.id)
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal [ "customer@example.com" ], email.to
    assert_equal "Payment received", email.subject
    assert_includes email.body.encoded, "Your payment has been recorded."
    assert_includes email.body.encoded, "http://example.com/notifications"
  end
end
