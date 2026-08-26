require "cgi"
require "json"
require "net/http"
require "uri"

module Folio
  class Careers
    ALLOWED_HOSTS = %w[
      boards-api.greenhouse.io
      api.lever.co
      api.ashbyhq.com
      api.smartrecruiters.com
      apply.workable.com
    ].freeze

    KINDS = %i[greenhouse lever ashby workable smartrecruiters].freeze
    TOKEN = /\A[a-zA-Z0-9_-]+\z/
    JOB_ID = /\A[a-zA-Z0-9_-]+\z/
    LIMIT = 40
    MATCHED_LIMIT = 40
    DEFAULT_MIN = 25

    Source = Struct.new(:kind, :board, :job_id, :page, keyword_init: true)
    Job = Struct.new(:title, :location, :url, :listing, keyword_init: true)
    Board = Struct.new(:source, :company, :jobs, keyword_init: true)

    def self.parse(url)
      new.parse(url)
    end

    def self.lookup(url, skills: [], http: nil)
      new(http: http).lookup(url, skills: skills)
    end

    def self.matched(skills:, min: DEFAULT_MIN, catalog: nil, http: nil, limit: MATCHED_LIMIT, us_only: true)
      new(http: http).matched(skills: skills, min: min, catalog: catalog, limit: limit, us_only: us_only)
    end

    def initialize(http: nil)
      @http = http
    end

    def parse(raw)
      uri = URI.parse(raw.to_s.strip)
      raise Folio::Error, "Use an http or https careers link." unless uri.is_a?(URI::HTTP)
      host = uri.host.to_s.downcase
      path = uri.path.to_s

      parts = path_parts(path)
      case host
      when "boards.greenhouse.io", "job-boards.greenhouse.io"
        token = parts[0]
        job = parts[1] == "jobs" ? parts[2] : nil
        source(:greenhouse, token, job, raw)
      when "jobs.lever.co"
        token = parts[0]
        job = parts[1]
        job = nil if job == "apply"
        source(:lever, token, job, raw)
      when "jobs.ashbyhq.com"
        source(:ashby, parts[0], parts[1], raw)
      when "apply.workable.com"
        token = parts[0]
        job = parts[1] == "j" ? parts[2] : nil
        source(:workable, token, job, raw)
      when "jobs.smartrecruiters.com", "careers.smartrecruiters.com"
        source(:smartrecruiters, parts[0], parts[1], raw)
      else
        raise Folio::Error, "Use a Greenhouse, Lever, Ashby, Workable, or SmartRecruiters careers link."
      end
    end

    def lookup(raw, skills: [])
      source = parse(raw)
      score_board(fetch_board(source), skills: skills, source: source)
    end

    # Scan the curated company list and return roles that fit the profile skills.
    def matched(skills:, min: DEFAULT_MIN, catalog: nil, limit: MATCHED_LIMIT, us_only: true)
      min = min.to_i
      min = DEFAULT_MIN if min.negative?
      us_only = ActiveModel::Type::Boolean.new.cast(us_only)
      us_only = true if us_only.nil?
      entries = Array(catalog || Folio::Catalog.entries)
      raise Folio::Error, "Curated catalog is empty." if entries.empty?

      boards = fetch_catalog(entries)
      jobs = []
      errors = []

      boards.each do |row|
        if row[:error]
          errors << { company: row[:company], board: row[:board], source: row[:kind].to_s, error: row[:error] }
          next
        end

        board = row[:board_payload]
        scored = score_board(board, skills: skills, source: board.source, why: row[:why], limit: nil)
        scored[:jobs].each do |job|
          next if job[:match][:score].nil? || job[:match][:score] < min
          next if us_only && !Folio::Locations.us?(job[:location])

          jobs << job.merge(
            company: scored[:company],
            source: scored[:source],
            why: row[:why]
          )
        end
      end

      jobs = jobs.sort_by { |job| [ -(job[:match][:score] || -1), job[:company].to_s, job[:title].to_s ] }
        .first(limit)

      {
        min: min,
        us_only: us_only,
        scanned: entries.length,
        jobs: jobs,
        errors: errors
      }
    end

    private

    def score_board(board, skills:, source:, why: nil, limit: LIMIT)
      jobs = board.jobs
      jobs = jobs.select { |job| same_job?(job, source) } if source.job_id
      raise Folio::Error, "That board has no open roles." if jobs.empty? && limit

      scored = jobs.filter_map do |job|
        next if job.title.blank?

        match = Folio::Matcher.score(skills, title: job.title, listing: job.listing)
        row = {
          title: job.title,
          company: board.company,
          location: job.location,
          url: job.url,
          listing: job.listing,
          source: source.kind.to_s,
          match: {
            score: match.score,
            hits: match.hits,
            gaps: match.gaps,
            detected: match.detected
          }
        }
        row[:why] = why if why.present?
        row
      end
      scored = scored.sort_by { |job| [ -(job[:match][:score] || -1), job[:title] ] }
      scored = scored.first(limit) if limit

      {
        source: source.kind.to_s,
        company: board.company,
        page: source.page,
        jobs: scored
      }
    end

    def fetch_catalog(entries)
      if @http
        return entries.map { |entry| fetch_catalog_entry(entry) }
      end

      # Parallelize public API calls so a curated refresh stays interactive.
      entries.map do |entry|
        Thread.new { fetch_catalog_entry(entry) }
      end.map(&:value)
    end

    def fetch_catalog_entry(entry)
      source = source(entry.kind, entry.board, nil, page_for(entry))
      begin
        {
          kind: entry.kind,
          board: entry.board,
          company: entry.company,
          why: entry.why,
          board_payload: fetch_board(source)
        }
      rescue Folio::Error => error
        {
          kind: entry.kind,
          board: entry.board,
          company: entry.company,
          why: entry.why,
          error: error.message
        }
      end
    end

    def page_for(entry)
      case entry.kind
      when :greenhouse then "https://boards.greenhouse.io/#{entry.board}"
      when :lever then "https://jobs.lever.co/#{entry.board}"
      when :ashby then "https://jobs.ashbyhq.com/#{entry.board}"
      when :workable then "https://apply.workable.com/#{entry.board}"
      when :smartrecruiters then "https://jobs.smartrecruiters.com/#{entry.board}"
      else "https://example.invalid/#{entry.board}"
      end
    end

    def source(kind, board, job_id, page)
      raise Folio::Error, "That careers link is missing the company." unless board.to_s.match?(TOKEN)
      raise Folio::Error, "That job id looks wrong." if job_id && !job_id.to_s.match?(JOB_ID)

      Source.new(kind: kind, board: board, job_id: job_id, page: page.to_s.strip)
    end

    def path_parts(path)
      path.split("/").reject(&:blank?)
    end

    def fetch_board(source)
      case source.kind
      when :greenhouse then greenhouse(source)
      when :lever then lever(source)
      when :ashby then ashby(source)
      when :workable then workable(source)
      when :smartrecruiters then smartrecruiters(source)
      end
    end

    def greenhouse(source)
      meta = get_json("https://boards-api.greenhouse.io/v1/boards/#{source.board}")
      payload = get_json("https://boards-api.greenhouse.io/v1/boards/#{source.board}/jobs?content=true")
      jobs = Array(payload["jobs"]).map do |row|
        id = row["id"].to_s
        Job.new(
          title: row["title"].to_s,
          location: row.dig("location", "name").to_s,
          url: row["absolute_url"].presence || "https://boards.greenhouse.io/#{source.board}/jobs/#{id}",
          listing: plain(row["content"])
        )
      end
      Board.new(source: source, company: meta["name"].presence || titleize(source.board), jobs: jobs)
    end

    def lever(source)
      payload = get_json("https://api.lever.co/v0/postings/#{source.board}?mode=json")
      jobs = Array(payload).map do |row|
        listing = [
          row["descriptionPlain"].presence || plain(row["description"]),
          Array(row["lists"]).map { |block| [ block["text"], plain(block["content"]) ].compact.join("\n") }.join("\n")
        ].reject(&:blank?).join("\n\n")
        Job.new(
          title: row["text"].to_s,
          location: row.dig("categories", "location").to_s,
          url: row["hostedUrl"].presence || "https://jobs.lever.co/#{source.board}/#{row["id"]}",
          listing: listing
        )
      end
      Board.new(source: source, company: titleize(source.board), jobs: jobs)
    end

    def ashby(source)
      payload = get_json("https://api.ashbyhq.com/posting-api/job-board/#{source.board}")
      jobs = Array(payload["jobs"]).map do |row|
        Job.new(
          title: row["title"].to_s,
          location: row["location"].to_s,
          url: row["jobUrl"].presence || "https://jobs.ashbyhq.com/#{source.board}",
          listing: plain(row["descriptionHtml"])
        )
      end
      Board.new(source: source, company: payload["name"].presence || titleize(source.board), jobs: jobs)
    end

    def workable(source)
      payload = get_json("https://apply.workable.com/api/v1/widget/accounts/#{source.board}")
      jobs = Array(payload["jobs"]).map do |row|
        shortcode = row["shortcode"].to_s
        listing = [ row["title"], row["department"], row["location"] ].compact.join("\n")
        Job.new(
          title: row["title"].to_s,
          location: location_text(row["location"]),
          url: row["url"].presence || "https://apply.workable.com/#{source.board}/j/#{shortcode}",
          listing: listing
        )
      end
      Board.new(source: source, company: payload["name"].presence || titleize(source.board), jobs: jobs)
    end

    def smartrecruiters(source)
      payload = get_json("https://api.smartrecruiters.com/v1/companies/#{source.board}/postings")
      jobs = Array(payload["content"]).map do |row|
        id = row["id"].to_s
        listing = row["name"].to_s
        if source.job_id && id == source.job_id
          detail = get_json("https://api.smartrecruiters.com/v1/companies/#{source.board}/postings/#{id}")
          ad = detail["jobAd"] || {}
          listing = [ ad.dig("sections", "jobDescription", "text"), ad.dig("sections", "qualifications", "text") ]
            .map { |part| plain(part) }.reject(&:blank?).join("\n\n").presence || listing
        end
        Job.new(
          title: row["name"].to_s,
          location: row.dig("location", "city").to_s,
          url: "https://jobs.smartrecruiters.com/#{source.board}/#{id}",
          listing: listing
        )
      end
      Board.new(source: source, company: titleize(source.board), jobs: jobs)
    end

    def same_job?(job, source)
      return true if source.job_id.blank?

      needle = source.job_id.downcase
      job.url.to_s.downcase.include?(needle) || job.title.to_s.parameterize.include?(needle)
    end

    def get_json(url)
      status, body = http_get(url)
      raise Folio::Error, "That careers board is not public or was not found." if status == 404
      raise Folio::Error, "The careers API did not return that board." unless status == 200

      JSON.parse(body)
    rescue JSON::ParserError
      raise Folio::Error, "The careers API did not return JSON."
    end

    def http_get(url)
      return @http.call(url) if @http

      uri = URI.parse(url)
      raise Folio::Error, "Blocked careers host." unless ALLOWED_HOSTS.include?(uri.host)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/json"
        request["User-Agent"] = "Folio/1.0 (+https://github.com/acald-creator/folio)"
        http.request(request)
      end
      [ response.code.to_i, response.body.to_s ]
    rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError
      raise Folio::Error, "Could not reach that careers API."
    end

    def plain(html)
      text = html.to_s
      text = CGI.unescapeHTML(text)
      text = text.gsub(/<(script|style)[^>]*>.*?<\/\1>/im, " ")
      text = text.gsub(/<br\s*\/?>/i, "\n").gsub(/<\/p>/i, "\n\n").gsub(/<[^>]+>/, " ")
      text.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip
    end

    def location_text(value)
      case value
      when Hash then value.values_at("city", "region", "country").compact.join(", ")
      else value.to_s
      end
    end

    def titleize(token)
      token.to_s.tr("-_", " ").split.map(&:capitalize).join(" ")
    end
  end
end
