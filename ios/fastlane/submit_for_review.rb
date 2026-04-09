#!/usr/bin/env ruby
# Attaches the latest build to the App Store version and submits for review.
require 'openssl'
require 'jwt'
require 'net/http'
require 'json'
require 'uri'

KEY_ID    = ENV.fetch('ASC_KEY_ID',    'YYHR35NSUL')
ISSUER_ID = ENV.fetch('ASC_ISSUER_ID', '8dbcdb9e-29bf-49f7-974c-7a16f3b80bdd')
KEY_PATH  = ENV.fetch('ASC_KEY_PATH',  File.expand_path("~/.appstoreconnect/private_keys/AuthKey_#{KEY_ID}.p8"))
BUNDLE_ID = ENV.fetch('APP_BUNDLE_ID', 'com.datachain.visualtimer')
PLATFORM  = ENV.fetch('ASC_PLATFORM',  'IOS')
BASE      = 'https://api.appstoreconnect.apple.com'

def success?(code) = %w[200 201 202 204].include?(code.to_s)

def log_failure(step, code, body)
  payload = body.is_a?(Hash) ? body.to_json : body.to_s
  puts "❌ #{step} failed (#{code}): #{payload[0..700]}"
end

def token
  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  payload = { iss: ISSUER_ID, iat: Time.now.to_i, exp: Time.now.to_i + 1200, aud: 'appstoreconnect-v1' }
  JWT.encode(payload, key, 'ES256', { kid: KEY_ID })
end

def call(method, path, body = nil)
  uri  = URI("#{BASE}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  klass = {
    get: Net::HTTP::Get, post: Net::HTTP::Post,
    patch: Net::HTTP::Patch, delete: Net::HTTP::Delete
  }.fetch(method)
  req  = klass.new(uri)
  req['Authorization'] = "Bearer #{token}"
  req['Content-Type']  = 'application/json'
  req.body = body.to_json if body
  resp = http.request(req)
  parsed = begin; JSON.parse(resp.body); rescue; resp.body; end
  [resp.code, parsed]
end

abort("Missing ASC key at #{KEY_PATH}.") unless File.exist?(KEY_PATH)

puts '=== Resolve App ID ==='
raw_app_id = ENV.fetch('ASC_APP_ID', '')
if raw_app_id.empty?
  a_code, a_data = call(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}&fields[apps]=bundleId,name")
  unless success?(a_code)
    log_failure('Fetch app by bundleId', a_code, a_data)
    exit 1
  end
  app_entry = a_data.dig('data', 0)
  abort("No app found for bundleId=#{BUNDLE_ID}") unless app_entry
  APP_ID = app_entry['id']
  puts "Resolved APP_ID=#{APP_ID} for #{BUNDLE_ID}"
else
  APP_ID = raw_app_id
  puts "Using APP_ID=#{APP_ID} (from env)"
end

puts '\n=== Resolve App Store Version ==='
version_filter = ENV['APP_VERSION_STRING']
v_code, versions = call(
  :get,
  "/v1/apps/#{APP_ID}/appStoreVersions?filter%5Bplatform%5D=#{PLATFORM}&limit=50&fields%5BappStoreVersions%5D=versionString,appStoreState"
)
unless success?(v_code)
  log_failure('Fetch appStoreVersions', v_code, versions)
  exit 1
end

version_data = versions.fetch('data', [])
version = if version_filter && !version_filter.empty?
            version_data.find { |item| item.dig('attributes', 'versionString') == version_filter }
          else
            preferred = %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW DEVELOPER_REJECTED WAITING_FOR_REVIEW IN_REVIEW REJECTED]
            version_data.find { |item| preferred.include?(item.dig('attributes', 'appStoreState')) } ||
              version_data.first
          end

unless version
  suffix = version_filter ? " for #{version_filter}" : ''
  abort("No App Store version found#{suffix}.")
end

version_id     = version['id']
version_state  = version.dig('attributes', 'appStoreState')
version_string = version.dig('attributes', 'versionString')
puts "Using version #{version_string} (#{version_id}) state=#{version_state}"

