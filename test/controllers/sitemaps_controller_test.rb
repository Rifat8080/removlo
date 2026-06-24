require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "sitemap renders valid xml with core marketing pages" do
    get sitemap_path

    assert_response :success
    assert_match %r{\Aapplication/xml}, response.media_type
    assert_includes response.body, "<urlset"
    assert_includes response.body, "removlo.co.uk/"
    assert_includes response.body, "removlo.co.uk/services"
    assert_includes response.body, "removlo.co.uk/get-a-quotation"
    assert_includes response.body, "removlo.co.uk/blog"
    assert_includes response.body, "removlo.co.uk/shop/products"
    assert_not_includes response.body, "/dashboard"
    assert_not_includes response.body, "/admin/"
  end
end
