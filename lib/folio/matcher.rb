require "json"

module Folio
  class Matcher
    CATALOG = {
      "Ruby" => %w[ruby],
      "Rails" => [ "rails", "ruby on rails", "rubyonrails" ],
      "ROM" => [ "rom", "rom-rb", "rom rb" ],
      "Active Record" => [ "activerecord", "active record" ],
      "Vue" => [ "vue", "vuejs", "vue.js" ],
      "ReScript" => %w[rescript reasonml],
      "TypeScript" => %w[typescript],
      "JavaScript" => %w[javascript],
      "Go" => [ "golang", "go developer", "go engineer", "go backend", "go services", "go service", "written in go", "using go" ],
      "C#" => [ "c#", "csharp", "c sharp", "blazor" ],
      "Elixir" => %w[elixir],
      "Phoenix" => [ "phoenix framework", "phoenix liveview", "liveview", "elixir phoenix" ],
      "SQLite" => %w[sqlite sqlite3],
      "PostgreSQL" => %w[postgres postgresql],
      "Redis" => %w[redis],
      "Docker" => %w[docker],
      "Kubernetes" => %w[kubernetes k8s],
      "AWS" => [ "aws", "amazon web services" ],
      "GCP" => [ "gcp", "google cloud" ],
      "Terraform" => %w[terraform],
      "GraphQL" => %w[graphql],
      "Python" => %w[python django flask],
      "Java" => [ "java", "spring boot" ],
      "Rust" => %w[rust],
      "Hono" => %w[hono],
      "Next.js" => [ "next.js", "nextjs" ],
      "React" => %w[react],
      "Design tokens" => [ "design tokens", "style dictionary", "w3c tokens", "oklch" ],
      "CI" => [ "github actions", "ci/cd", "continuous integration" ]
    }.freeze

    Result = Struct.new(:score, :hits, :gaps, :detected, keyword_init: true)

    def self.score(profile_skills, title:, listing:)
      new(profile_skills).score(title: title, listing: listing)
    end

    def initialize(profile_skills)
      @owned = Array(profile_skills).map { |skill| skill.to_s.strip }.reject(&:blank?)
    end

    def score(title:, listing:)
      haystack = normalize([ title, listing ].join(" "))
      return empty_result if haystack.blank?

      hits = []
      @owned.each do |skill|
        hits << skill if present?(haystack, phrases_for(skill))
      end

      detected = []
      CATALOG.each do |name, phrases|
        detected << name if present?(haystack, phrases)
      end

      owned_keys = @owned.map { |skill| catalog_name(skill) || skill }
      gaps = detected.reject { |name| owned_keys.any? { |owned| owned.casecmp?(name) } }

      Result.new(
        score: compute_score(hits, detected, gaps),
        hits: hits.uniq,
        gaps: gaps,
        detected: detected
      )
    end

    private

    def empty_result
      Result.new(score: nil, hits: [], gaps: [], detected: [])
    end

    def compute_score(hits, detected, gaps)
      return nil if hits.empty? && detected.empty?

      fit = detected.empty? ? 0.0 : (detected.length - gaps.length).to_f / detected.length
      coverage = @owned.empty? ? 0.0 : hits.length.to_f / @owned.length
      raw = if detected.empty?
        coverage
      else
        (fit * 0.65) + (coverage * 0.35)
      end
      (raw * 100).round
    end

    def phrases_for(skill)
      key = catalog_name(skill)
      list = key ? CATALOG[key] : []
      [ skill.downcase, *list ]
    end

    def catalog_name(skill)
      return skill if CATALOG.key?(skill)

      needle = skill.downcase
      CATALOG.each do |name, phrases|
        return name if name.downcase == needle || phrases.include?(needle)
      end
      nil
    end

    def present?(haystack, phrases)
      phrases.any? do |phrase|
        phrase = phrase.to_s.downcase
        next false if phrase.blank?

        if phrase.match?(/[^a-z0-9]/)
          haystack.include?(phrase)
        else
          haystack.match?(/\b#{Regexp.escape(phrase)}\b/)
        end
      end
    end

    def normalize(text)
      text.to_s.downcase
        .gsub("c#", " csharp ")
        .gsub(/[^a-z0-9.\s-]/, " ")
        .squeeze(" ")
        .strip
    end
  end
end
