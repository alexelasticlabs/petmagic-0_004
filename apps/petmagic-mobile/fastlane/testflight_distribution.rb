# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"
require "uri"
require "jwt"

# Idempotently prepares the private TestFlight groups used by PetMagic release
# engineering. It deliberately does not create beta testers, send invitations,
# enable a public link, or submit a build for Beta App Review.
class TestflightDistribution
  API_BASE = "https://api.appstoreconnect.apple.com/v1"
  INTERNAL_GROUP_NAME = "PetMagic Internal QA"
  EXTERNAL_GROUP_NAME = "PetMagic External Beta"

  def initialize
    @app_id = ENV.fetch("APP_STORE_CONNECT_APP_ID")
    @marketing_version = ENV.fetch("APP_VERSION")
    @build_number = ENV.fetch("BUILD_NUMBER")
    @key_id = ENV.fetch("APP_STORE_CONNECT_KEY_ID")
    @issuer_id = ENV.fetch("APP_STORE_CONNECT_ISSUER_ID")
    @private_key = OpenSSL::PKey::EC.new(ENV.fetch("APP_STORE_CONNECT_KEY_P8").gsub("\\n", "\n"))
  end

  def run
    build = find_build
    validate_build!(build)

    [
      [INTERNAL_GROUP_NAME, true],
      [EXTERNAL_GROUP_NAME, false]
    ].each do |name, internal|
      group = find_or_create_group(name, internal)
      attach_build(group.fetch("id"), build.fetch("id"))
      puts "prepared_group=#{name} internal=#{internal} build=#{@marketing_version}(#{@build_number})"
    end
  end

  private

  def find_build
    response = get(
      "/builds?#{URI.encode_www_form(
        "filter[app]" => @app_id,
        "filter[version]" => @build_number,
        "fields[builds]" => "version,processingState,expired,usesNonExemptEncryption,preReleaseVersion",
        "include" => "preReleaseVersion",
        "limit" => "200"
      )}"
    )

    matching_builds = response.fetch("data").select do |build|
      build.fetch("attributes").fetch("version") == @build_number &&
        prerelease_version(build, response.fetch("included", [])) == @marketing_version
    end

    raise "TestFlight build #{@marketing_version} (#{@build_number}) was not found" unless matching_builds.length == 1

    matching_builds.first
  end

  def prerelease_version(build, included)
    prerelease_id = build.dig("relationships", "preReleaseVersion", "data", "id")
    included.find { |resource| resource["type"] == "preReleaseVersions" && resource["id"] == prerelease_id }
      &.dig("attributes", "version")
  end

  def validate_build!(build)
    attributes = build.fetch("attributes")
    raise "TestFlight build is expired" if attributes.fetch("expired")
    raise "TestFlight build is not processed: #{attributes.fetch("processingState")}" unless attributes.fetch("processingState") == "VALID"
  end

  def find_or_create_group(name, internal)
    groups = get(
      "/apps/#{@app_id}/betaGroups?#{URI.encode_www_form(
        "fields[betaGroups]" => "name,isInternalGroup,publicLinkEnabled,hasAccessToAllBuilds",
        "limit" => "200"
      )}"
    ).fetch("data")

    existing = groups.find do |group|
      attributes = group.fetch("attributes")
      attributes["name"] == name && attributes["isInternalGroup"] == internal
    end
    return existing if existing

    attributes = {
      "name" => name,
      "isInternalGroup" => internal,
      "feedbackEnabled" => true,
      "hasAccessToAllBuilds" => false
    }
    unless internal
      attributes["publicLinkEnabled"] = false
      attributes["publicLinkLimitEnabled"] = true
      attributes["publicLinkLimit"] = 100
    end

    post("/betaGroups", {
      "data" => {
        "type" => "betaGroups",
        "attributes" => attributes,
        "relationships" => {
          "app" => {
            "data" => { "type" => "apps", "id" => @app_id }
          }
        }
      }
    }).fetch("data")
  end

  def attach_build(group_id, build_id)
    existing_build_ids = get("/betaGroups/#{group_id}/relationships/builds?limit=200")
      .fetch("data")
      .map { |build| build.fetch("id") }
    return if existing_build_ids.include?(build_id)

    post("/betaGroups/#{group_id}/relationships/builds", {
      "data" => [{ "type" => "builds", "id" => build_id }]
    }, expected_status: 204)
  end

  def get(path)
    request(Net::HTTP::Get, path)
  end

  def post(path, body, expected_status: 201)
    request(Net::HTTP::Post, path, body: body, expected_status: expected_status)
  end

  def request(request_class, path, body: nil, expected_status: 200)
    uri = URI("#{API_BASE}#{path}")
    request = request_class.new(uri)
    request["Authorization"] = "Bearer #{jwt}"
    request["Accept"] = "application/json"
    if body
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)
    end

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
    return {} if response.code.to_i == expected_status && response.body.to_s.empty?
    return JSON.parse(response.body) if response.code.to_i == expected_status

    error_message = JSON.parse(response.body).fetch("errors", []).map { |error| error["detail"] || error["title"] }.join("; ")
    raise "App Store Connect API #{request.method} #{path} returned HTTP #{response.code}: #{error_message}"
  rescue JSON::ParserError
    raise "App Store Connect API #{request.method} #{path} returned HTTP #{response.code}"
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

TestflightDistribution.new.run
