require "test_helper"

class CareersTest < ActiveSupport::TestCase
  test "parses well known career hosts" do
    greenhouse = Folio::Careers.parse("https://boards.greenhouse.io/acme/jobs/123")
    assert_equal :greenhouse, greenhouse.kind
    assert_equal "acme", greenhouse.board
    assert_equal "123", greenhouse.job_id

    lever = Folio::Careers.parse("https://jobs.lever.co/north-glass/abcd-ef")
    assert_equal :lever, lever.kind
    assert_equal "north-glass", lever.board
    assert_equal "abcd-ef", lever.job_id

    ashby = Folio::Careers.parse("https://jobs.ashbyhq.com/mongoose")
    assert_equal :ashby, ashby.kind
    assert_equal "mongoose", ashby.board
    assert_nil ashby.job_id
  end

  test "rejects an unknown host" do
    error = assert_raises(Folio::Error) { Folio::Careers.parse("https://linkedin.com/jobs/view/1") }
    assert_match(/Greenhouse/, error.message)
  end

  test "scores a greenhouse board through the public api shape" do
    http = lambda do |url|
      case url
      when "https://boards-api.greenhouse.io/v1/boards/mongoose"
        [ 200, { name: "Mongoose Press" }.to_json ]
      when "https://boards-api.greenhouse.io/v1/boards/mongoose/jobs?content=true"
        [ 200, {
          jobs: [
            {
              id: 11,
              title: "Staff Rails engineer",
              content: "<p>Rails, Vue, and SQLite. No Kubernetes.</p>",
              absolute_url: "https://boards.greenhouse.io/mongoose/jobs/11",
              location: { name: "Remote" }
            },
            {
              id: 12,
              title: "Platform engineer",
              content: "<p>Kubernetes, Terraform, and Java.</p>",
              absolute_url: "https://boards.greenhouse.io/mongoose/jobs/12",
              location: { name: "Austin" }
            }
          ]
        }.to_json ]
      else
        flunk "unexpected url #{url}"
      end
    end

    result = Folio::Careers.lookup(
      "https://boards.greenhouse.io/mongoose",
      skills: [ "Rails", "Vue", "SQLite" ],
      http: http
    )

    assert_equal "greenhouse", result[:source]
    assert_equal "Mongoose Press", result[:company]
    assert_equal "Staff Rails engineer", result[:jobs].first[:title]
    assert result[:jobs].first[:match][:score] > result[:jobs].last[:match][:score]
    assert_includes result[:jobs].first[:match][:hits], "Rails"
  end

  test "matched feed ranks curated boards without a pasted url" do
    catalog = [
      Folio::Catalog::Entry.new(
        kind: :greenhouse,
        board: "mongoose",
        company: "Mongoose Press",
        why: "Rails and Vue product work."
      ),
      Folio::Catalog::Entry.new(
        kind: :ashby,
        board: "harbor",
        company: "Harbor Platform",
        why: "Wrong stack on purpose."
      )
    ]

    http = lambda do |url|
      case url
      when "https://boards-api.greenhouse.io/v1/boards/mongoose"
        [ 200, { name: "Mongoose Press" }.to_json ]
      when "https://boards-api.greenhouse.io/v1/boards/mongoose/jobs?content=true"
        [ 200, {
          jobs: [
            {
              id: 11,
              title: "Staff Rails engineer",
              content: "<p>Rails, Vue, ROM, and SQLite.</p>",
              absolute_url: "https://boards.greenhouse.io/mongoose/jobs/11",
              location: { name: "Remote, United States" }
            }
          ]
        }.to_json ]
      when "https://api.ashbyhq.com/posting-api/job-board/harbor"
        [ 200, {
          name: "Harbor Platform",
          jobs: [
            {
              title: "Platform engineer",
              descriptionHtml: "<p>Kubernetes, Terraform, and Java Spring Boot.</p>",
              location: "Austin, TX",
              jobUrl: "https://jobs.ashbyhq.com/harbor/platform"
            }
          ]
        }.to_json ]
      else
        flunk "unexpected url #{url}"
      end
    end

    result = Folio::Careers.matched(
      skills: [ "Rails", "Vue", "SQLite", "ROM" ],
      min: 20,
      catalog: catalog,
      http: http
    )

    assert_equal 2, result[:scanned]
    assert result[:us_only]
    assert_equal 1, result[:jobs].length
    assert_equal "Staff Rails engineer", result[:jobs].first[:title]
    assert_equal "Mongoose Press", result[:jobs].first[:company]
    assert_equal "Rails and Vue product work.", result[:jobs].first[:why]
    assert result[:jobs].first[:match][:score] >= 20
  end

  test "matched feed can restrict to US locations" do
    catalog = [
      Folio::Catalog::Entry.new(
        kind: :greenhouse,
        board: "mongoose",
        company: "Mongoose Press",
        why: "Rails product work."
      )
    ]

    http = lambda do |url|
      case url
      when "https://boards-api.greenhouse.io/v1/boards/mongoose"
        [ 200, { name: "Mongoose Press" }.to_json ]
      when "https://boards-api.greenhouse.io/v1/boards/mongoose/jobs?content=true"
        [ 200, {
          jobs: [
            {
              id: 11,
              title: "Staff Rails engineer US",
              content: "<p>Rails, Vue, ROM, and SQLite.</p>",
              absolute_url: "https://boards.greenhouse.io/mongoose/jobs/11",
              location: { name: "San Francisco" }
            },
            {
              id: 12,
              title: "Staff Rails engineer UK",
              content: "<p>Rails, Vue, ROM, and SQLite.</p>",
              absolute_url: "https://boards.greenhouse.io/mongoose/jobs/12",
              location: { name: "London, United Kingdom" }
            },
            {
              id: 13,
              title: "Staff Rails engineer Bang",
              content: "<p>Rails, Vue, ROM, and SQLite.</p>",
              absolute_url: "https://boards.greenhouse.io/mongoose/jobs/13",
              location: { name: "Bangalore" }
            }
          ]
        }.to_json ]
      else
        flunk "unexpected url #{url}"
      end
    end

    us = Folio::Careers.matched(
      skills: [ "Rails", "Vue", "SQLite", "ROM" ],
      min: 20,
      catalog: catalog,
      http: http,
      us_only: true
    )
    assert_equal 1, us[:jobs].length
    assert_equal "Staff Rails engineer US", us[:jobs].first[:title]
    assert_match(/San Francisco/i, us[:jobs].first[:location])

    all = Folio::Careers.matched(
      skills: [ "Rails", "Vue", "SQLite", "ROM" ],
      min: 20,
      catalog: catalog,
      http: http,
      us_only: false
    )
    assert_equal 3, all[:jobs].length
    refute all[:us_only]
  end

  test "catalog loads curated boards from yaml" do
    entries = Folio::Catalog.entries
    assert entries.length >= 5
    assert entries.all? { |entry| Folio::Careers::KINDS.include?(entry.kind) }
    assert entries.all? { |entry| entry.board.present? }
  end

  test "imports a posting onto the board once" do
    job = studio.import_posting(
      company_name: "Mongoose Press",
      title: "Staff Rails engineer",
      listing: "Rails and Vue.",
      url: "https://boards.greenhouse.io/mongoose/jobs/11",
      location: "Remote"
    )

    columns = studio.board
    card = columns["saved"].first
    assert_equal job.id, card[:id]
    assert_equal "Mongoose Press", card[:client][:name]
    assert_equal "Posting", card[:assets].first[:label]

    error = assert_raises(Folio::Error) do
      studio.import_posting(
        company_name: "Mongoose Press",
        title: "Staff Rails engineer",
        listing: "Rails and Vue."
      )
    end
    assert_match(/already/, error.message)
  end
end
