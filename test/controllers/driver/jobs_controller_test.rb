require "test_helper"

class Driver::JobsControllerTest < ActionDispatch::IntegrationTest
  test "assigned driver sees start move action for scheduled job" do
    sign_in users(:driver_a)

    get driver_job_path(quotations(:booked_job))

    assert_response :success
    assert_match "Start move", response.body
    assert_match "Cancel assignment", response.body
  end

  test "assigned driver can start scheduled move" do
    sign_in users(:driver_a)
    job = quotations(:booked_job)

    patch start_driver_job_path(job)

    assert_redirected_to driver_job_path(job)
    assert_equal "in_progress", job.reload.status
  end

  test "assigned driver can complete in progress move and record earning" do
    sign_in users(:driver_a)
    job = quotations(:booked_job)
    job.update!(status: "in_progress")

    assert_difference "DriverWalletEntry.count", 1 do
      patch complete_driver_job_path(job)
    end

    assert_redirected_to driver_job_path(job)
    assert_equal "completed", job.reload.status
  end

  test "assigned driver can cancel assignment and notify operators" do
    sign_in users(:driver_a)
    job = quotations(:booked_job)
    job.update!(awaiting_driver_offers: true)
    selected_offer = job.driver_offers.create!(driver: users(:driver_a), amount_cents: 45_000, status: :selected, selected_by_admin: true)
    rejected_offer = job.driver_offers.create!(driver: users(:driver_b), amount_cents: 47_500, status: :rejected)
    job.update!(selected_driver_offer: selected_offer, awaiting_driver_offers: false)

    assert_difference -> { Notification.where(event_type: "quotation.driver_cancelled", notifiable: job).count }, User.operators.count do
      patch cancel_assignment_driver_job_path(job)
    end

    assert_redirected_to driver_jobs_path
    job.reload
    assert_nil job.assigned_driver
    assert_nil job.selected_driver_offer
    assert job.awaiting_driver_offers?
    assert_equal "withdrawn", selected_offer.reload.status
    assert_equal "submitted", rejected_offer.reload.status
  end

  test "assigned driver cannot cancel after move starts" do
    sign_in users(:driver_a)
    job = quotations(:booked_job)
    job.update!(status: "in_progress")

    assert_no_difference -> { Notification.where(event_type: "quotation.driver_cancelled").count } do
      patch cancel_assignment_driver_job_path(job)
    end

    assert_redirected_to driver_job_path(job)
    assert_equal users(:driver_a), job.reload.assigned_driver
  end

  test "in progress job auto starts tracking and hides stop sharing" do
    sign_in users(:driver_a)
    job = quotations(:booked_job)
    job.update!(status: "in_progress")

    get driver_job_path(job)

    assert_response :success
    assert_match "data-driver-tracking-auto-start-value=\"true\"", response.body
    assert_match "Auto-sharing while move is active", response.body
    assert_no_match "Stop sharing", response.body
  end

  test "complete move uses in page confirmation modal" do
    sign_in users(:driver_a)
    job = quotations(:booked_job)
    job.update!(status: "in_progress")

    get driver_job_path(job)

    assert_response :success
    assert_match "Complete this move?", response.body
    assert_match "Yes, complete move", response.body
    assert_no_match "turbo_confirm", response.body
    assert_no_match "data-turbo-confirm", response.body
  end

  test "other driver cannot start assigned move" do
    sign_in users(:driver_b)
    job = quotations(:booked_job)

    patch start_driver_job_path(job)

    assert_redirected_to driver_jobs_path
    assert_equal "scheduled", job.reload.status
  end

  test "other driver cannot start assigned move even when marketplace flag remains open" do
    sign_in users(:driver_b)
    job = quotations(:booked_job)
    job.update!(awaiting_driver_offers: true)

    patch start_driver_job_path(job)

    assert_redirected_to driver_jobs_path
    assert_equal "scheduled", job.reload.status
  end
end
