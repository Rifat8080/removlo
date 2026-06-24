require "test_helper"

class SeoLandingPageTest < ActiveSupport::TestCase
  test "defines sixty keyword landing pages with unique slugs" do
    assert_equal 60, SeoLandingPage.all.size
    assert_equal 60, SeoLandingPage.slugs.uniq.size
    assert SeoLandingPage.valid_slug?("removal-company-near-me")
    assert SeoLandingPage.valid_slug?("removals-london")
    assert_not SeoLandingPage.valid_slug?("not-a-real-page")
  end
end