puts '\n=== Cancel Existing Review Submissions (if any) ==='
s_code, submissions = call(
  :get,
  "/v1/apps/#{APP_ID}/reviewSubmissions?filter%5Bplatform%5D=#{PLATFORM}&limit=50&fields%5BreviewSubmissions%5D=state,submittedDate"
)
if success?(s_code)
  cancellable_states = %w[WAITING_FOR_REVIEW IN_REVIEW UNRESOLVED_ISSUES]
  submissions.fetch('data', []).each do |submission|
    state  = submission.dig('attributes', 'state')
    next unless cancellable_states.include?(state)
    sub_id = submission['id']
    c_code, c_body = call(:patch, "/v1/reviewSubmissions/#{sub_id}", {
      data: { type: 'reviewSubmissions', id: sub_id, attributes: { canceled: true } }
    })
    if success?(c_code)
      puts "✅ Cancelled submission #{sub_id} (was #{state})"
    else
      log_failure("Cancel submission #{sub_id}", c_code, c_body)
    end
  end
else
  log_failure('Fetch reviewSubmissions', s_code, submissions)
end

puts '\n=== Find Latest Processed Build ==='
b_code, builds = call(
  :get,
  "/v1/builds?filter%5Bapp%5D=#{APP_ID}&filter%5BprocessingState%5D=VALID&sort=-uploadedDate&limit=1&fields%5Bbuilds%5D=version,uploadedDate,processingState"
)
unless success?(b_code)
  log_failure('Fetch builds', b_code, builds)
  exit 1
end

build = builds.dig('data', 0)
abort('No VALID build found to submit.') unless build

build_id      = build['id']
build_version = build.dig('attributes', 'version')
puts "Using build #{build_version} (#{build_id})"

puts '\n=== Attach Build To App Store Version ==='
a_code, attached = call(:patch, "/v1/appStoreVersions/#{version_id}", {
  data: {
    type: 'appStoreVersions',
    id:   version_id,
    relationships: {
      build: { data: { type: 'builds', id: build_id } }
    }
  }
})
unless success?(a_code)
  log_failure('Attach build to appStoreVersion', a_code, attached)
  exit 1
end
puts '✅ Build attached to App Store version'

puts '\n=== Create Review Submission ==='
r_code, created = call(:post, '/v1/reviewSubmissions', {
  data: {
    type: 'reviewSubmissions',
    attributes: { platform: PLATFORM },
    relationships: {
      app: { data: { type: 'apps', id: APP_ID } }
    }
  }
})

submission_id = created.dig('data', 'id') if success?(r_code)
unless submission_id
  log_failure('Create reviewSubmission', r_code, created)
  exit 1
end
puts "✅ Created review submission #{submission_id}"

puts '\n=== Add Version To Submission ==='
i_code, item = call(:post, '/v1/reviewSubmissionItems', {
  data: {
    type: 'reviewSubmissionItems',
    relationships: {
      reviewSubmission: { data: { type: 'reviewSubmissions', id: submission_id } },
      appStoreVersion:  { data: { type: 'appStoreVersions',   id: version_id    } }
    }
  }
})
unless success?(i_code)
  log_failure('Create reviewSubmissionItem', i_code, item)
  exit 1
end
puts '✅ Version added to submission'

puts '\n=== Submit For Review ==='
f_code, final = call(:patch, "/v1/reviewSubmissions/#{submission_id}", {
  data: {
    type: 'reviewSubmissions',
    id:   submission_id,
    attributes: { submitted: true }
  }
})
unless success?(f_code)
  log_failure('Submit reviewSubmission', f_code, final)
  exit 1
end

final_state    = final.dig('data', 'attributes', 'state')
submitted_date = final.dig('data', 'attributes', 'submittedDate')
puts "✅ SUBMITTED FOR REVIEW"
puts "State: #{final_state}"
puts "Date:  #{submitted_date}"
