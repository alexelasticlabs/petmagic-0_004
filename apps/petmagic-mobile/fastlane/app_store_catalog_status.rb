# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"
require "jwt"

# Read-only verification of the exact StoreKit catalog used by the iOS app.
# The script deliberately never creates, edits, or submits App Store Connect
# resources. It is run from the protected production GitHub environment so the
# API key remains unavailable to a developer workstation or workflow log.
class AppStoreCatalogStatus
  API_BASE = "https://api.appstoreconnect.apple.com/v1"

  EXPECTED_SUBSCRIPTION_IDS = %w[
    com.petmagic.app.premium.monthly
    com.petmagic.app.premium.yearly
  ].freeze

  EXPECTED_CONSUMABLE_IDS = %w[
    com.petmagic.app.tokens.apple.starter
    com.petmagic.app.tokens.apple.creator
    com.petmagic.app.tokens.apple.viral
  ].freeze

  def initialize
    @app_id = ENV.fetch("APP_STORE_CONNECT_APP_ID")
    @key_id = ENV.fetch("APP_STORE_CONNECT_KEY_ID")
    @issuer_id = ENV.fetch("APP_STORE_CONNECT_ISSUER_ID")
    @private_key = OpenSSL::PKey::EC.new(ENV.fetch("APP_STORE_CONNECT_KEY_P8").gsub("\\n", "\n"))
  end

  def run
    consumables = list_all(
      "/apps/#{@app_id}/inAppPurchasesV2?#{URI.encode_www_form(
        "fields[inAppPurchases]" => "name,productId,state,inAppPurchaseType",
        "limit" => "200"
      )}"
    )
    subscriptions = subscription_groups.flat_map do |group|
      list_all(
        "/subscriptionGroups/#{group.fetch("id")}/subscriptions?#{URI.encode_www_form(
          "fields[subscriptions]" => "name,productId,state",
          "limit" => "200"
        )}"
      )
    end

    print_catalog("consumable", consumables)
    print_catalog("subscription", subscriptions)
    print_localization_status("consumable", consumables, "/v2/inAppPurchases", "inAppPurchaseLocalizations")
    print_localization_status("subscription", subscriptions, "subscriptions", "subscriptionLocalizations")
    print_subscription_group_localization_status
    print_consumable_price_status(consumables)
    print_subscription_price_status(subscriptions)
    print_review_screenshot_status("consumable", consumables, "/v2/inAppPurchases")
    print_review_screenshot_status("subscription", subscriptions, "/subscriptions")

    verify_expected!("consumable", consumables, EXPECTED_CONSUMABLE_IDS)
    verify_expected!("subscription", subscriptions, EXPECTED_SUBSCRIPTION_IDS)
    puts "app_store_catalog_status=verified"
  end

  private

  def subscription_groups
    list_all(
      "/apps/#{@app_id}/subscriptionGroups?#{URI.encode_www_form(
        "fields[subscriptionGroups]" => "referenceName",
        "limit" => "200"
      )}"
    )
  end

  def list_all(initial_path)
    resources = []
    path = initial_path

    while path
      response = get(path)
      resources.concat(response.fetch("data"))
      path = response.dig("links", "next")
      path = URI(path).request_uri if path
    end

    resources
  end

  def print_catalog(kind, resources)
    resources
      .sort_by { |resource| resource.dig("attributes", "productId").to_s }
      .each do |resource|
        attributes = resource.fetch("attributes")
        product_id = attributes.fetch("productId")
        state = attributes.fetch("state", "UNKNOWN")
        type = attributes.fetch("inAppPurchaseType", "AUTO_RENEWABLE_SUBSCRIPTION")
        puts "app_store_catalog_item kind=#{kind} product_id=#{product_id} state=#{state} type=#{type}"
      end
  end

  def verify_expected!(kind, resources, expected_ids)
    actual_ids = resources.map { |resource| resource.dig("attributes", "productId") }.compact
    missing_ids = expected_ids - actual_ids
    return if missing_ids.empty?

    raise "App Store #{kind} products are missing: #{missing_ids.join(", ")}"
  end

  def print_localization_status(kind, resources, resource_path, localization_path)
    resources.each do |resource|
      product_id = resource.dig("attributes", "productId")
      localizations = list_all(
        "/#{resource_path}/#{resource.fetch("id")}/#{localization_path}?#{URI.encode_www_form(
          "fields[#{localization_path}]" => "locale,name,description,state",
          "limit" => "200"
        )}"
      )
      locales = localizations.map { |localization| localization.dig("attributes", "locale") }.compact.sort
      puts "app_store_catalog_localizations kind=#{kind} product_id=#{product_id} count=#{localizations.length} locales=#{locales.join(",")}"
    end
  end

  def print_consumable_price_status(resources)
    resources.each do |resource|
      schedule = get(
        "/v2/inAppPurchases/#{resource.fetch("id")}/iapPriceSchedule?#{URI.encode_www_form(
          "include" => "manualPrices,automaticPrices",
          "limit[manualPrices]" => "50",
          "limit[automaticPrices]" => "50"
        )}"
      ).fetch("data")
      relationships = schedule.fetch("relationships", {})
      manual_count = relationships.dig("manualPrices", "data")&.length || 0
      automatic_count = relationships.dig("automaticPrices", "data")&.length || 0
      puts "app_store_catalog_prices kind=consumable product_id=#{resource.dig("attributes", "productId")} manual=#{manual_count} automatic=#{automatic_count}"
    end
  end

  def print_subscription_group_localization_status
    subscription_groups.each do |group|
      localizations = list_all(
        "/subscriptionGroups/#{group.fetch("id")}/subscriptionGroupLocalizations?#{URI.encode_www_form(
          "fields[subscriptionGroupLocalizations]" => "locale,name,state",
          "limit" => "200"
        )}"
      )
      locales = localizations.map { |localization| localization.dig("attributes", "locale") }.compact.sort
      puts "app_store_catalog_group_localizations group=#{group.dig("attributes", "referenceName")} count=#{localizations.length} locales=#{locales.join(",")}"
    end
  end

  def print_review_screenshot_status(kind, resources, resource_path)
    resources.each do |resource|
      response = get_optional("#{resource_path}/#{resource.fetch("id")}/relationships/appStoreReviewScreenshot")
      review_screenshot_id = response&.dig("data", "id")
      status = review_screenshot_id ? "present" : "missing"
      puts "app_store_catalog_review_screenshot kind=#{kind} product_id=#{resource.dig("attributes", "productId")} status=#{status}"
    end
  end

  def print_subscription_price_status(resources)
    resources.each do |resource|
      prices = list_all(
        "/subscriptions/#{resource.fetch("id")}/prices?#{URI.encode_www_form(
          "filter[territory]" => "USA",
          "limit" => "200"
        )}"
      )
      puts "app_store_catalog_prices kind=subscription product_id=#{resource.dig("attributes", "productId")} usa=#{prices.length}"
    end
  end

  def get(path)
    api_base = path.start_with?("/v2/") ? API_BASE.delete_suffix("/v1") : API_BASE
    uri = URI(path.start_with?("http") ? path : "#{api_base}#{path}")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{jwt}"
    request["Accept"] = "application/json"

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    return JSON.parse(response.body) if response.code.to_i == 200

    error_message = JSON.parse(response.body).fetch("errors", []).map { |error| error["detail"] || error["title"] }.join("; ")
    raise "App Store Connect API GET #{uri.request_uri} returned HTTP #{response.code}: #{error_message}"
  rescue JSON::ParserError
    raise "App Store Connect API GET #{uri.request_uri} returned HTTP #{response.code}"
  end

  def get_optional(path)
    api_base = path.start_with?("/v2/") ? API_BASE.delete_suffix("/v1") : API_BASE
    uri = URI(path.start_with?("http") ? path : "#{api_base}#{path}")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{jwt}"
    request["Accept"] = "application/json"

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    return JSON.parse(response.body) if response.code.to_i == 200
    return nil if response.code.to_i == 404

    error_message = JSON.parse(response.body).fetch("errors", []).map { |error| error["detail"] || error["title"] }.join("; ")
    raise "App Store Connect API GET #{uri.request_uri} returned HTTP #{response.code}: #{error_message}"
  rescue JSON::ParserError
    raise "App Store Connect API GET #{uri.request_uri} returned HTTP #{response.code}"
  end

  def jwt
    now = Time.now.to_i
    JWT.encode(
      { "iss" => @issuer_id, "iat" => now - 30, "exp" => now + 600, "aud" => "appstoreconnect-v1" },
      @private_key,
      "ES256",
      { "kid" => @key_id, "typ" => "JWT" }
    )
  end
end

AppStoreCatalogStatus.new.run
